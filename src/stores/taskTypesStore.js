import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useTaskTypesStore = defineStore('taskTypes', {
  state: () => ({
    taskTypes: [],
    taskItems: [],
    assignments: [],
    loading: {
      taskTypes: false,
      taskItems: false,
      assignments: false
    },
    error: null
  }),
  
  getters: {
    taskTypesWithItems: (state) => {
      return state.taskTypes.map(taskType => {
        const items = state.taskItems.filter(
          item => item.task_type_id === taskType.id
        );
        return {
          ...taskType,
          items
        };
      });
    },
    
    getTaskItemsByTypeId: (state) => (typeId) => {
      return state.taskItems.filter(item => item.task_type_id === typeId);
    },
    
    getAssignmentsByTypeId: (state) => (typeId) => {
      return state.assignments.filter(
        assignment => assignment.task_type_id === typeId
      );
    },
    
    hasAssignments: (state) => (typeId) => {
      return state.assignments.some(
        assignment => assignment.task_type_id === typeId
      );
    },
    
    getDepartmentAssignment: (state) => (typeId, departmentId) => {
      return state.assignments.find(
        a => a.task_type_id === typeId && a.department_id === departmentId
      ) || { is_origin: false, is_destination: false };
    }
  },
  
  actions: {
    // Task Types CRUD operations
    async fetchTaskTypes() {
      this.loading.taskTypes = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('task_types')
          .select('*')
          .order('name');
        
        if (error) throw error;
        
        this.taskTypes = data || [];
      } catch (error) {
        console.error('Error fetching task types:', error);
        this.error = 'Failed to load task types';
      } finally {
        this.loading.taskTypes = false;
      }
    },
    
    async addTaskType(taskType) {
      this.loading.taskTypes = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('task_types')
          .insert(taskType)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          this.taskTypes.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding task type:', error);
        this.error = 'Failed to add task type';
        return null;
      } finally {
        this.loading.taskTypes = false;
      }
    },
    
    async updateTaskType(id, updates) {
      this.loading.taskTypes = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('task_types')
          .update(updates)
          .eq('id', id)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const index = this.taskTypes.findIndex(t => t.id === id);
          if (index !== -1) {
            this.taskTypes[index] = data[0];
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating task type:', error);
        this.error = 'Failed to update task type';
        return false;
      } finally {
        this.loading.taskTypes = false;
      }
    },
    
    async deleteTaskType(id) {
      this.loading.taskTypes = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('task_types')
          .delete()
          .eq('id', id);
        
        if (error) throw error;
        
        // Remove from local state
        this.taskTypes = this.taskTypes.filter(t => t.id !== id);
        // Also remove associated task items and assignments
        this.taskItems = this.taskItems.filter(i => i.task_type_id !== id);
        this.assignments = this.assignments.filter(a => a.task_type_id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting task type:', error);
        this.error = 'Failed to delete task type';
        return false;
      } finally {
        this.loading.taskTypes = false;
      }
    },
    
    // Task Items CRUD operations
    async fetchTaskItems() {
      this.loading.taskItems = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('task_items')
          .select('*')
          .order('name');
        
        if (error) throw error;
        
        this.taskItems = data || [];
      } catch (error) {
        console.error('Error fetching task items:', error);
        this.error = 'Failed to load task items';
      } finally {
        this.loading.taskItems = false;
      }
    },
    
    async addTaskItem(taskItem) {
      this.loading.taskItems = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('task_items')
          .insert(taskItem)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          this.taskItems.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding task item:', error);
        this.error = 'Failed to add task item';
        return null;
      } finally {
        this.loading.taskItems = false;
      }
    },
    
    async updateTaskItem(id, updates) {
      this.loading.taskItems = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('task_items')
          .update(updates)
          .eq('id', id)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const index = this.taskItems.findIndex(i => i.id === id);
          if (index !== -1) {
            this.taskItems[index] = data[0];
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating task item:', error);
        this.error = 'Failed to update task item';
        return false;
      } finally {
        this.loading.taskItems = false;
      }
    },
    
    async deleteTaskItem(id) {
      this.loading.taskItems = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('task_items')
          .delete()
          .eq('id', id);
        
        if (error) throw error;
        
        // Remove from local state
        this.taskItems = this.taskItems.filter(i => i.id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting task item:', error);
        this.error = 'Failed to delete task item';
        return false;
      } finally {
        this.loading.taskItems = false;
      }
    },
    
    // Department Assignments operations
    async fetchAssignments() {
      this.loading.assignments = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('task_type_department_assignments')
          .select('*');
        
        if (error) throw error;
        
        this.assignments = data || [];
      } catch (error) {
        console.error('Error fetching assignments:', error);
        this.error = 'Failed to load department assignments';
      } finally {
        this.loading.assignments = false;
      }
    },
    
    async updateAssignments(taskTypeId, departmentAssignments) {
      this.loading.assignments = true;
      this.error = null;
      
      try {
        // First, delete all existing assignments for this task type
        const { error: deleteError } = await supabase
          .from('task_type_department_assignments')
          .delete()
          .eq('task_type_id', taskTypeId);
        
        if (deleteError) throw deleteError;
        
        // Filter out assignments where both is_origin and is_destination are false
        const validAssignments = departmentAssignments.filter(
          a => a.is_origin || a.is_destination
        );
        
        // If there are valid assignments, insert them
        if (validAssignments.length > 0) {
          const { error: insertError } = await supabase
            .from('task_type_department_assignments')
            .insert(validAssignments);
          
          if (insertError) throw insertError;
        }
        
        // Update local state
        this.assignments = this.assignments.filter(
          a => a.task_type_id !== taskTypeId
        );
        
        validAssignments.forEach(assignment => {
          this.assignments.push(assignment);
        });
        
        return true;
      } catch (error) {
        console.error('Error updating assignments:', error);
        this.error = 'Failed to update department assignments';
        return false;
      } finally {
        this.loading.assignments = false;
      }
    },
    
    // Initialize data
    async initialize() {
      await Promise.all([
        this.fetchTaskTypes(),
        this.fetchTaskItems(),
        this.fetchAssignments()
      ]);
    }
  }
});
