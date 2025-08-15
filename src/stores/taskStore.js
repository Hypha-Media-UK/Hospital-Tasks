import { defineStore } from 'pinia';
import { ApiError, tasksApi } from '../services/api';

export const useTaskStore = defineStore('tasks', {
  state: () => ({
    tasks: [],
    archivedTasks: [],
    loading: false,
    error: null
  }),
  
  getters: {
    activeTasks: (state) => state.tasks.filter(task => !task.completed),
    completedTasks: (state) => state.tasks.filter(task => task.completed)
  },
  
  actions: {
    async fetchTasks(filters = {}) {
      this.loading = true;
      this.error = null;
      
      try {
        const response = await tasksApi.getAll(filters);
        this.tasks = response.data || response || [];
        
        // If we want to separate archived tasks, we can filter them
        this.archivedTasks = this.tasks.filter(task => task.status === 'archived');
      } catch (error) {
        this.error = error instanceof ApiError ? error.message : 'Failed to fetch tasks';
      } finally {
        this.loading = false;
      }
    },
    
    async addTask(taskData) {
      this.loading = true;
      this.error = null;
      
      try {
        const response = await tasksApi.create(taskData);
        const newTask = response.data || response;
        
        if (newTask) {
          this.tasks.unshift(newTask);
        }
        
        return newTask;
      } catch (error) {
        this.error = error instanceof ApiError ? error.message : 'Failed to add task';
        throw error;
      } finally {
        this.loading = false;
      }
    },
    
    async updateTask(id, updates) {
      this.loading = true;
      this.error = null;
      
      try {
        const response = await tasksApi.update(id, updates);
        const updatedTask = response.data || response;
        
        if (updatedTask) {
          const index = this.tasks.findIndex(task => task.id === id);
          if (index !== -1) {
            this.tasks[index] = updatedTask;
          }
        }
        
        return updatedTask;
      } catch (error) {
        this.error = error instanceof ApiError ? error.message : 'Failed to update task';
        throw error;
      } finally {
        this.loading = false;
      }
    },
    
    async deleteTask(id) {
      this.loading = true;
      this.error = null;
      
      try {
        await tasksApi.delete(id);
        
        // Remove from local state
        this.tasks = this.tasks.filter(task => task.id !== id);
        this.archivedTasks = this.archivedTasks.filter(task => task.id !== id);
        
        return true;
      } catch (error) {
        this.error = error instanceof ApiError ? error.message : 'Failed to delete task';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    // Fetch tasks for a specific shift
    async fetchTasksByShift(shiftId) {
      this.loading = true;
      this.error = null;
      
      try {
        const response = await tasksApi.getByShiftId(shiftId);
        const tasks = response.data || response || [];
        
        // Update tasks for this shift
        this.tasks = tasks;
        
        return tasks;
      } catch (error) {
        this.error = error instanceof ApiError ? error.message : 'Failed to fetch shift tasks';
        throw error;
      } finally {
        this.loading = false;
      }
    }
  }
});
