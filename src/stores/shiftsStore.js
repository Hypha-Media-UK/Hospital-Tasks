import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

// Helper function to determine if a date is on a weekend
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}

// Removed legacy isDayShift function

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
      console.log(`shiftsStore.createShift called with supervisor: ${supervisorId}, type: ${shiftType}`);
      
      const { data, error } = await supabase
        .from('shifts')
        .insert({
          supervisor_id: supervisorId,
          shift_type: shiftType, // Using specific shift type (week_day, week_night, etc.)
          start_time: new Date().toISOString(),
          is_active: true
        })
        .select();
      
      if (error) throw error;
      
      if (data && data.length > 0) {
        const newShift = data[0];
        console.log(`Created new shift with ID: ${newShift.id}, type: ${newShift.shift_type}`);
        
        // Add the new shift to activeShifts array
        this.activeShifts.unshift(newShift);
        
        // First, directly verify that there are default assignments for this shift type
        const { useAreaCoverStore } = await import('./areaCoverStore');
        const areaCoverStore = useAreaCoverStore();
        await areaCoverStore.initialize();
        
        // Log the state of area cover assignments
        console.log(`BEFORE SETUP - Area cover store state for ${shiftType}:`, 
          areaCoverStore[`${shiftType}Assignments`]?.length || 0, 'assignments');
        
        if (areaCoverStore[`${shiftType}Assignments`]?.length > 0) {
          console.log('Default assignments exist:', 
            areaCoverStore[`${shiftType}Assignments`].map(a => 
              `${a.department?.name || 'Unknown'} (ID: ${a.department_id})`));
        } else {
          console.log('NO DEFAULT ASSIGNMENTS FOUND IN THE STORE!');
          console.log('This indicates the database is missing entries for this shift type.');
        }
        
        // Copy area cover assignments from settings based on shift type
        console.log(`Calling setupShiftAreaCoverFromDefaults(${newShift.id}, ${shiftType})`);
        const result = await this.setupShiftAreaCoverFromDefaults(newShift.id, shiftType);
        console.log('Setup result:', result);
        
        // Verify the assignments were added
        const assignments = await this.fetchShiftAreaCover(newShift.id);
        console.log(`After setup, found ${assignments.length} area cover assignments for shift ${newShift.id}`);
        
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
    
    // Copy area cover assignments from defaults to a new shift
    async setupShiftAreaCoverFromDefaults(shiftId, shiftType) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        console.log(`Setting up area coverage for shift ID: ${shiftId}, type: ${shiftType}`);
        
        // Import areaCoverStore
        const { useAreaCoverStore } = await import('./areaCoverStore');
        const areaCoverStore = useAreaCoverStore();
        
        // Initialize the store
        await areaCoverStore.initialize();
        
        // Ensure the shift type is valid
        if (!['week_day', 'week_night', 'weekend_day', 'weekend_night'].includes(shiftType)) {
          console.error(`Invalid shift type: ${shiftType}. Must be one of: week_day, week_night, weekend_day, weekend_night`);
          return false;
        }
        
        // Use the provided shift type directly
        const areaCoverType = shiftType;
        console.log(`Setting up area coverage for new ${areaCoverType} shift`);
        
        // Make sure we have the default assignments loaded - different naming conventions
        // week_day -> weekDayAssignments, week_night -> weekNightAssignments, etc.
        // Convert shift_type to store property name
        let storePropertyName;
        switch(areaCoverType) {
          case 'week_day':
            storePropertyName = 'weekDayAssignments';
            break;
          case 'week_night':
            storePropertyName = 'weekNightAssignments';
            break;
          case 'weekend_day':
            storePropertyName = 'weekendDayAssignments';
            break;
          case 'weekend_night':
            storePropertyName = 'weekendNightAssignments';
            break;
          default:
            storePropertyName = null;
        }
        
        console.log(`Looking for assignments in areaCoverStore.${storePropertyName}`);
        
        // If the store doesn't have assignments for this type, fetch them
        if (!areaCoverStore[storePropertyName]?.length) {
          console.log(`No assignments found in store.${storePropertyName}, fetching...`);
          await areaCoverStore.fetchAssignments(areaCoverType);
        }
        
        // Get the default assignments for this shift type
        const defaultAssignments = areaCoverStore[storePropertyName] || [];
        
        console.log(`Found ${defaultAssignments.length} default assignments to copy`);
        console.log('Default assignments:', JSON.stringify(defaultAssignments));
        
        // Copy each default assignment to the new shift
        for (const assignment of defaultAssignments) {
          console.log(`Adding assignment for department ${assignment.department_id} to shift ${shiftId}`);
          await this.addShiftAreaCover(
            shiftId,
            assignment.department_id,
            assignment.start_time,
            assignment.end_time,
            assignment.color
          );
        }
        
        // Verify the assignments were added
        const assignments = await this.fetchShiftAreaCover(shiftId);
        console.log(`After adding, shift has ${assignments.length} area cover assignments`);
        
        // Setup support services as well
        await this.setupShiftSupportServicesFromDefaults(shiftId, shiftType);
        
        return true;
      } catch (error) {
        console.error('Error setting up shift area cover from defaults:', error);
        this.error = 'Failed to set up default area coverage';
        return false;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Copy support service assignments from defaults to a new shift
    async setupShiftSupportServicesFromDefaults(shiftId, shiftType) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        // Import supportServicesStore
        const { useSupportServicesStore } = await import('./supportServicesStore');
        const supportServicesStore = useSupportServicesStore();
        
        // Use the provided shift type directly - no conversion needed
        const serviceType = shiftType;
        
        console.log(`Setting up support services for new ${serviceType} shift`);
        
        // Make sure we have the default assignments loaded
        await supportServicesStore.loadAllServiceAssignments();
        
        // Get the default assignments for this shift type
        const defaultServiceAssignments = supportServicesStore.serviceAssignments[serviceType] || [];
        
        console.log(`Found ${defaultServiceAssignments.length} default service assignments to copy`);
        
        // Copy each default service assignment to the new shift
        // (Note: we need to add addShiftSupportService method)
        for (const assignment of defaultServiceAssignments) {
          await this.addShiftSupportService(
            shiftId,
            assignment.service.id,
            assignment.start_time,
            assignment.end_time,
            assignment.color
          );
        }
        
        return true;
      } catch (error) {
        console.error('Error setting up shift support services from defaults:', error);
        this.error = 'Failed to set up default support services';
        return false;
      } finally {
        this.loading.supportServices = false;
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
        
        console.log(`Retrieved ${data?.length || 0} area cover assignments for shift ${shiftId}`);
        if (data && data.length > 0) {
          console.log('First assignment:', JSON.stringify(data[0]));
        }
        
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
    
    // Add an area cover assignment to a shift
    async addShiftAreaCover(shiftId, departmentId, startTime, endTime, color = '#4285F4') {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        console.log(`Adding area cover assignment: shift=${shiftId}, dept=${departmentId}, time=${startTime}-${endTime}`);
        
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
        
        if (error) {
          console.error('Error in addShiftAreaCover:', error);
          throw error;
        }
        
        if (data && data.length > 0) {
          console.log(`Successfully added area cover assignment: ${data[0].id} for department ${data[0].department_id}`);
          // Add to shiftAreaCoverAssignments array
          this.shiftAreaCoverAssignments.push(data[0]);
          return data[0];
        } else {
          console.warn('No data returned from addShiftAreaCover insert operation');
        }
        
        return null;
      } catch (error) {
        console.error('Error adding area cover to shift:', error);
        this.error = 'Failed to add department to shift';
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
          // Update the assignment in shiftAreaCoverAssignments array
          const index = this.shiftAreaCoverAssignments.findIndex(a => a.id === assignmentId);
          if (index !== -1) {
            this.shiftAreaCoverAssignments[index] = data[0];
          }
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error updating area cover assignment:', error);
        this.error = 'Failed to update area cover assignment';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Remove a department from shift area cover
    async removeShiftAreaCover(assignmentId) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_area_cover_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove from shiftAreaCoverAssignments array
        this.shiftAreaCoverAssignments = this.shiftAreaCoverAssignments.filter(
          a => a.id !== assignmentId
        );
        
        // Also remove all porter assignments for this area cover
        this.shiftAreaCoverPorterAssignments = this.shiftAreaCoverPorterAssignments.filter(
          pa => pa.shift_area_cover_assignment_id !== assignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing department from shift area cover:', error);
        this.error = 'Failed to remove department from shift';
        return false;
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
    },
    
    // Support Services Management
    
    // Fetch support service assignments for a specific shift
    async fetchShiftSupportServices(shiftId) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
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
        
        if (error) throw error;
        
        this.shiftSupportServiceAssignments = data || [];
        
        // Fetch porter assignments for these services
        if (data && data.length > 0) {
          const serviceIds = data.map(a => a.id);
          await this.fetchShiftSupportServicePorterAssignments(serviceIds);
        }
        
        return this.shiftSupportServiceAssignments;
      } catch (error) {
        console.error('Error fetching shift support services:', error);
        this.error = 'Failed to load support service assignments';
        return [];
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Add a support service assignment to a shift
    async addShiftSupportService(shiftId, serviceId, startTime, endTime, color = '#4285F4') {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        // Check if this service is already assigned to the shift to avoid 409 errors
        const { data: existingAssignments } = await supabase
          .from('shift_support_service_assignments')
          .select('id')
          .eq('shift_id', shiftId)
          .eq('service_id', serviceId);
          
        // If service is already assigned to this shift, skip adding it
        if (existingAssignments && existingAssignments.length > 0) {
          console.log(`Service ${serviceId} already assigned to shift ${shiftId}, skipping`);
          return existingAssignments[0];
        }
        
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
          // Add to shiftSupportServiceAssignments array
          this.shiftSupportServiceAssignments.push(data[0]);
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error adding support service to shift:', error);
        this.error = 'Failed to add support service to shift';
        return null;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Fetch porter assignments for shift support services
    async fetchShiftSupportServicePorterAssignments(serviceIds) {
      if (!serviceIds || serviceIds.length === 0) return [];
      
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_support_service_porter_assignments')
          .select(`
            *,
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `)
          .in('shift_support_service_assignment_id', serviceIds);
        
        if (error) throw error;
        
        this.shiftSupportServicePorterAssignments = data || [];
        return data;
      } catch (error) {
        console.error('Error fetching porter assignments for support services:', error);
        this.error = 'Failed to load porter assignments';
        return [];
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Alias for backward compatibility
    initializeShiftAreaCover(shiftId, shiftType) {
      return this.setupShiftAreaCoverFromDefaults(shiftId, shiftType);
    }
  }
});
