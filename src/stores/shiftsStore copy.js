import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

// Helper function to determine if a date is on a weekend
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}

// Helper function to determine if a time is during day shift hours
function isDayShift(date, dayStart, dayEnd) {
  const hours = date.getHours();
  const minutes = date.getMinutes();
  const timeInMinutes = hours * 60 + minutes;
  
  const [dayStartHours, dayStartMinutes] = dayStart.split(':').map(Number);
  const [dayEndHours, dayEndMinutes] = dayEnd.split(':').map(Number);
  
  const dayStartInMinutes = dayStartHours * 60 + dayStartMinutes;
  const dayEndInMinutes = dayEndHours * 60 + dayEndMinutes;
  
  return timeInMinutes >= dayStartInMinutes && timeInMinutes < dayEndInMinutes;
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
    // Get active day shifts
    activeDayShifts: (state) => {
      return state.activeShifts.filter(shift => shift.shift_type === 'day');
    },
    
    // Get active night shifts
    activeNightShifts: (state) => {
      return state.activeShifts.filter(shift => shift.shift_type === 'night');
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
    
    // Get area cover assignments for day shift
    shiftDayAreaCoverAssignments: (state) => {
      return state.shiftAreaCoverAssignments.filter(assignment => 
        assignment.shift_type === 'day'
      );
    },
    
    // Get area cover assignments for night shift
    shiftNightAreaCoverAssignments: (state) => {
      return state.shiftAreaCoverAssignments.filter(assignment => 
        assignment.shift_type === 'night'
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
      return state.shiftSupportServicePorterAssignments.filter(
        pa => pa.shift_support_service_assignment_id === serviceId
      );
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
        const { data, error } = await supabase
          .from('shifts')
          .select(`
            *,
            supervisor:supervisor_id(id, first_name, last_name, role)
          `)
          .eq('is_active', false)
          .order('end_time', { ascending: false });
        
        if (error) throw error;
        
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
    async createShift(supervisorId, shiftType) {
      this.loading.createShift = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shifts')
          .insert({
            supervisor_id: supervisorId,
            shift_type: shiftType,
            start_time: new Date().toISOString(),
            is_active: true
          })
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add the new shift to activeShifts array
          this.activeShifts.unshift(data[0]);
          return data[0];
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
        
        if (error) throw error;
        
        this.shiftAreaCoverAssignments = data || [];
        
        // Fetch porter assignments for these area covers
        if (data && data.length > 0) {
          const areaCoverIds = data.map(a => a.id);
          await this.fetchShiftAreaCoverPorterAssignments(areaCoverIds);
        }
        
        return this.shiftAreaCoverAssignments;
      } catch (error) {
        console.error('Error fetching shift area cover:', error);
        this.error = 'Failed to load area cover assignments';
        return [];
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Fetch porter assignments for shift area cover
    async fetchShiftAreaCoverPorterAssignments(areaCoverIds) {
      if (!areaCoverIds || areaCoverIds.length === 0) return [];
      
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_area_cover_porter_assignments')
          .select(`
            *,
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `)
          .in('shift_area_cover_assignment_id', areaCoverIds);
        
        if (error) throw error;
        
        this.shiftAreaCoverPorterAssignments = data || [];
        return data;
      } catch (error) {
        console.error('Error fetching porter assignments for area cover:', error);
        this.error = 'Failed to load porter assignments';
        return [];
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Porter Pool Management
    
    // Fetch porters assigned to a specific shift
    async fetchShiftPorterPool(shiftId) {
      this.loading.porterPool = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_porter_pool')
          .select(`
            *,
            porter:porter_id(
              id,
              first_name,
              last_name,
              role
            )
          `)
          .eq('shift_id', shiftId);
        
        if (error) throw error;
        
        this.shiftPorterPool = data || [];
        return data;
      } catch (error) {
        console.error('Error fetching shift porter pool:', error);
        this.error = 'Failed to load porter pool';
        return [];
      } finally {
        this.loading.porterPool = false;
      }
    },
    
    // Add porter to shift porter pool
    async addPorterToShift(shiftId, porterId) {
      this.loading.porterPool = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_porter_pool')
          .insert({
            shift_id: shiftId,
            porter_id: porterId
          })
          .select(`
            *,
            porter:porter_id(
              id,
              first_name,
              last_name,
              role
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to porter pool array
          this.shiftPorterPool.push(data[0]);
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error adding porter to shift:', error);
        this.error = 'Failed to add porter to shift';
        return null;
      } finally {
        this.loading.porterPool = false;
      }
    },
    
    // Remove porter from shift porter pool
    async removePorterFromShift(porterPoolId) {
      this.loading.porterPool = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_porter_pool')
          .delete()
          .eq('id', porterPoolId);
        
        if (error) throw error;
        
        // Remove from porter pool array
        this.shiftPorterPool = this.shiftPorterPool.filter(p => p.id !== porterPoolId);
        
        return true;
      } catch (error) {
        console.error('Error removing porter from shift:', error);
        this.error = 'Failed to remove porter from shift';
        return false;
      } finally {
        this.loading.porterPool = false;
      }
    }
  }
});
