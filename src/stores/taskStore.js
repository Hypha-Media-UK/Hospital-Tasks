import { defineStore } from 'pinia';
import { ApiError } from '../services/api';

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
    async fetchTasks() {
      this.loading = true;
      this.error = null;
      
      try {
        // TODO: Implement tasks API endpoint
        console.log('Tasks API not yet implemented');
        this.tasks = [];
        this.archivedTasks = [];
      } catch (error) {
        console.error('Error in fetchTasks:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to fetch tasks';
      } finally {
        this.loading = false;
      }
    },
    
    async addTask(task) {
      this.loading = true;
      this.error = null;
      
      try {
        // TODO: Implement tasks API endpoint
        console.log('Task creation not yet implemented');
      } catch (error) {
        console.error('Error in addTask:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to add task';
      } finally {
        this.loading = false;
      }
    },
    
    async updateTask(id, updates) {
      this.loading = true;
      this.error = null;
      
      try {
        // TODO: Implement tasks API endpoint
        console.log('Task update not yet implemented');
      } catch (error) {
        console.error('Error in updateTask:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update task';
      } finally {
        this.loading = false;
      }
    },
    
    async deleteTask(id) {
      this.loading = true;
      this.error = null;
      
      try {
        // TODO: Implement tasks API endpoint
        console.log('Task deletion not yet implemented');
      } catch (error) {
        console.error('Error in deleteTask:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete task';
      } finally {
        this.loading = false;
      }
    }
  }
});
