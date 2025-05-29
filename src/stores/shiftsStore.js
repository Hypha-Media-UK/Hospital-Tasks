import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

// Helper function to determine if a date is on a weekend
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}

export const useShiftsStore = defineStore('shifts', {
  state: () => ({
    activeShifts: [],
    archivedShifts: [],
    archivedShiftTaskCounts: {}, // Object mapping shift IDs to their task counts
    currentShift: null,
    shiftTasks: [],
    shiftAreaCoverAssignments: [], // Shift-specific area cover assignments
    shiftAreaCoverPorterAssignments: [], // Porter assignments for shift area cover
    shiftSupportServiceAssignments: [], // Shift-specific support service assignments
    shiftSupportServicePorterAssignments: [], // Porter assignments for shift support services
    shiftPorterPool: [], // Porters assigned to the current shift
    loading: {
      activeShifts: false,
      archivedShifts: false,
      currentShift: false,
      shiftTasks: false,
      createShift: false,
      endShift: false,
      updateTask: false,
      areaCover: false, // Loading state for area cover operations
      supportServices: false, // Loading state for support service operations
      porterPool: false, // Loading state for porter pool operations
      deleteShift: false
    },
    error: null
  }),
  
  getters: {
    // Get active day shifts (week_day and weekend_day)
    activeDayShifts: (state) => {
      return state.activeShifts.filter(shift => 
        shift.shift_type === 'week_day' || shift.shift_type === 'weekend_day'
      );
    },
    
    // Get active night shifts (week_night and weekend_night)
    activeNightShifts: (state) => {
      return state.activeShifts.filter(shift => 
        shift.shift_type === 'week_night' || shift.shift_type === 'weekend_night'
      );
    },
    
    // Get pending tasks for current shift
    pendingTasks: (state) => {
      return state.shiftTasks.filter(task => task.status === 'pending');
    },
    
    // Get completed tasks for current shift
    completedTasks: (state) => {
      return state.shiftTasks.filter(task => task.status === 'completed');
    },
    
    // Get area cover assignments for current shift sorted by department name
    sortedAreaCoverAssignments: (state) => {
      return [...state.shiftAreaCoverAssignments].sort((a, b) => {
        return a.department.name.localeCompare(b.department.name);
      });
    },
    
    // Get support service assignments for current shift sorted by service name
    sortedSupportServiceAssignments: (state) => {
      return [...state.shiftSupportServiceAssignments].sort((a, b) => {
        return a.service.name.localeCompare(b.service.name);
      });
    },
    
    // Get area cover assignments for day shifts (week_day and weekend_day)
    shiftDayAreaCoverAssignments: (state) => {
      return state.shiftAreaCoverAssignments.filter(assignment => 
        assignment.shift_type === 'week_day' || assignment.shift_type === 'weekend_day'
      );
    },
    
    // Get area cover assignments for night shifts (week_night and weekend_night)
    shiftNightAreaCoverAssignments: (state) => {
      return state.shiftAreaCoverAssignments.filter(assignment => 
        assignment.shift_type === 'week_night' || assignment.shift_type === 'weekend_night'
      );
    },
    
    // Get area cover assignment by ID
    getAreaCoverAssignmentById: (state) => (id) => {
      return state.shiftAreaCoverAssignments.find(a => a.id === id);
    },
    
    // Get support service assignment by ID
    getSupportServiceAssignmentById: (state) => (id) => {
      return state.shiftSupportServiceAssignments.find(a => a.id === id);
    },
    
    // Get porter assignments for a specific area cover assignment
    getPorterAssignmentsByAreaId: (state) => (areaCoverId) => {
      return state.shiftAreaCoverPorterAssignments.filter(
        pa => pa.shift_area_cover_assignment_id === areaCoverId
      );
    },
    
    // Get porter assignments for a specific support service assignment
    getPorterAssignmentsByServiceId: (state) => (serviceId) => {
      if (!serviceId || !state.shiftSupportServicePorterAssignments) {
        return [];
      }
      return state.shiftSupportServicePorterAssignments.filter(
        pa => pa.shift_support_service_assignment_id === serviceId
      ) || [];
    },
    
    // Check for coverage gaps in a specific area cover assignment
    hasAreaCoverageGap: (state) => (areaCoverId) => {
      try {
        const assignment = state.shiftAreaCoverAssignments.find(a => a.id === areaCoverId);
        if (!assignment) return false;
        
        const porterAssignments = state.shiftAreaCoverPorterAssignments.filter(
          pa => pa.shift_area_cover_assignment_id === areaCoverId
        );
        
        if (porterAssignments.length === 0) return true; // No porters means complete gap
        
        // Convert department times to minutes for easier comparison
        const departmentStart = timeToMinutes(assignment.start_time);
        const departmentEnd = timeToMinutes(assignment.end_time);
        
        // First check if any single porter covers the entire time period
        const fullCoverageExists = porterAssignments.some(assignment => {
          const porterStart = timeToMinutes(assignment.start_time);
          const porterEnd = timeToMinutes(assignment.end_time);
          return porterStart <= departmentStart && porterEnd >= departmentEnd;
        });
        
        // If at least one porter provides full coverage, there's no gap
        if (fullCoverageExists) {
          return false;
        }
        
        // Sort porter assignments by start time
        const sortedAssignments = [...porterAssignments].sort((a, b) => {
          return timeToMinutes(a.start_time) - timeToMinutes(b.start_time);
        });
        
        // Check for gap at the beginning
        if (timeToMinutes(sortedAssignments[0].start_time) > departmentStart) {
          return true;
        }
        
        // Check for gaps between porter assignments
        for (let i = 0; i < sortedAssignments.length - 1; i++) {
          const currentEnd = timeToMinutes(sortedAssignments[i].end_time);
          const nextStart = timeToMinutes(sortedAssignments[i + 1].start_time);
          
          if (nextStart > currentEnd) {
            return true;
          }
        }
        
        // Check for gap at the end
        const lastEnd = timeToMinutes(sortedAssignments[sortedAssignments.length - 1].end_time);
        if (lastEnd < departmentEnd) {
          return true;
        }
        
        return false;
      } catch (error) {
        console.error('Error in hasAreaCoverageGap:', error);
        return false;
      }
    },
    
    // Check for coverage gaps in a specific support service assignment
    hasServiceCoverageGap: (state) => (serviceId) => {
      try {
        const assignment = state.shiftSupportServiceAssignments.find(a => a.id === serviceId);
        if (!assignment) return false;
        
        const porterAssignments = state.shiftSupportServicePorterAssignments.filter(
          pa => pa.shift_support_service_assignment_id === serviceId
        );
        
        if (porterAssignments.length === 0) return true; // No porters means complete gap
        
        // Convert service times to minutes for easier comparison
        const serviceStart = timeToMinutes(assignment.start_time);
        const serviceEnd = timeToMinutes(assignment.end_time);
        
        // First check if any single porter covers the entire time period
        const fullCoverageExists = porterAssignments.some(assignment => {
          const porterStart = timeToMinutes(assignment.start_time);
          const porterEnd = timeToMinutes(assignment.end_time);
          return porterStart <= serviceStart && porterEnd >= serviceEnd;
        });
        
        // If at least one porter provides full coverage, there's no gap
        if (fullCoverageExists) {
          return false;
        }
        
        // Sort porter assignments by start time
        const sortedAssignments = [...porterAssignments].sort((a, b) => {
          return timeToMinutes(a.start_time) - timeToMinutes(b.start_time);
        });
        
        // Check for gap at the beginning
        if (timeToMinutes(sortedAssignments[0].start_time) > serviceStart) {
          return true;
        }
        
        // Check for gaps between porter assignments
        for (let i = 0; i < sortedAssignments.length - 1; i++) {
          const currentEnd = timeToMinutes(sortedAssignments[i].end_time);
          const nextStart = timeToMinutes(sortedAssignments[i + 1].start_time);
          
          if (nextStart > currentEnd) {
            return true;
          }
        }
        
        // Check for gap at the end
        const lastEnd = timeToMinutes(sortedAssignments[sortedAssignments.length - 1].end_time);
        if (lastEnd < serviceEnd) {
          return true;
        }
        
        return false;
      } catch (error) {
        console.error('Error in hasServiceCoverageGap:', error);
        return false;
      }
    }
  },
  
  actions: {
    // Fetch all active shifts
    async fetchActiveShifts() {
      this.loading.activeShifts = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shifts')
          .select(`
            *,
            supervisor:supervisor_id(id, first_name, last_name, role)
          `)
          .eq('is_active', true)
          .order('start_time', { ascending: false });
        
        if (error) throw error;
        
        this.activeShifts = data || [];
      } catch (error) {
        console.error('Error fetching active shifts:', error);
        this.error = 'Failed to load active shifts';
      } finally {
        this.loading.activeShifts = false;
      }
    },
    
    // Fetch all archived shifts
    async fetchArchivedShifts() {
      this.loading.archivedShifts = true;
      this.error = null;
      
      try {
        console.log('Fetching archived shifts from database...');
        
        // First check that archived shifts exist
        const { count, error: countError } = await supabase
          .from('shifts')
          .select('*', { count: 'exact', head: true })
          .eq('is_active', false);
          
        if (countError) {
          console.error('Error counting archived shifts:', countError);
          throw countError;
        }
        
        console.log(`Found ${count} archived shifts in database`);
        
        // If no archived shifts, set empty array and return early
        if (count === 0) {
          this.archivedShifts = [];
          return;
        }
        
        // Fetch the actual shifts with supervisor data
        const { data, error } = await supabase
          .from('shifts')
          .select(`
            *,
            supervisor:supervisor_id(id, first_name, last_name, role)
          `)
          .eq('is_active', false)
          .order('end_time', { ascending: false });
        
        if (error) {
          console.error('Error fetching archived shifts data:', error);
          throw error;
        }
        
        console.log(`Retrieved ${data?.length || 0} archived shifts with supervisor data`);
        
        // Check if we got the expected number of shifts
        if (data && data.length !== count) {
          console.warn(`Count mismatch: Expected ${count} archived shifts but received ${data.length}`);
        }
        
        // Check for shifts with missing end_time and fix them
        const shiftsWithoutEndTime = data?.filter(shift => !shift.end_time) || [];
        if (shiftsWithoutEndTime.length > 0) {
          console.warn(`Found ${shiftsWithoutEndTime.length} archived shifts with missing end_time`);
        }
        
        this.archivedShifts = data || [];
      } catch (error) {
        console.error('Error fetching archived shifts:', error);
        this.error = 'Failed to load archived shifts';
      } finally {
        this.loading.archivedShifts = false;
      }
    },
    
    // Fetch a specific shift by ID
    async fetchShiftById(shiftId) {
      this.loading.currentShift = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shifts')
          .select(`
            *,
            supervisor:supervisor_id(id, first_name, last_name, role)
          `)
          .eq('id', shiftId)
          .single();
        
        if (error) throw error;
        
        this.currentShift = data;
        return data;
      } catch (error) {
        console.error('Error fetching shift:', error);
        this.error = 'Failed to load shift details';
        return null;
      } finally {
        this.loading.currentShift = false;
      }
    },
    
    // Fetch tasks for a specific shift
    async fetchShiftTasks(shiftId) {
      this.loading.shiftTasks = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_tasks')
          .select(`
            *,
            task_item:task_item_id(id, name, description, task_type_id),
            porter:porter_id(id, first_name, last_name),
            origin_department:origin_department_id(id, name, building_id),
            destination_department:destination_department_id(id, name, building_id)
          `)
          .eq('shift_id', shiftId)
          .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        this.shiftTasks = data || [];
        return data;
      } catch (error) {
        console.error('Error fetching shift tasks:', error);
        this.error = 'Failed to load shift tasks';
        return [];
      } finally {
        this.loading.shiftTasks = false;
      }
    },
    
    // Create a new shift
    async createShift(supervisorId, shiftType, startTime = null) {
      this.loading.createShift = true;
      this.error = null;
      
      try {
        // Use provided start time or default to current time
        const shiftStartTime = startTime || new Date().toISOString();
        
        console.log(`Creating new shift with supervisor: ${supervisorId}, type: ${shiftType}, start time: ${shiftStartTime}`);
        
        const { data, error } = await supabase
          .from('shifts')
          .insert({
            supervisor_id: supervisorId,
            shift_type: shiftType,
            start_time: shiftStartTime,
            is_active: true
          })
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const newShift = data[0];
          console.log(`Created new shift with ID: ${newShift.id}, type: ${newShift.shift_type}`);
          
          // Add the new shift to activeShifts array
          this.activeShifts.unshift(newShift);
          
          // The database trigger will automatically copy default assignments
          // Let's just fetch the assignments to update our local state
          await this.fetchShiftAreaCover(newShift.id);
          await this.fetchShiftSupportServices(newShift.id);
          
          return newShift;
        }
        
        return null;
      } catch (error) {
        console.error('Error creating shift:', error);
        this.error = 'Failed to create shift';
        return null;
      } finally {
        this.loading.createShift = false;
      }
    },
    
    // End an active shift
    async endShift(shiftId) {
      this.loading.endShift = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shifts')
          .update({
            end_time: new Date().toISOString(),
            is_active: false
          })
          .eq('id', shiftId)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Remove the shift from activeShifts array
          this.activeShifts = this.activeShifts.filter(shift => shift.id !== shiftId);
          
          // If this was the current shift, update it
          if (this.currentShift && this.currentShift.id === shiftId) {
            this.currentShift = data[0];
          }
          
          // Add to archived shifts if we have that loaded
          if (this.archivedShifts.length > 0) {
            this.archivedShifts.unshift(data[0]);
          }
          
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error ending shift:', error);
        this.error = 'Failed to end shift';
        return null;
      } finally {
        this.loading.endShift = false;
      }
    },
    
    // Add a task to a shift
    async addTaskToShift(shiftId, taskData) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        // First check if the shift is active
        const { data: shift } = await supabase
          .from('shifts')
          .select('is_active')
          .eq('id', shiftId)
          .single();
          
        if (!shift || !shift.is_active) {
          this.error = 'Cannot add tasks to archived shifts';
          return null;
        }
        
        // Create default time strings for the task if not provided
        const now = new Date();
        const hours = String(now.getHours()).padStart(2, '0');
        const minutes = String(now.getMinutes()).padStart(2, '0');
        const nowTimeString = `${hours}:${minutes}`;
        
        // Calculate time_allocated (+1 minute from now)
        const allocatedMinutes = now.getMinutes() + 1;
        const allocatedHours = now.getHours() + Math.floor(allocatedMinutes / 60);
        const normalizedAllocatedMinutes = allocatedMinutes % 60;
        const allocatedTimeString = `${String(allocatedHours % 24).padStart(2, '0')}:${String(normalizedAllocatedMinutes).padStart(2, '0')}`;
        
        // Calculate time_completed (+20 minutes from now)
        const completedMinutes = now.getMinutes() + 20;
        const completedHours = now.getHours() + Math.floor(completedMinutes / 60);
        const normalizedCompletedMinutes = completedMinutes % 60;
        const completedTimeString = `${String(completedHours % 24).padStart(2, '0')}:${String(normalizedCompletedMinutes).padStart(2, '0')}`;
        
        // Use provided time values or default ones
        const taskInsertData = {
          shift_id: shiftId,
          task_item_id: taskData.taskItemId,
          porter_id: taskData.porterId || null,
          origin_department_id: taskData.originDepartmentId || null,
          destination_department_id: taskData.destinationDepartmentId || null,
          status: taskData.status || 'pending',
          time_received: taskData.time_received || nowTimeString,
          time_allocated: taskData.time_allocated || allocatedTimeString,
          time_completed: taskData.time_completed || completedTimeString
        };
        
        // Proceed with adding the task
        const { data, error } = await supabase
          .from('shift_tasks')
          .insert(taskInsertData)
          .select(`
            *,
            task_item:task_item_id(id, name, description, task_type_id),
            porter:porter_id(id, first_name, last_name),
            origin_department:origin_department_id(id, name, building_id),
            destination_department:destination_department_id(id, name, building_id)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add the new task to shiftTasks array
          this.shiftTasks.unshift(data[0]);
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error adding task to shift:', error);
        this.error = 'Failed to add task';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Update task status
    async updateTaskStatus(taskId, status) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        // First, get the current task to check the current status
        const { data: existingTask, error: fetchError } = await supabase
          .from('shift_tasks')
          .select('*')
          .eq('id', taskId)
          .single();
        
        if (fetchError) throw fetchError;
        
        let updates = { status };
        
        // If we're changing from completed to pending (reopening a completed task)
        // we keep all the original times as they were
        if (existingTask.status === 'completed' && status === 'pending') {
          // No time field updates needed - we keep the original times
          console.log('Reopening completed task - keeping original times');
        }
        // If we're marking a task as pending (but it wasn't completed)
        // we need to update the time_allocated and time_completed fields
        else if (status === 'pending' && existingTask.status === 'pending') {
          // Get current time
          const now = new Date();
          const hours = String(now.getHours()).padStart(2, '0');
          const minutes = String(now.getMinutes()).padStart(2, '0');
          const nowTimeString = `${hours}:${minutes}`;
          
          // Calculate time_completed (+20 minutes from now)
          const completedMinutes = now.getMinutes() + 20;
          const completedHours = now.getHours() + Math.floor(completedMinutes / 60);
          const normalizedCompletedMinutes = completedMinutes % 60;
          const completedTimeString = `${String(completedHours % 24).padStart(2, '0')}:${String(normalizedCompletedMinutes).padStart(2, '0')}`;
          
          // Update timestamps, but keep the original time_received
          updates = {
            ...updates,
            time_allocated: nowTimeString,
            time_completed: completedTimeString
          };
          
          console.log('Reopening pending task - updating time_allocated and time_completed');
        }
        
        // If we're changing from pending to completed (completing a task)
        // we keep the expected completion time already stored in the task
        else if (existingTask.status === 'pending' && status === 'completed') {
          // No time field updates needed - we keep the existing time_completed value
          console.log('Completing task - using existing expected completion time');
        }
        
        // Update the task with the new status and any time changes
        const { data, error } = await supabase
          .from('shift_tasks')
          .update(updates)
          .eq('id', taskId)
          .select(`
            *,
            task_item:task_item_id(id, name, description, task_type_id),
            porter:porter_id(id, first_name, last_name),
            origin_department:origin_department_id(id, name, building_id),
            destination_department:destination_department_id(id, name, building_id)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the task in shiftTasks array
          const index = this.shiftTasks.findIndex(task => task.id === taskId);
          if (index !== -1) {
            this.shiftTasks[index] = data[0];
          }
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error updating task status:', error);
        this.error = 'Failed to update task status';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Assign porter to task
    async assignPorterToTask(taskId, porterId) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_tasks')
          .update({ porter_id: porterId })
          .eq('id', taskId)
          .select(`
            *,
            task_item:task_item_id(id, name, description, task_type_id),
            porter:porter_id(id, first_name, last_name),
            origin_department:origin_department_id(id, name, building_id),
            destination_department:destination_department_id(id, name, building_id)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the task in shiftTasks array
          const index = this.shiftTasks.findIndex(task => task.id === taskId);
          if (index !== -1) {
            this.shiftTasks[index] = data[0];
          }
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error assigning porter to task:', error);
        this.error = 'Failed to assign porter to task';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Update an existing task
    async updateTask(taskId, taskData) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        // Build update object with required fields
        const updateObj = {
          task_item_id: taskData.taskItemId,
          porter_id: taskData.porterId || null,
          origin_department_id: taskData.originDepartmentId || null,
          destination_department_id: taskData.destinationDepartmentId || null,
          status: taskData.status
        };
        
        // Extract just the time part (HH:MM) from any time values provided
        // This handles both the old-style ISO dates and new-style direct time inputs
        if (taskData.time_received) {
          // Check if we received a full datetime string (old format)
          if (taskData.time_received.includes('T')) {
            const date = new Date(taskData.time_received);
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            updateObj.time_received = `${hours}:${minutes}`;
          } else {
            // Otherwise, use the provided time string directly (likely already in HH:MM format)
            updateObj.time_received = taskData.time_received;
          }
        }
        
        if (taskData.time_allocated) {
          if (taskData.time_allocated.includes('T')) {
            const date = new Date(taskData.time_allocated);
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            updateObj.time_allocated = `${hours}:${minutes}`;
          } else {
            updateObj.time_allocated = taskData.time_allocated;
          }
        }
        
        if (taskData.time_completed) {
          if (taskData.time_completed.includes('T')) {
            const date = new Date(taskData.time_completed);
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            updateObj.time_completed = `${hours}:${minutes}`;
          } else {
            updateObj.time_completed = taskData.time_completed;
          }
        }
        
        const { data, error } = await supabase
          .from('shift_tasks')
          .update(updateObj)
          .eq('id', taskId)
          .select(`
            *,
            task_item:task_item_id(id, name, description, task_type_id),
            porter:porter_id(id, first_name, last_name),
            origin_department:origin_department_id(id, name, building_id),
            destination_department:destination_department_id(id, name, building_id)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the task in shiftTasks array
          const index = this.shiftTasks.findIndex(task => task.id === taskId);
          if (index !== -1) {
            this.shiftTasks[index] = data[0];
          }
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error updating task:', error);
        this.error = 'Failed to update task';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Clear current shift and tasks
    clearCurrentShift() {
      this.currentShift = null;
      this.shiftTasks = [];
    },
    
    // Initialize store data
    async initialize() {
      await this.fetchActiveShifts();
    },
    
    // Area Cover Management
    
    // Fetch area cover assignments for a specific shift
    async fetchShiftAreaCover(shiftId) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        console.log(`fetchShiftAreaCover called for shift ID: ${shiftId}`);
        
        // Check if the shift exists first
        const { data: shiftData, error: shiftError } = await supabase
          .from('shifts')
          .select('id, shift_type')
          .eq('id', shiftId)
          .single();
        
        if (shiftError) {
          console.error('Error checking shift:', shiftError);
          throw shiftError;
        }
        
        if (!shiftData) {
          console.error(`No shift found with ID: ${shiftId}`);
          return [];
        }
        
        console.log(`Found shift: ${shiftData.id}, type: ${shiftData.shift_type}`);
        
        // Query shift area cover assignments
        console.log(`Fetching area cover assignments for shift: ${shiftId}`);
        const { data, error } = await supabase
          .from('shift_area_cover_assignments')
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              building:building_id(id, name)
            )
          `)
          .eq('shift_id', shiftId);
        
        if (error) {
          console.error('Error fetching shift area cover assignments:', error);
          throw error;
        }
        
        console.log(`Fetched ${data?.length || 0} area cover assignments`);
        
        // Store the assignments
        this.shiftAreaCoverAssignments = data || [];
        
        // Also fetch porter assignments for these area cover assignments
        const assignmentIds = data?.map(a => a.id) || [];
        
        if (assignmentIds.length > 0) {
          console.log(`Fetching porter assignments for ${assignmentIds.length} area cover assignments`);
          
          const { data: porterData, error: porterError } = await supabase
            .from('shift_area_cover_porter_assignments')
            .select(`
              *,
              porter:porter_id(id, first_name, last_name),
              shift_area_cover_assignment:shift_area_cover_assignment_id(
                id,
                color,
                department:department_id(id, name)
              )
            `)
            .in('shift_area_cover_assignment_id', assignmentIds);
          
          if (porterError) {
            console.error('Error fetching area cover porter assignments:', porterError);
            throw porterError;
          }
          
          console.log(`Fetched ${porterData?.length || 0} porter assignments for area cover`);
          
          // Store the porter assignments
          this.shiftAreaCoverPorterAssignments = porterData || [];
        } else {
          // No area cover assignments, so no porter assignments
          this.shiftAreaCoverPorterAssignments = [];
        }
        
        return this.shiftAreaCoverAssignments;
      } catch (error) {
        console.error('Error fetching shift area cover:', error);
        this.error = 'Failed to load area coverage';
        return [];
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Add a new area cover assignment to a shift
    async addShiftAreaCover(shiftId, departmentId, startTime, endTime, color = '#4285F4') {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_area_cover_assignments')
          .insert({
            shift_id: shiftId,
            department_id: departmentId,
            start_time: startTime,
            end_time: endTime,
            color: color
          })
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              building:building_id(id, name)
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to local state
          this.shiftAreaCoverAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding area cover to shift:', error);
        this.error = 'Failed to add area cover to shift';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Update a shift area cover assignment
    async updateShiftAreaCover(assignmentId, updates) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_area_cover_assignments')
          .update(updates)
          .eq('id', assignmentId)
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              building:building_id(id, name)
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update in local state
          const index = this.shiftAreaCoverAssignments.findIndex(a => a.id === assignmentId);
          if (index !== -1) {
            this.shiftAreaCoverAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating shift area cover:', error);
        this.error = 'Failed to update area cover';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Remove a shift area cover assignment
    async removeShiftAreaCover(assignmentId) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_area_cover_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftAreaCoverAssignments = this.shiftAreaCoverAssignments.filter(a => a.id !== assignmentId);
        
        // Also remove all associated porter assignments
        this.shiftAreaCoverPorterAssignments = this.shiftAreaCoverPorterAssignments.filter(
          pa => pa.shift_area_cover_assignment_id !== assignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing shift area cover:', error);
        this.error = 'Failed to remove area cover';
        return false;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Add a porter to a shift area cover assignment
    async addShiftAreaCoverPorter(areaCoverId, porterId, startTime, endTime) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_area_cover_porter_assignments')
          .insert({
            shift_area_cover_assignment_id: areaCoverId,
            porter_id: porterId,
            start_time: startTime,
            end_time: endTime
          })
          .select(`
            *,
            porter:porter_id(id, first_name, last_name),
            shift_area_cover_assignment:shift_area_cover_assignment_id(
              id,
              color,
              department:department_id(id, name)
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to local state
          this.shiftAreaCoverPorterAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding porter to shift area cover:', error);
        this.error = 'Failed to add porter to area cover';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Update a shift area cover porter assignment
    async updateShiftAreaCoverPorter(porterAssignmentId, updates) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_area_cover_porter_assignments')
          .update(updates)
          .eq('id', porterAssignmentId)
          .select(`
            *,
            porter:porter_id(id, first_name, last_name),
            shift_area_cover_assignment:shift_area_cover_assignment_id(
              id,
              color,
              department:department_id(id, name)
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update in local state
          const index = this.shiftAreaCoverPorterAssignments.findIndex(pa => pa.id === porterAssignmentId);
          if (index !== -1) {
            this.shiftAreaCoverPorterAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating shift area cover porter assignment:', error);
        this.error = 'Failed to update porter assignment';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Remove a porter from a shift area cover assignment
    async removeShiftAreaCoverPorter(porterAssignmentId) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_area_cover_porter_assignments')
          .delete()
          .eq('id', porterAssignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftAreaCoverPorterAssignments = this.shiftAreaCoverPorterAssignments.filter(
          pa => pa.id !== porterAssignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing porter from shift area cover:', error);
        this.error = 'Failed to remove porter assignment';
        return false;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Fetch support service assignments for a specific shift
    async fetchShiftSupportServices(shiftId) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        console.log(`Fetching support service assignments for shift: ${shiftId}`);
        
        // Query shift support service assignments
        const { data, error } = await supabase
          .from('shift_support_service_assignments')
          .select(`
            *,
            service:service_id(
              id,
              name,
              description
            )
          `)
          .eq('shift_id', shiftId);
        
        if (error) {
          console.error('Error fetching shift support service assignments:', error);
          throw error;
        }
        
        console.log(`Fetched ${data?.length || 0} support service assignments`);
        
        // Store the assignments
        this.shiftSupportServiceAssignments = data || [];
        
        // Also fetch porter assignments for these support service assignments
        const assignmentIds = data?.map(a => a.id) || [];
        
        if (assignmentIds.length > 0) {
          console.log(`Fetching porter assignments for ${assignmentIds.length} support service assignments`);
          
          const { data: porterData, error: porterError } = await supabase
            .from('shift_support_service_porter_assignments')
            .select(`
              *,
              porter:porter_id(id, first_name, last_name)
            `)
            .in('shift_support_service_assignment_id', assignmentIds);
          
          if (porterError) {
            console.error('Error fetching support service porter assignments:', porterError);
            throw porterError;
          }
          
          console.log(`Fetched ${porterData?.length || 0} porter assignments for support services`);
          
          // Store the porter assignments
          this.shiftSupportServicePorterAssignments = porterData || [];
        } else {
          // No support service assignments, so no porter assignments
          this.shiftSupportServicePorterAssignments = [];
        }
        
        return this.shiftSupportServiceAssignments;
      } catch (error) {
        console.error('Error fetching shift support services:', error);
        this.error = 'Failed to load support services';
        return [];
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Add a new support service assignment to a shift
    async addShiftSupportService(shiftId, serviceId, startTime, endTime, color = '#4285F4') {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_support_service_assignments')
          .insert({
            shift_id: shiftId,
            service_id: serviceId,
            start_time: startTime,
            end_time: endTime,
            color: color
          })
          .select(`
            *,
            service:service_id(
              id,
              name,
              description
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to local state
          this.shiftSupportServiceAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding support service to shift:', error);
        this.error = 'Failed to add support service to shift';
        return null;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Update a shift support service assignment
    async updateShiftSupportService(assignmentId, updates) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_support_service_assignments')
          .update(updates)
          .eq('id', assignmentId)
          .select(`
            *,
            service:service_id(
              id,
              name,
              description
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update in local state
          const index = this.shiftSupportServiceAssignments.findIndex(a => a.id === assignmentId);
          if (index !== -1) {
            this.shiftSupportServiceAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating shift support service:', error);
        this.error = 'Failed to update support service';
        return null;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Remove a shift support service assignment
    async removeShiftSupportService(assignmentId) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_support_service_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftSupportServiceAssignments = this.shiftSupportServiceAssignments.filter(a => a.id !== assignmentId);
        
        // Also remove all associated porter assignments
        this.shiftSupportServicePorterAssignments = this.shiftSupportServicePorterAssignments.filter(
          pa => pa.shift_support_service_assignment_id !== assignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing shift support service:', error);
        this.error = 'Failed to remove support service';
        return false;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Add a porter to a shift support service assignment
    async addShiftSupportServicePorter(serviceId, porterId, startTime, endTime) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_support_service_porter_assignments')
          .insert({
            shift_support_service_assignment_id: serviceId,
            porter_id: porterId,
            start_time: startTime,
            end_time: endTime
          })
          .select(`
            *,
            porter:porter_id(id, first_name, last_name)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to local state
          this.shiftSupportServicePorterAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding porter to shift support service:', error);
        this.error = 'Failed to add porter to support service';
        return null;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Update a shift support service porter assignment
    async updateShiftSupportServicePorter(porterAssignmentId, updates) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_support_service_porter_assignments')
          .update(updates)
          .eq('id', porterAssignmentId)
          .select(`
            *,
            porter:porter_id(id, first_name, last_name)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update in local state
          const index = this.shiftSupportServicePorterAssignments.findIndex(pa => pa.id === porterAssignmentId);
          if (index !== -1) {
            this.shiftSupportServicePorterAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating shift support service porter assignment:', error);
        this.error = 'Failed to update porter assignment';
        return null;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Remove a porter from a shift support service assignment
    async removeShiftSupportServicePorter(porterAssignmentId) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_support_service_porter_assignments')
          .delete()
          .eq('id', porterAssignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftSupportServicePorterAssignments = this.shiftSupportServicePorterAssignments.filter(
          pa => pa.id !== porterAssignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing porter from shift support service:', error);
        this.error = 'Failed to remove porter assignment';
        return false;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Fetch porter pool for a specific shift
    async fetchShiftPorterPool(shiftId) {
      this.loading.porterPool = true;
      this.error = null;
      
      try {
        // Query shift porter pool
        const { data, error } = await supabase
          .from('shift_porter_pool')
          .select(`
            *,
            porter:porter_id(id, first_name, last_name)
          `)
          .eq('shift_id', shiftId);
        
        if (error) {
          console.error('Error fetching shift porter pool:', error);
          throw error;
        }
        
        console.log(`Fetched ${data?.length || 0} porters in pool for shift ${shiftId}`);
        
        // Store the porter pool
        this.shiftPorterPool = data || [];
        
        return this.shiftPorterPool;
      } catch (error) {
        console.error('Error fetching shift porter pool:', error);
        this.error = 'Failed to load shift porter pool';
        return [];
      } finally {
        this.loading.porterPool = false;
      }
    },

    // Add a porter to a shift's porter pool
    async addPorterToShift(shiftId, porterId) {
      this.loading.porterPool = true;
      this.error = null;
      
      try {
        // Add porter to shift pool
        const { data, error } = await supabase
          .from('shift_porter_pool')
          .insert({
            shift_id: shiftId,
            porter_id: porterId
          })
          .select(`
            *,
            porter:porter_id(id, first_name, last_name)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to local state
          this.shiftPorterPool.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding porter to shift:', error);
        this.error = 'Failed to add porter to shift';
        return null;
      } finally {
        this.loading.porterPool = false;
      }
    },
    
    // Remove a porter from a shift's porter pool
    async removePorterFromShift(porterPoolId) {
      this.loading.porterPool = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_porter_pool')
          .delete()
          .eq('id', porterPoolId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftPorterPool = this.shiftPorterPool.filter(p => p.id !== porterPoolId);
        
        return true;
      } catch (error) {
        console.error('Error removing porter from shift:', error);
        this.error = 'Failed to remove porter from shift';
        return false;
      } finally {
        this.loading.porterPool = false;
      }
    },
    
    // Fetch task counts for archived shifts
    async fetchArchivedShiftTaskCounts() {
      this.error = null;
      
      try {
        console.log('Fetching task counts for archived shifts...');
        
        // Get the shift IDs for which we need to fetch task counts
        const shiftIds = this.archivedShifts.map(shift => shift.id);
        
        if (shiftIds.length === 0) {
          console.log('No archived shifts to fetch task counts for');
          return {};
        }

        // We'll try a different approach - fetch all tasks for the archived shifts
        // and then count them manually
        const { data, error } = await supabase
          .from('shift_tasks')
          .select('shift_id')
          .in('shift_id', shiftIds);
        
        if (error) {
          console.error('Error fetching shift tasks:', error);
          throw error;
        }
        
        console.log(`Fetched ${data?.length || 0} tasks for archived shifts`);
        
        // Create a mapping of shift ID to task count by counting tasks manually
        const taskCounts = {};
        
        // Initialize counts for all shifts to 0
        shiftIds.forEach(id => {
          taskCounts[id] = 0;
        });
        
        // Count tasks for each shift
        if (data && data.length > 0) {
          data.forEach(task => {
            if (task.shift_id) {
              taskCounts[task.shift_id] = (taskCounts[task.shift_id] || 0) + 1;
            }
          });
        }
        
        console.log('Task counts:', taskCounts);
        
        // Store the task counts
        this.archivedShiftTaskCounts = taskCounts;
        
        return taskCounts;
      } catch (error) {
        console.error('Error in fetchArchivedShiftTaskCounts:', error);
        this.error = 'Failed to load task counts';
        return {};
      }
    },
    
    // Delete a shift
    async deleteShift(shiftId) {
      this.loading.deleteShift = true;
      this.error = null;
      
      try {
        // Delete the shift
        const { error } = await supabase
          .from('shifts')
          .delete()
          .eq('id', shiftId);
        
        if (error) throw error;
        
        // Remove from local state
        this.archivedShifts = this.archivedShifts.filter(shift => shift.id !== shiftId);
        
        return true;
      } catch (error) {
        console.error('Error deleting shift:', error);
        this.error = 'Failed to delete shift';
        return false;
      } finally {
        this.loading.deleteShift = false;
      }
    }
  }
});
