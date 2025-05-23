import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useShiftsStore = defineStore('shifts', {
  state: () => ({
    activeShifts: [],
    archivedShifts: [],
    currentShift: null,
    shiftTasks: [],
    loading: {
      activeShifts: false,
      archivedShifts: false,
      currentShift: false,
      shiftTasks: false,
      createShift: false,
      endShift: false,
      updateTask: false
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
    }
  }
});
