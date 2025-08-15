import { defineStore } from 'pinia';
import { taskTypesApi, taskItemsApi, ApiError } from '../services/api';

export const useTaskTypesStore = defineStore('taskTypes', {
  state: () => ({
    taskTypes: [],
    taskItems: [],
    taskItemAssignments: [],
    typeAssignments: [],
    loading: {
      taskTypes: false,
      taskItems: false,
      itemAssignments: false,
      typeAssignments: false,
      creating: false,
      updating: false,
      deleting: false
    },
    error: null
  }),
  
  getters: {
    // Get task types sorted by name
    sortedTaskTypes: (state) => {
      return [...state.taskTypes].sort((a, b) => a.name.localeCompare(b.name));
    },
    
    // Get task items for a specific task type
    getTaskItemsByType: (state) => (taskTypeId) => {
      return state.taskItems.filter(item => item.task_type_id === taskTypeId);
    },
    
    // Get regular task items
    regularTaskItems: (state) => {
      return state.taskItems.filter(item => item.is_regular);
    },
    
    // Get task type by ID
    getTaskTypeById: (state) => (id) => {
      return state.taskTypes.find(type => type.id === id);
    },
    
    // Get task item by ID
    getTaskItemById: (state) => (id) => {
      return state.taskItems.find(item => item.id === id);
    },
    
    // Get task types with their items
    taskTypesWithItems: (state) => {
      return state.taskTypes.map(taskType => ({
        ...taskType,
        items: state.taskItems.filter(item => item.task_type_id === taskType.id)
      }));
    }
  },
  
  actions: {
    // Task Types CRUD operations
    async fetchTaskTypes(includeItems = false) {
      this.loading.taskTypes = true;
      this.error = null;
      
      try {
        const data = await taskTypesApi.getAll(includeItems);
        this.taskTypes = data || [];
        
        // If items were included, extract them
        if (includeItems) {
          const allItems = [];
          this.taskTypes.forEach(taskType => {
            if (taskType.task_items) {
              allItems.push(...taskType.task_items);
            }
          });
          this.taskItems = allItems;
        }
      } catch (error) {
        console.error('Error fetching task types:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load task types';
      } finally {
        this.loading.taskTypes = false;
      }
    },
    
    async fetchTaskType(id, includeItems = true) {
      this.loading.taskTypes = true;
      this.error = null;
      
      try {
        const data = await taskTypesApi.getById(id, includeItems);
        
        if (data) {
          // Update or add to task types
          const index = this.taskTypes.findIndex(t => t.id === id);
          if (index !== -1) {
            this.taskTypes[index] = data;
          } else {
            this.taskTypes.push(data);
          }
          
          // If items were included, update task items
          if (includeItems && data.task_items) {
            // Remove existing items for this task type
            this.taskItems = this.taskItems.filter(item => item.task_type_id !== id);
            // Add new items
            this.taskItems.push(...data.task_items);
          }
        }
        
        return data;
      } catch (error) {
        console.error('Error fetching task type:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load task type';
        return null;
      } finally {
        this.loading.taskTypes = false;
      }
    },
    
    async createTaskType(taskTypeData) {
      this.loading.creating = true;
      this.error = null;
      
      try {
        const data = await taskTypesApi.create(taskTypeData);
        
        if (data) {
          this.taskTypes.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error creating task type:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to create task type';
        return null;
      } finally {
        this.loading.creating = false;
      }
    },
    
    async updateTaskType(id, updates) {
      this.loading.updating = true;
      this.error = null;
      
      try {
        const data = await taskTypesApi.update(id, updates);
        
        if (data) {
          const index = this.taskTypes.findIndex(t => t.id === id);
          if (index !== -1) {
            this.taskTypes[index] = data;
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating task type:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update task type';
        return false;
      } finally {
        this.loading.updating = false;
      }
    },
    
    async deleteTaskType(id) {
      this.loading.deleting = true;
      this.error = null;
      
      try {
        await taskTypesApi.delete(id);
        
        // Remove from local state
        this.taskTypes = this.taskTypes.filter(t => t.id !== id);
        // Also remove associated task items
        this.taskItems = this.taskItems.filter(item => item.task_type_id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting task type:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete task type';
        return false;
      } finally {
        this.loading.deleting = false;
      }
    },
    
    // Task Items CRUD operations
    async fetchTaskItems(filters = {}) {
      this.loading.taskItems = true;
      this.error = null;
      
      try {
        const data = await taskItemsApi.getAll(filters);
        this.taskItems = data || [];
      } catch (error) {
        console.error('Error fetching task items:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load task items';
      } finally {
        this.loading.taskItems = false;
      }
    },
    
    async fetchTaskItemsForType(taskTypeId, filters = {}) {
      this.loading.taskItems = true;
      this.error = null;
      
      try {
        const data = await taskTypesApi.getItems(taskTypeId, filters);
        
        // Replace items for this task type
        this.taskItems = this.taskItems.filter(item => item.task_type_id !== taskTypeId);
        if (data) {
          this.taskItems.push(...data);
        }
        
        return data;
      } catch (error) {
        console.error('Error fetching task items for type:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load task items';
        return [];
      } finally {
        this.loading.taskItems = false;
      }
    },
    
    async createTaskItem(itemData) {
      this.loading.creating = true;
      this.error = null;
      
      try {
        const data = await taskItemsApi.create(itemData);
        
        if (data) {
          this.taskItems.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error creating task item:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to create task item';
        return null;
      } finally {
        this.loading.creating = false;
      }
    },
    
    async createTaskItemForType(taskTypeId, itemData) {
      this.loading.creating = true;
      this.error = null;
      
      try {
        const data = await taskTypesApi.createItem(taskTypeId, itemData);
        
        if (data) {
          this.taskItems.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error creating task item for type:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to create task item';
        return null;
      } finally {
        this.loading.creating = false;
      }
    },
    
    async updateTaskItem(id, updates) {
      this.loading.updating = true;
      this.error = null;
      
      try {
        const data = await taskItemsApi.update(id, updates);
        
        if (data) {
          const index = this.taskItems.findIndex(item => item.id === id);
          if (index !== -1) {
            this.taskItems[index] = data;
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating task item:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update task item';
        return false;
      } finally {
        this.loading.updating = false;
      }
    },
    
    async deleteTaskItem(id) {
      this.loading.deleting = true;
      this.error = null;
      
      try {
        await taskItemsApi.delete(id);
        
        // Remove from local state
        this.taskItems = this.taskItems.filter(item => item.id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting task item:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete task item';
        return false;
      } finally {
        this.loading.deleting = false;
      }
    },
    
    // Utility methods
    async toggleTaskItemRegular(id) {
      const item = this.getTaskItemById(id);
      if (!item) return false;
      
      return this.updateTaskItem(id, { is_regular: !item.is_regular });
    },
    
    async setTaskItemRegular(id, isRegular) {
      return this.updateTaskItem(id, { is_regular: isRegular });
    },
    
    // Alias for createTaskItemForType for compatibility
    async addTaskItem(itemData) {
      return this.createTaskItem(itemData);
    },
    
    // Task Item Department Assignments
    async fetchItemAssignments(itemId) {
      this.loading.itemAssignments = true;
      this.error = null;
      
      try {
        const data = await taskItemsApi.getAssignments(itemId);
        
        // Update assignments in state
        this.taskItemAssignments = this.taskItemAssignments.filter(
          assignment => assignment.task_item_id !== itemId
        );
        if (data) {
          this.taskItemAssignments.push(...data);
        }
        
        return data || [];
      } catch (error) {
        console.error('Error fetching task item assignments:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load task item assignments';
        return [];
      } finally {
        this.loading.itemAssignments = false;
      }
    },
    
    async updateItemAssignments(itemId, assignments) {
      this.loading.itemAssignments = true;
      this.error = null;
      
      try {
        const data = await taskItemsApi.updateAssignments(itemId, assignments);
        
        // Update assignments in state
        this.taskItemAssignments = this.taskItemAssignments.filter(
          assignment => assignment.task_item_id !== itemId
        );
        if (data) {
          this.taskItemAssignments.push(...data);
        }
        
        return true;
      } catch (error) {
        console.error('Error updating task item assignments:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update task item assignments';
        return false;
      } finally {
        this.loading.itemAssignments = false;
      }
    },
    
    // Get assignments for a specific task item
    getItemAssignmentsByItemId(itemId) {
      return this.taskItemAssignments.filter(assignment => assignment.task_item_id === itemId);
    },
    
    // Task Type Department Assignments
    async fetchTypeAssignments() {
      this.loading.typeAssignments = true;
      this.error = null;
      
      try {
        // Fetch all task types and their assignments
        const taskTypes = await taskTypesApi.getAll();
        const allAssignments = [];
        
        // Fetch assignments for each task type
        for (const taskType of taskTypes) {
          try {
            const assignments = await taskTypesApi.getAssignments(taskType.id);
            allAssignments.push(...assignments);
          } catch (error) {
            // If a task type has no assignments, that's okay, just continue
            if (error.status !== 404) {
              console.warn(`Error fetching assignments for task type ${taskType.id}:`, error);
            }
          }
        }
        
        this.typeAssignments = allAssignments;
        return allAssignments;
      } catch (error) {
        console.error('Error fetching task type assignments:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load task type assignments';
        return [];
      } finally {
        this.loading.typeAssignments = false;
      }
    },
    
    async updateTypeAssignments(taskTypeId, assignments) {
      this.loading.typeAssignments = true;
      this.error = null;
      
      try {
        const data = await taskTypesApi.updateAssignments(taskTypeId, assignments);
        
        // Update assignments in state
        this.typeAssignments = this.typeAssignments.filter(
          assignment => assignment.task_type_id !== taskTypeId
        );
        if (data) {
          this.typeAssignments.push(...data);
        }
        
        return true;
      } catch (error) {
        console.error('Error updating task type assignments:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update task type assignments';
        return false;
      } finally {
        this.loading.typeAssignments = false;
      }
    },
    
    // Get assignments for a specific task type
    getTypeAssignmentsByTypeId(taskTypeId) {
      return this.typeAssignments.filter(assignment => assignment.task_type_id === taskTypeId);
    },
    
    // Alias for fetchTaskItemsForType for compatibility
    async fetchTaskItemsByType(taskTypeId, filters = {}) {
      return this.fetchTaskItemsForType(taskTypeId, filters);
    },
    
    // Check if task type has department assignments
    hasTypeAssignments(taskTypeId) {
      const assignments = this.getTypeAssignmentsByTypeId(taskTypeId);
      return assignments.length > 0;
    },
    
    // Check if task item has department assignments
    hasItemAssignments(itemId) {
      const assignments = this.getItemAssignmentsByItemId(itemId);
      return assignments.length > 0;
    },
    
    // Initialize data
    async initialize() {
      await Promise.all([
        this.fetchTaskTypes(true), // Include items
        // this.fetchTaskItems() // Already loaded with task types
      ]);
    }
  }
});
