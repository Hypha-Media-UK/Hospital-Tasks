import { defineStore } from 'pinia';
import { supabase, fetchData } from '../services/supabase';

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
        const data = await fetchData('tasks');
        
        if (data) {
          this.tasks = data.filter(task => !task.archived);
          this.archivedTasks = data.filter(task => task.archived);
        }
      } catch (error) {
        console.error('Error in fetchTasks:', error);
        this.error = 'Failed to fetch tasks';
      } finally {
        this.loading = false;
      }
    },
    
    async addTask(task) {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('tasks')
          .insert(task)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          this.tasks.push(data[0]);
        }
      } catch (error) {
        console.error('Error in addTask:', error);
        this.error = 'Failed to add task';
      } finally {
        this.loading = false;
      }
    },
    
    async updateTask(id, updates) {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('tasks')
          .update(updates)
          .eq('id', id)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const index = this.tasks.findIndex(task => task.id === id);
          
          if (index !== -1) {
            // Handle archiving
            if (updates.archived) {
              this.archivedTasks.push(data[0]);
              this.tasks.splice(index, 1);
            } else {
              this.tasks[index] = data[0];
            }
          }
        }
      } catch (error) {
        console.error('Error in updateTask:', error);
        this.error = 'Failed to update task';
      } finally {
        this.loading = false;
      }
    },
    
    async deleteTask(id) {
      this.loading = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('tasks')
          .delete()
          .eq('id', id);
        
        if (error) throw error;
        
        // Remove from appropriate array
        const taskIndex = this.tasks.findIndex(task => task.id === id);
        if (taskIndex !== -1) {
          this.tasks.splice(taskIndex, 1);
        } else {
          const archivedIndex = this.archivedTasks.findIndex(task => task.id === id);
          if (archivedIndex !== -1) {
            this.archivedTasks.splice(archivedIndex, 1);
          }
        }
      } catch (error) {
        console.error('Error in deleteTask:', error);
        this.error = 'Failed to delete task';
      } finally {
        this.loading = false;
      }
    }
  }
});
