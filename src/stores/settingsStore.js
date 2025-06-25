import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useSettingsStore = defineStore('settings', {
  state: () => ({
    shiftDefaults: {
      // Only using proper shift types
      week_day: {
        startTime: '08:00',
        endTime: '20:00',
        color: '#4285F4' // Default blue
      },
      week_night: {
        startTime: '20:00',
        endTime: '08:00',
        color: '#673AB7' // Default purple
      },
      weekend_day: {
        startTime: '08:00',
        endTime: '20:00',
        color: '#34A853' // Default green
      },
      weekend_night: {
        startTime: '20:00',
        endTime: '08:00',
        color: '#EA4335' // Default red
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
            // Update the specific shift type if valid
            if (this.shiftDefaults[shift.shift_type]) {
              this.shiftDefaults[shift.shift_type] = {
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
              // Map any legacy settings to their proper types
              if (parsedDefaults.day) {
                this.shiftDefaults.week_day = {
                  ...this.shiftDefaults.week_day,
                  ...parsedDefaults.day
                };
              }
              if (parsedDefaults.night) {
                this.shiftDefaults.week_night = {
                  ...this.shiftDefaults.week_night,
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
              // Update all shift types
              // Update week_day shift
              supabase
                .from('shift_defaults')
                .upsert({
                  shift_type: 'week_day',
                  start_time: this.shiftDefaults.week_day.startTime + ':00',
                  end_time: this.shiftDefaults.week_day.endTime + ':00',
                  color: this.shiftDefaults.week_day.color,
                  updated_at: new Date().toISOString()
                }, { onConflict: 'shift_type' })
                .select(),
                
              // Update week_night shift
              supabase
                .from('shift_defaults')
                .upsert({
                  shift_type: 'week_night',
                  start_time: this.shiftDefaults.week_night.startTime + ':00',
                  end_time: this.shiftDefaults.week_night.endTime + ':00',
                  color: this.shiftDefaults.week_night.color,
                  updated_at: new Date().toISOString()
                }, { onConflict: 'shift_type' })
                .select(),
              
              // Update weekend_day shift
              supabase
                .from('shift_defaults')
                .upsert({
                  shift_type: 'weekend_day',
                  start_time: this.shiftDefaults.weekend_day.startTime + ':00',
                  end_time: this.shiftDefaults.weekend_day.endTime + ':00',
                  color: this.shiftDefaults.weekend_day.color,
                  updated_at: new Date().toISOString()
                }, { onConflict: 'shift_type' })
                .select(),
                
              // Update weekend_night shift
              supabase
                .from('shift_defaults')
                .upsert({
                  shift_type: 'weekend_night',
                  start_time: this.shiftDefaults.weekend_night.startTime + ':00',
                  end_time: this.shiftDefaults.weekend_night.endTime + ':00',
                  color: this.shiftDefaults.weekend_night.color,
                  updated_at: new Date().toISOString()
                }, { onConflict: 'shift_type' })
                .select()
            ]);
            
            // Check for errors
            const anyError = results.find(result => result.error);
            
            if (anyError) {
              // If any operation failed, check if it's because table doesn't exist
              if (anyError.error.message.includes('relation "shift_defaults" does not exist')) {
                // Save to localStorage instead
                localStorage.setItem('shift_defaults', JSON.stringify(this.shiftDefaults));
                console.log('Saved shift defaults to localStorage:', this.shiftDefaults);
                return [{ id: 'local-storage' }]; // Return a fake result
              }
              
              // If error is not related to missing table, throw it
              throw anyError.error;
            }
            
            // Combine all results
            const allData = results.reduce((acc, result) => {
              return [...acc, ...(result.data || [])];
            }, []);
            
            return allData;
          } catch (err) {
            console.warn('Falling back to localStorage for settings:', err);
            localStorage.setItem('shift_defaults', JSON.stringify(this.shiftDefaults));
            return [{ id: 'local-storage' }]; // Return a fake result
          }
        } else {
          // Production mode - only use Supabase
          const results = await Promise.all([
            // Update week_day shift
            supabase
              .from('shift_defaults')
              .upsert({
                shift_type: 'week_day',
                start_time: this.shiftDefaults.week_day.startTime + ':00',
                end_time: this.shiftDefaults.week_day.endTime + ':00',
                color: this.shiftDefaults.week_day.color,
                updated_at: new Date().toISOString()
              }, { onConflict: 'shift_type' })
              .select(),
              
            // Update week_night shift
            supabase
              .from('shift_defaults')
              .upsert({
                shift_type: 'week_night',
                start_time: this.shiftDefaults.week_night.startTime + ':00',
                end_time: this.shiftDefaults.week_night.endTime + ':00',
                color: this.shiftDefaults.week_night.color,
                updated_at: new Date().toISOString()
              }, { onConflict: 'shift_type' })
              .select(),
              
            // Update weekend_day shift
            supabase
              .from('shift_defaults')
              .upsert({
                shift_type: 'weekend_day',
                start_time: this.shiftDefaults.weekend_day.startTime + ':00',
                end_time: this.shiftDefaults.weekend_day.endTime + ':00',
                color: this.shiftDefaults.weekend_day.color,
                updated_at: new Date().toISOString()
              }, { onConflict: 'shift_type' })
              .select(),
              
            // Update weekend_night shift
            supabase
              .from('shift_defaults')
              .upsert({
                shift_type: 'weekend_night',
                start_time: this.shiftDefaults.weekend_night.startTime + ':00',
                end_time: this.shiftDefaults.weekend_night.endTime + ':00',
                color: this.shiftDefaults.weekend_night.color,
                updated_at: new Date().toISOString()
              }, { onConflict: 'shift_type' })
              .select()
          ]);
          
          // Check for errors in any of the results
          for (const result of results) {
            if (result.error) throw result.error;
          }
          
          // Combine all results data
          const allData = results.reduce((acc, result) => {
            return [...acc, ...(result.data || [])];
          }, []);
          
          return allData;
        }
      } catch (error) {
        console.error('Error saving shift defaults:', error);
        this.error = 'Failed to save shift defaults';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Update day shift defaults (both weekday and weekend)
    updateDayShiftDefaults(dayDefaults) {
      // Apply to weekday day shifts
      this.shiftDefaults.week_day = {
        ...this.shiftDefaults.week_day,
        ...dayDefaults
      };
      
      // Apply the same settings to weekend day shifts
      this.shiftDefaults.weekend_day = {
        ...this.shiftDefaults.weekend_day,
        startTime: dayDefaults.startTime || this.shiftDefaults.weekend_day.startTime,
        endTime: dayDefaults.endTime || this.shiftDefaults.weekend_day.endTime,
        // Keep the weekend color unless specifically changed
        color: dayDefaults.color || this.shiftDefaults.weekend_day.color
      };
    },
    
    // Update night shift defaults (both weekday and weekend)
    updateNightShiftDefaults(nightDefaults) {
      // Apply to weekday night shifts
      this.shiftDefaults.week_night = {
        ...this.shiftDefaults.week_night,
        ...nightDefaults
      };
      
      // Apply the same settings to weekend night shifts
      this.shiftDefaults.weekend_night = {
        ...this.shiftDefaults.weekend_night,
        startTime: nightDefaults.startTime || this.shiftDefaults.weekend_night.startTime,
        endTime: nightDefaults.endTime || this.shiftDefaults.weekend_night.endTime,
        // Keep the weekend color unless specifically changed
        color: nightDefaults.color || this.shiftDefaults.weekend_night.color
      };
    },
    
    // Load app settings from Supabase
    async loadAppSettings() {
      try {
        console.log('Loading app settings from database...');
        
        // Try to load from Supabase
        const { data, error } = await supabase
          .from('app_settings')
          .select('*')
          .order('updated_at', { ascending: false })
          .limit(1)
          .single();
        
        // Handle table not existing yet in development
        if (error) {
          if (error.message.includes('relation "app_settings" does not exist')) {
            console.log('App settings table does not exist, using defaults');
            return null;
          } else if (error.code === 'PGRST116') {
            console.log('No app settings found in database, using defaults');
            return null;
          } else {
            console.error('Error loading app settings:', error);
            throw error;
          }
        }
        
        // Process data if it exists
        if (data) {
          console.log('Loaded app settings from database:', data);
          this.appSettings = {
            timezone: data.timezone || 'UTC',
            timeFormat: data.time_format || '24h'
          };
          console.log('Updated app settings state:', this.appSettings);
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
              console.log('Loaded app settings from localStorage:', this.appSettings);
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
