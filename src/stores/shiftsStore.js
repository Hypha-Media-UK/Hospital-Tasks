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
      porterPool: false // Loading state for porter pool operations
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
    
    // Get porter assignments for a specific area cover assignment
    getPorterAssignmentsByAreaId: (state) => (areaCoverId) => {
      return state.shiftAreaCoverPorterAssignments.filter(
        pa => pa.shift_area_cover_assignment_id === areaCoverId
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
        
        // Proceed with adding the task
        const { data, error } = await supabase
          .from('shift_tasks')
          .insert({
            shift_id: shiftId,
            task_item_id: taskData.taskItemId,
            porter_id: taskData.porterId || null,
            origin_department_id: taskData.originDepartmentId || null,
            destination_department_id: taskData.destinationDepartmentId || null,
            status: taskData.status || 'pending'
          })
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
        const { data, error } = await supabase
          .from('shift_tasks')
          .update({ status })
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
        const { data, error } = await supabase
          .from('shift_tasks')
          .update({
            task_item_id: taskData.taskItemId,
            porter_id: taskData.porterId || null,
            origin_department_id: taskData.originDepartmentId || null,
            destination_department_id: taskData.destinationDepartmentId || null,
            status: taskData.status
          })
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
        console.error('Error fetching shift area cover porter assignments:', error);
        this.error = 'Failed to load porter assignments';
        return [];
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Map new shift types to legacy shift types
    mapToLegacyShiftType(shiftType) {
      switch(shiftType) {
        case 'week_day':
        case 'weekend_day':
          return 'day';
        case 'week_night':
        case 'weekend_night':
          return 'night';
        default:
          return shiftType;
      }
    },
    
    // Initialize area cover for a new shift
    async initializeShiftAreaCover(shiftId, shiftType) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        // Get the shift info to verify it exists and is the right type
        const { data: shiftData } = await supabase
          .from('shifts')
          .select('id, shift_type')
          .eq('id', shiftId)
          .single();
        
        if (!shiftData) {
          throw new Error('Shift not found');
        }
        
        // Map the new shift types to legacy types if needed
        const legacyShiftType = this.mapToLegacyShiftType(shiftType);
        
        // Try to fetch with the specific shift type first
        let { data: defaultAssignments, error: fetchError } = await supabase
          .from('area_cover_assignments')
          .select(`
            id,
            department_id,
            start_time,
            end_time,
            color
          `)
          .eq('shift_type', shiftType);
        
        // If no assignments found with the specific type, try with the legacy type
        if (!defaultAssignments || defaultAssignments.length === 0) {
          const { data: legacyAssignments, error: legacyFetchError } = await supabase
            .from('area_cover_assignments')
            .select(`
              id,
              department_id,
              start_time,
              end_time,
              color
            `)
            .eq('shift_type', legacyShiftType);
          
          if (!legacyFetchError) {
            defaultAssignments = legacyAssignments;
          }
        }
        
        // If no default assignments found with either type, return empty array
        if (!defaultAssignments || defaultAssignments.length === 0) {
          return [];
        }
        
        // Insert the shift-specific area cover assignments
        const newAssignments = defaultAssignments.map(assignment => ({
          shift_id: shiftId,
          department_id: assignment.department_id,
          start_time: assignment.start_time,
          end_time: assignment.end_time,
          color: assignment.color
        }));
        
        const { data: insertedData, error: insertError } = await supabase
          .from('shift_area_cover_assignments')
          .insert(newAssignments)
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              building:building_id(id, name)
            )
          `);
        
        if (insertError) throw insertError;
        
        this.shiftAreaCoverAssignments = insertedData || [];
        
        // Create a mapping from original area_cover_assignments.id to the new shift_area_cover_assignments.id
        const areaCoverIdMapping = {};
        for (let i = 0; i < defaultAssignments.length; i++) {
          const originalId = defaultAssignments[i].id;
          const newId = insertedData[i].id;
          areaCoverIdMapping[originalId] = newId;
        }
        
        // Fetch porter assignments for the original area covers
        const originalAreaCoverIds = defaultAssignments.map(a => a.id);
        if (originalAreaCoverIds.length > 0) {
          const { data: porterAssignments, error: porterFetchError } = await supabase
            .from('area_cover_porter_assignments')
            .select(`
              area_cover_assignment_id,
              porter_id,
              start_time,
              end_time
            `)
            .in('area_cover_assignment_id', originalAreaCoverIds);
          
          if (porterFetchError) throw porterFetchError;
          
          // Create shift-specific porter assignments
          if (porterAssignments && porterAssignments.length > 0) {
            const newPorterAssignments = porterAssignments.map(pa => ({
              shift_area_cover_assignment_id: areaCoverIdMapping[pa.area_cover_assignment_id],
              porter_id: pa.porter_id,
              start_time: pa.start_time,
              end_time: pa.end_time
            }));
            
            const { data: insertedPorterData, error: porterInsertError } = await supabase
              .from('shift_area_cover_porter_assignments')
              .insert(newPorterAssignments)
              .select(`
                *,
                porter:porter_id(
                  id,
                  first_name,
                  last_name
                )
              `);
            
            if (porterInsertError) throw porterInsertError;
            
            // Update local state with the new porter assignments
            this.shiftAreaCoverPorterAssignments = insertedPorterData || [];
          }
        }
        
        return insertedData;
      } catch (error) {
        console.error('Error initializing shift area cover:', error);
        this.error = 'Failed to initialize area cover for this shift';
        return [];
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Add department to shift area cover
    async addShiftAreaCover(shiftId, departmentId, startTime, endTime, color = '#4285F4') {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { data: shift } = await supabase
          .from('shifts')
          .select('shift_type')
          .eq('id', shiftId)
          .single();
        
        if (!shift) {
          throw new Error('Shift not found');
        }
        
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
          this.shiftAreaCoverAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding department to shift area cover:', error);
        this.error = 'Failed to add department to area cover';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Update shift area cover assignment
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
          const index = this.shiftAreaCoverAssignments.findIndex(a => a.id === assignmentId);
          if (index !== -1) {
            this.shiftAreaCoverAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating shift area cover assignment:', error);
        this.error = 'Failed to update area cover assignment';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Remove department from shift area cover
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
        this.error = 'Failed to remove department from area cover';
        return false;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Add porter assignment to shift area cover
    async addShiftAreaCoverPorter(areaCoverId, porterId, startTime, endTime) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        // First, get the shift ID from the area cover assignment
        const { data: areaCover, error: areaCoverError } = await supabase
          .from('shift_area_cover_assignments')
          .select('shift_id')
          .eq('id', areaCoverId)
          .single();
        
        if (areaCoverError) throw areaCoverError;
        
        if (!areaCover) {
          throw new Error('Area cover assignment not found');
        }
        
        // Add the porter to the department assignment
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
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to local state
          this.shiftAreaCoverPorterAssignments.push(data[0]);
          
          // Now remove the porter from the shift porter pool if they're in it
          // First find the porter pool entry
          const porterPoolEntry = this.shiftPorterPool.find(
            p => p.porter_id === porterId && p.shift_id === areaCover.shift_id
          );
          
          if (porterPoolEntry) {
            // Remove from database
            const { error: removeError } = await supabase
              .from('shift_porter_pool')
              .delete()
              .eq('id', porterPoolEntry.id);
            
            if (removeError) {
              console.error('Error removing porter from shift pool:', removeError);
            } else {
              // Remove from local state
              this.shiftPorterPool = this.shiftPorterPool.filter(p => p.id !== porterPoolEntry.id);
            }
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding porter assignment to shift area cover:', error);
        this.error = 'Failed to add porter assignment';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Update porter assignment for shift area cover
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
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const index = this.shiftAreaCoverPorterAssignments.findIndex(
            pa => pa.id === porterAssignmentId
          );
          if (index !== -1) {
            this.shiftAreaCoverPorterAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating porter assignment for shift area cover:', error);
        this.error = 'Failed to update porter assignment';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Remove porter assignment from shift area cover
    async removeShiftAreaCoverPorter(porterAssignmentId) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        // First, get the assignment to know which porter to add back to the pool
        const { data: assignment, error: fetchError } = await supabase
          .from('shift_area_cover_porter_assignments')
          .select(`
            porter_id,
            shift_area_cover_assignment_id
          `)
          .eq('id', porterAssignmentId)
          .single();
        
        if (fetchError) throw fetchError;
        
        if (!assignment) {
          throw new Error('Porter assignment not found');
        }
        
        // Get the shift ID from the area cover assignment
        const { data: areaCover, error: areaCoverError } = await supabase
          .from('shift_area_cover_assignments')
          .select('shift_id')
          .eq('id', assignment.shift_area_cover_assignment_id)
          .single();
        
        if (areaCoverError) throw areaCoverError;
        
        // Delete the porter assignment
        const { error } = await supabase
          .from('shift_area_cover_porter_assignments')
          .delete()
          .eq('id', porterAssignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftAreaCoverPorterAssignments = this.shiftAreaCoverPorterAssignments.filter(
          pa => pa.id !== porterAssignmentId
        );
        
        // Add the porter back to the shift pool
        if (areaCover && assignment.porter_id) {
          // Check if the porter is already in the pool
          const alreadyInPool = this.shiftPorterPool.some(p => p.porter_id === assignment.porter_id);
          
          if (!alreadyInPool) {
            // Add porter back to the shift pool
            const { data: porterData, error: porterError } = await supabase
              .from('shift_porter_pool')
              .insert({
                shift_id: areaCover.shift_id,
                porter_id: assignment.porter_id
              })
              .select(`
                *,
                porter:porter_id(id, first_name, last_name, role)
              `);
            
            if (!porterError && porterData && porterData.length > 0) {
              // Add to local state
              this.shiftPorterPool.push(porterData[0]);
            } else if (porterError) {
              console.error('Error adding porter back to shift pool:', porterError);
            }
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error removing porter assignment from shift area cover:', error);
        this.error = 'Failed to remove porter assignment';
        return false;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Porter Pool Management
    
    // Fetch porters in a shift's pool
    async fetchShiftPorterPool(shiftId) {
      this.loading.porterPool = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_porter_pool')
          .select(`
            *,
            porter:porter_id(id, first_name, last_name, role)
          `)
          .eq('shift_id', shiftId);
        
        if (error) throw error;
        
        this.shiftPorterPool = data || [];
        return data;
      } catch (error) {
        console.error('Error fetching shift porter pool:', error);
        this.error = 'Failed to load shift porters';
        return [];
      } finally {
        this.loading.porterPool = false;
      }
    },
    
    // Add porter to shift pool
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
            porter:porter_id(id, first_name, last_name, role)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
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
    
    // Remove porter from shift pool
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
    }
  }
});
