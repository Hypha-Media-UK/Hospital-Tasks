import { defineStore } from 'pinia';
import { settingsApi, ApiError } from '../services/api';

export const useSettingsStore = defineStore('settings', {
  state: () => ({
    appSettings: {},
    shiftDefaults: [],
    loading: {
      appSettings: false,
      shiftDefaults: false,
      updating: false
    },
    error: null
  }),
  
  getters: {
    // Get shift defaults organized by shift type
    shiftDefaultsByType: (state) => {
      const defaults = {};
      state.shiftDefaults.forEach(shiftDefault => {
        defaults[shiftDefault.shift_type] = shiftDefault;
      });
      return defaults;
    },
    
    // Get formatted shift defaults for display
    formattedShiftDefaults: (state) => {
      return state.shiftDefaults.map(shiftDefault => ({
        ...shiftDefault,
        start_time_display: shiftDefault.start_time ? 
          new Date(shiftDefault.start_time).toLocaleTimeString('en-GB', { 
            hour: '2-digit', 
            minute: '2-digit',
            hour12: false 
          }) : '00:00',
        end_time_display: shiftDefault.end_time ? 
          new Date(shiftDefault.end_time).toLocaleTimeString('en-GB', { 
            hour: '2-digit', 
            minute: '2-digit',
            hour12: false 
          }) : '00:00'
      }));
    },
    
    // Get shift default by type
    getShiftDefaultByType: (state) => (shiftType) => {
      return state.shiftDefaults.find(sd => sd.shift_type === shiftType);
    },
    
  },
  
  actions: {
    // App Settings operations (simplified - no longer needed for timezone)
    async fetchAppSettings() {
      this.loading.appSettings = true;
      this.error = null;
      
      try {
        // App settings no longer needed for timezone, but keep for compatibility
        this.appSettings = {};
      } catch (error) {
        this.error = 'Failed to load app settings';
      } finally {
        this.loading.appSettings = false;
      }
    },
    
    // Shift Defaults operations
    async fetchShiftDefaults() {
      this.loading.shiftDefaults = true;
      this.error = null;
      
      try {
        const data = await settingsApi.getShiftDefaults();
        this.shiftDefaults = data || [];
      } catch (error) {
        this.error = error instanceof ApiError ? error.message : 'Failed to load shift defaults';
      } finally {
        this.loading.shiftDefaults = false;
      }
    },
    
    async updateShiftDefault(id, updates) {
      this.loading.updating = true;
      this.error = null;
      
      try {
        const data = await settingsApi.updateShiftDefault(id, updates);
        
        if (data) {
          const index = this.shiftDefaults.findIndex(sd => sd.id === id);
          if (index !== -1) {
            this.shiftDefaults[index] = data;
          }
        }
        
        return true;
      } catch (error) {
        this.error = error instanceof ApiError ? error.message : 'Failed to update shift default';
        return false;
      } finally {
        this.loading.updating = false;
      }
    },
    
    async createShiftDefault(shiftDefaultData) {
      this.loading.updating = true;
      this.error = null;
      
      try {
        const data = await settingsApi.createShiftDefault(shiftDefaultData);
        
        if (data) {
          this.shiftDefaults.push(data);
        }
        
        return data;
      } catch (error) {
        this.error = error instanceof ApiError ? error.message : 'Failed to create shift default';
        return null;
      } finally {
        this.loading.updating = false;
      }
    },
    
    async deleteShiftDefault(id) {
      this.loading.updating = true;
      this.error = null;
      
      try {
        await settingsApi.deleteShiftDefault(id);
        
        // Remove from local state
        this.shiftDefaults = this.shiftDefaults.filter(sd => sd.id !== id);
        
        return true;
      } catch (error) {
        this.error = error instanceof ApiError ? error.message : 'Failed to delete shift default';
        return false;
      } finally {
        this.loading.updating = false;
      }
    },
    
    // Utility methods (simplified for browser timezone)
    formatTime(timeString) {
      if (!timeString) return '00:00';
      
      const date = new Date(timeString);
      
      return date.toLocaleTimeString('en-GB', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false // Always 24-hour format
      });
    },
    
    // Load settings (alias for initialize - for compatibility)
    async loadSettings() {
      await this.initialize();
    },
    
    // Initialize data
    async initialize() {
      await Promise.all([
        this.fetchAppSettings(),
        this.fetchShiftDefaults()
      ]);
    }
  }
});
