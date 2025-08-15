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
        this.tasks = [];
        this.archivedTasks = [];
      } catch (error) {
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
      } catch (error) {
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
      } catch (error) {
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
      } catch (error) {
        this.error = error instanceof ApiError ? error.message : 'Failed to delete task';
      } finally {
        this.loading = false;
      }
    }
  }
});
