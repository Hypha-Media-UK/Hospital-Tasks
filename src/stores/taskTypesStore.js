import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useTaskTypesStore = defineStore('taskTypes', {
  state: () => ({
    taskTypes: [],
    taskItems: [],
    typeAssignments: [],
    itemAssignments: [],
    loading: {
      taskTypes: false,
      taskItems: false,
      typeAssignments: false,
      itemAssignments: false
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
    
    getTaskItemsByType: (state) => (typeId) => {
      return state.taskItems.filter(item => item.task_type_id === typeId);
    },
    
    // Task Type Assignment Getters
    getTypeAssignmentsByTypeId: (state) => (typeId) => {
      return state.typeAssignments.filter(
        assignment => assignment.task_type_id === typeId
      );
    },
    
    hasTypeAssignments: (state) => (typeId) => {
      return state.typeAssignments.some(
        assignment => assignment.task_type_id === typeId
      );
    },
    
    getTypeDepartmentAssignment: (state) => (typeId, departmentId) => {
      return state.typeAssignments.find(
        a => a.task_type_id === typeId && a.department_id === departmentId
      ) || { is_origin: false, is_destination: false };
    },
    
    // Task Item Assignment Getters
    getItemAssignmentsByItemId: (state) => (itemId) => {
      return state.itemAssignments.filter(
        assignment => assignment.task_item_id === itemId
      );
    },
    
    hasItemAssignments: (state) => (itemId) => {
      return state.itemAssignments.some(
        assignment => assignment.task_item_id === itemId
      );
    },
    
    getItemDepartmentAssignment: (state) => (itemId, departmentId) => {
      return state.itemAssignments.find(
        a => a.task_item_id === itemId && a.department_id === departmentId
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
        this.typeAssignments = this.typeAssignments.filter(a => a.task_type_id !== id);
        
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
        // Also remove associated assignments
        this.itemAssignments = this.itemAssignments.filter(a => a.task_item_id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting task item:', error);
        this.error = 'Failed to delete task item';
        return false;
      } finally {
        this.loading.taskItems = false;
      }
    },
    
    // Fetch task items for a specific type
    async fetchTaskItemsByType(typeId) {
      this.loading.taskItems = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('task_items')
          .select('*')
          .eq('task_type_id', typeId)
          .order('name');
        
        if (error) throw error;
        
        // Only update the items of this type, preserve others
        const existingItems = this.taskItems.filter(item => item.task_type_id !== typeId);
        this.taskItems = [...existingItems, ...(data || [])];
        
        return data || [];
      } catch (error) {
        console.error('Error fetching task items by type:', error);
        this.error = 'Failed to load task items';
        return [];
      } finally {
        this.loading.taskItems = false;
      }
    },
    
    // Task Type Department Assignments operations
    async fetchTypeAssignments() {
      this.loading.typeAssignments = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('task_type_department_assignments')
          .select('*');
        
        if (error) throw error;
        
        this.typeAssignments = data || [];
      } catch (error) {
        console.error('Error fetching type assignments:', error);
        this.error = 'Failed to load department assignments for task types';
      } finally {
        this.loading.typeAssignments = false;
      }
    },
    
    async updateTypeAssignments(taskTypeId, departmentAssignments) {
      this.loading.typeAssignments = true;
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
        this.typeAssignments = this.typeAssignments.filter(
          a => a.task_type_id !== taskTypeId
        );
        
        validAssignments.forEach(assignment => {
          this.typeAssignments.push(assignment);
        });
        
        return true;
      } catch (error) {
        console.error('Error updating type assignments:', error);
        this.error = 'Failed to update department assignments for task type';
        return false;
      } finally {
        this.loading.typeAssignments = false;
      }
    },
    
    // Task Item Department Assignments operations
    async fetchItemAssignments() {
      this.loading.itemAssignments = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('task_item_department_assignments')
          .select('*');
        
        if (error) throw error;
        
        this.itemAssignments = data || [];
      } catch (error) {
        console.error('Error fetching item assignments:', error);
        this.error = 'Failed to load department assignments for task items';
      } finally {
        this.loading.itemAssignments = false;
      }
    },
    
    async updateItemAssignments(taskItemId, departmentAssignments) {
      this.loading.itemAssignments = true;
      this.error = null;
      
      try {
        // First, delete all existing assignments for this task item
        const { error: deleteError } = await supabase
          .from('task_item_department_assignments')
          .delete()
          .eq('task_item_id', taskItemId);
        
        if (deleteError) throw deleteError;
        
        // Filter out assignments where both is_origin and is_destination are false
        const validAssignments = departmentAssignments.filter(
          a => a.is_origin || a.is_destination
        );
        
        // If there are valid assignments, insert them
        if (validAssignments.length > 0) {
          const { error: insertError } = await supabase
            .from('task_item_department_assignments')
            .insert(validAssignments);
          
          if (insertError) throw insertError;
        }
        
        // Update local state
        this.itemAssignments = this.itemAssignments.filter(
          a => a.task_item_id !== taskItemId
        );
        
        validAssignments.forEach(assignment => {
          this.itemAssignments.push(assignment);
        });
        
        return true;
      } catch (error) {
        console.error('Error updating item assignments:', error);
        this.error = 'Failed to update department assignments for task item';
        return false;
      } finally {
        this.loading.itemAssignments = false;
      }
    },
    
    // Initialize data
    async initialize() {
      await Promise.all([
        this.fetchTaskTypes(),
        this.fetchTaskItems(),
        this.fetchTypeAssignments(),
        this.fetchItemAssignments()
      ]);
    }
  }
});
