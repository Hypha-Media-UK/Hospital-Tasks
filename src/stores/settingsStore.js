import { defineStore } from 'pinia';
import { settingsApi, ApiError } from '../services/api';

export const useSettingsStore = defineStore('settings', {
  state: () => ({
    appSettings: {
      timezone: 'UTC',
      time_format: '24h'
    },
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
    
    // Get current timezone
    currentTimezone: (state) => {
      return state.appSettings.timezone || 'UTC';
    },
    
    // Get current time format
    currentTimeFormat: (state) => {
      return state.appSettings.time_format || '24h';
    },
    
    // Check if using 12-hour format
    is12HourFormat: (state) => {
      return state.appSettings.time_format === '12h';
    },
    
    // Get available timezones (static list)
    availableTimezones: () => [
      'UTC',
      'GMT',
      'Europe/London',
      'Europe/Paris',
      'Europe/Berlin',
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
      'Asia/Tokyo',
      'Asia/Shanghai',
      'Australia/Sydney'
    ],
    
    // Get available time formats
    availableTimeFormats: () => [
      { value: '24h', label: '24 Hour (14:30)' },
      { value: '12h', label: '12 Hour (2:30 PM)' }
    ]
  },
  
  actions: {
    // App Settings operations
    async fetchAppSettings() {
      this.loading.appSettings = true;
      this.error = null;
      
      try {
        const data = await settingsApi.get();
        this.appSettings = data || {
          timezone: 'UTC',
          time_format: '24h'
        };
      } catch (error) {
        console.error('Error fetching app settings:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load app settings';
      } finally {
        this.loading.appSettings = false;
      }
    },
    
    async updateAppSettings(settings) {
      this.loading.updating = true;
      this.error = null;
      
      try {
        const data = await settingsApi.update(settings);
        
        if (data) {
          this.appSettings = data;
        }
        
        return true;
      } catch (error) {
        console.error('Error updating app settings:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update app settings';
        return false;
      } finally {
        this.loading.updating = false;
      }
    },
    
    async updateTimezone(timezone) {
      return this.updateAppSettings({ 
        ...this.appSettings, 
        timezone 
      });
    },
    
    async updateTimeFormat(timeFormat) {
      return this.updateAppSettings({ 
        ...this.appSettings, 
        time_format: timeFormat 
      });
    },
    
    // Shift Defaults operations
    async fetchShiftDefaults() {
      this.loading.shiftDefaults = true;
      this.error = null;
      
      try {
        const data = await settingsApi.getShiftDefaults();
        this.shiftDefaults = data || [];
      } catch (error) {
        console.error('Error fetching shift defaults:', error);
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
        console.error('Error updating shift default:', error);
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
        console.error('Error creating shift default:', error);
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
        console.error('Error deleting shift default:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete shift default';
        return false;
      } finally {
        this.loading.updating = false;
      }
    },
    
    // Utility methods
    formatTime(timeString, use12Hour = null) {
      if (!timeString) return '00:00';
      
      const use12HourFormat = use12Hour !== null ? use12Hour : this.is12HourFormat;
      const date = new Date(timeString);
      
      return date.toLocaleTimeString('en-GB', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: use12HourFormat
      });
    },
    
    formatDate(dateString) {
      if (!dateString) return '';
      
      const date = new Date(dateString);
      return date.toLocaleDateString('en-GB', {
        timeZone: this.currentTimezone
      });
    },
    
    formatDateTime(dateTimeString) {
      if (!dateTimeString) return '';
      
      const date = new Date(dateTimeString);
      return date.toLocaleString('en-GB', {
        timeZone: this.currentTimezone,
        hour12: this.is12HourFormat
      });
    },
    
    // Get current date/time in the configured timezone
    getCurrentDateTime() {
      return new Date().toLocaleString('en-GB', {
        timeZone: this.currentTimezone,
        hour12: this.is12HourFormat
      });
    },
    
    getCurrentDate() {
      return new Date().toLocaleDateString('en-GB', {
        timeZone: this.currentTimezone
      });
    },
    
    getCurrentTime() {
      return new Date().toLocaleTimeString('en-GB', {
        timeZone: this.currentTimezone,
        hour: '2-digit',
        minute: '2-digit',
        hour12: this.is12HourFormat
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
