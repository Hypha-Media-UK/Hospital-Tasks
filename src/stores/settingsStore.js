import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useSettingsStore = defineStore('settings', {
  state: () => ({
    shiftDefaults: {
      day: {
        startTime: '08:00',
        endTime: '16:00',
        color: '#4285F4' // Default blue
      },
      night: {
        startTime: '20:00',
        endTime: '08:00',
        color: '#673AB7' // Default purple
      }
    },
    appSettings: {
      timezone: 'UTC',
      timeFormat: '24h' // '12h' or '24h'
    },
    loading: false,
    error: null
  }),
  
  actions: {
    // Load all settings from Supabase
    async loadSettings() {
      this.loading = true;
      this.error = null;
      
      try {
        // Load shift defaults
        await this.loadShiftDefaults();
        
        // Load app settings
        await this.loadAppSettings();
        
        return true;
      } catch (error) {
        console.error('Error loading settings:', error);
        // Don't show error to user for initial load - we'll use defaults
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Load shift defaults from Supabase
    async loadShiftDefaults() {
      try {
        // Try to load from Supabase
        const { data, error } = await supabase
          .from('shift_defaults')
          .select('*');
        
        // Handle table not existing yet in development
        if (error && !error.message.includes('relation "shift_defaults" does not exist')) {
          throw error;
        }
        
        // Process data if it exists
        if (data && data.length > 0) {
          // Process each shift type
          data.forEach(shift => {
            if (shift.shift_type === 'day') {
              this.shiftDefaults.day = {
                startTime: shift.start_time.slice(0, 5),
                endTime: shift.end_time.slice(0, 5),
                color: shift.color
              };
            } else if (shift.shift_type === 'night') {
              this.shiftDefaults.night = {
                startTime: shift.start_time.slice(0, 5),
                endTime: shift.end_time.slice(0, 5),
                color: shift.color
              };
            }
          });
        } else if (import.meta.env.DEV) {
          // In development, try to load from localStorage as fallback
          const savedDefaults = localStorage.getItem('shift_defaults');
          if (savedDefaults) {
            try {
              const parsedDefaults = JSON.parse(savedDefaults);
              if (parsedDefaults.day) {
                this.shiftDefaults.day = {
                  ...this.shiftDefaults.day,
                  ...parsedDefaults.day
                };
              }
              if (parsedDefaults.night) {
                this.shiftDefaults.night = {
                  ...this.shiftDefaults.night,
                  ...parsedDefaults.night
                };
              }
            } catch (e) {
              console.warn('Error parsing localStorage shift defaults', e);
            }
          }
        }
        
        return data;
      } catch (error) {
        console.error('Error loading settings:', error);
        // Don't show error to user for initial load - we'll use defaults
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Save settings to Supabase
    async saveShiftDefaults() {
      this.loading = true;
      this.error = null;
      
      try {
        // For development, if the shift_defaults table doesn't exist yet, 
        // we'll use localStorage as a fallback
        if (import.meta.env.DEV) {
          try {
            // Try to save to Supabase first
            const results = await Promise.all([
              // Update day shift
              supabase
                .from('shift_defaults')
                .upsert({
                  shift_type: 'day',
                  start_time: this.shiftDefaults.day.startTime + ':00',
                  end_time: this.shiftDefaults.day.endTime + ':00',
                  color: this.shiftDefaults.day.color,
                  updated_at: new Date().toISOString()
                }, { onConflict: 'shift_type' })
                .select(),
                
              // Update night shift
              supabase
                .from('shift_defaults')
                .upsert({
                  shift_type: 'night',
                  start_time: this.shiftDefaults.night.startTime + ':00',
                  end_time: this.shiftDefaults.night.endTime + ':00',
                  color: this.shiftDefaults.night.color,
                  updated_at: new Date().toISOString()
                }, { onConflict: 'shift_type' })
                .select()
            ]);
            
            const [dayResult, nightResult] = results;
            
            if (dayResult.error || nightResult.error) {
              // If either operation failed, check if it's because table doesn't exist
              if ((dayResult.error && dayResult.error.message.includes('relation "shift_defaults" does not exist')) ||
                  (nightResult.error && nightResult.error.message.includes('relation "shift_defaults" does not exist'))) {
                // Save to localStorage instead
                localStorage.setItem('shift_defaults', JSON.stringify(this.shiftDefaults));
                console.log('Saved shift defaults to localStorage:', this.shiftDefaults);
                return [{ id: 'local-storage' }]; // Return a fake result
              }
              
              // If error is not related to missing table, throw it
              throw dayResult.error || nightResult.error;
            }
            
            return [...(dayResult.data || []), ...(nightResult.data || [])];
          } catch (err) {
            console.warn('Falling back to localStorage for settings:', err);
            localStorage.setItem('shift_defaults', JSON.stringify(this.shiftDefaults));
            return [{ id: 'local-storage' }]; // Return a fake result
          }
        } else {
          // Production mode - only use Supabase
          const results = await Promise.all([
            // Update day shift
            supabase
              .from('shift_defaults')
              .upsert({
                shift_type: 'day',
                start_time: this.shiftDefaults.day.startTime + ':00',
                end_time: this.shiftDefaults.day.endTime + ':00',
                color: this.shiftDefaults.day.color,
                updated_at: new Date().toISOString()
              }, { onConflict: 'shift_type' })
              .select(),
              
            // Update night shift
            supabase
              .from('shift_defaults')
              .upsert({
                shift_type: 'night',
                start_time: this.shiftDefaults.night.startTime + ':00',
                end_time: this.shiftDefaults.night.endTime + ':00',
                color: this.shiftDefaults.night.color,
                updated_at: new Date().toISOString()
              }, { onConflict: 'shift_type' })
              .select()
          ]);
          
          const [dayResult, nightResult] = results;
          
          if (dayResult.error) throw dayResult.error;
          if (nightResult.error) throw nightResult.error;
          
          return [...(dayResult.data || []), ...(nightResult.data || [])];
        }
      } catch (error) {
        console.error('Error saving shift defaults:', error);
        this.error = 'Failed to save shift defaults';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Update day shift defaults
    updateDayShiftDefaults(dayDefaults) {
      this.shiftDefaults.day = {
        ...this.shiftDefaults.day,
        ...dayDefaults
      };
    },
    
    // Update night shift defaults
    updateNightShiftDefaults(nightDefaults) {
      this.shiftDefaults.night = {
        ...this.shiftDefaults.night,
        ...nightDefaults
      };
    },
    
    // Load app settings from Supabase
    async loadAppSettings() {
      try {
        // Try to load from Supabase
        const { data, error } = await supabase
          .from('app_settings')
          .select('*')
          .limit(1)
          .single();
        
        // Handle table not existing yet in development
        if (error) {
          if (error.message.includes('relation "app_settings" does not exist')) {
            // Table doesn't exist yet, use defaults
            return null;
          } else if (error.code === 'PGRST116') {
            // No rows found, use defaults
            return null;
          } else {
            throw error;
          }
        }
        
        // Process data if it exists
        if (data) {
          this.appSettings = {
            timezone: data.timezone || 'UTC',
            timeFormat: data.time_format || '24h'
          };
        } else if (import.meta.env.DEV) {
          // In development, try to load from localStorage as fallback
          const savedSettings = localStorage.getItem('app_settings');
          if (savedSettings) {
            try {
              const parsedSettings = JSON.parse(savedSettings);
              this.appSettings = {
                ...this.appSettings,
                ...parsedSettings
              };
            } catch (e) {
              console.warn('Error parsing localStorage app settings', e);
            }
          }
        }
        
        return data;
      } catch (error) {
        console.error('Error loading app settings:', error);
        // Don't show error to user for initial load - we'll use defaults
        return null;
      }
    },
    
    // Save app settings to Supabase
    async saveAppSettings() {
      this.loading = true;
      this.error = null;
      
      try {
        // For development, if the app_settings table doesn't exist yet, 
        // we'll use localStorage as a fallback
        if (import.meta.env.DEV) {
          try {
            // Try to save to Supabase first
            const { data, error } = await supabase
              .from('app_settings')
              .upsert({
                timezone: this.appSettings.timezone,
                time_format: this.appSettings.timeFormat,
                updated_at: new Date().toISOString()
              })
              .select();
            
            if (error) {
              // If operation failed, check if it's because table doesn't exist
              if (error.message.includes('relation "app_settings" does not exist')) {
                // Save to localStorage instead
                localStorage.setItem('app_settings', JSON.stringify(this.appSettings));
                console.log('Saved app settings to localStorage:', this.appSettings);
                return [{ id: 'local-storage' }]; // Return a fake result
              }
              
              // If error is not related to missing table, throw it
              throw error;
            }
            
            return data;
          } catch (err) {
            console.warn('Falling back to localStorage for app settings:', err);
            localStorage.setItem('app_settings', JSON.stringify(this.appSettings));
            return [{ id: 'local-storage' }]; // Return a fake result
          }
        } else {
          // Production mode - only use Supabase
          const { data, error } = await supabase
            .from('app_settings')
            .upsert({
              timezone: this.appSettings.timezone,
              time_format: this.appSettings.timeFormat,
              updated_at: new Date().toISOString()
            })
            .select();
          
          if (error) throw error;
          
          return data;
        }
      } catch (error) {
        console.error('Error saving app settings:', error);
        this.error = 'Failed to save app settings';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Update app settings
    updateAppSettings(settings) {
      this.appSettings = {
        ...this.appSettings,
        ...settings
      };
    },
    
    // Format a datetime based on current app settings
    formatDateTime(dateString) {
      if (!dateString) return '';
      
      const date = new Date(dateString);
      // Apply timezone conversion if needed
      
      // Return formatted time based on user preference
      if (this.appSettings.timeFormat === '12h') {
        return date.toLocaleTimeString('en-US', { 
          hour: 'numeric', 
          minute: '2-digit', 
          hour12: true 
        });
      } else {
        return date.toLocaleTimeString('en-US', { 
          hour: '2-digit', 
          minute: '2-digit', 
          hour12: false 
        });
      }
    }
  }
});
