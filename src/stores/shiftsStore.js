import { defineStore } from 'pinia';
import { shiftsApi, tasksApi, ApiError } from '../services/api';

// Helper function to determine if a date is on a weekend
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}

export const useShiftsStore = defineStore('shifts', {
  state: () => ({
    activeShifts: [],
    archivedShifts: [],
    archivedShiftTaskCounts: {}, // Task counts for archived shifts
    currentShift: null,
    shiftTasks: [],
    shiftAreaCoverAssignments: [], // Shift-specific area cover assignments
    shiftAreaCoverPorterAssignments: [], // Porter assignments for shift area cover
    shiftSupportServiceAssignments: [], // Shift-specific support service assignments
    shiftSupportServicePorterAssignments: [], // Porter assignments for shift support services
    shiftPorterPool: [], // Porters assigned to the current shift
    shiftPorterAbsences: [], // Porter absences for the current shift
    loading: {
      activeShifts: false,
      archivedShifts: false,
      currentShift: false,
      shiftTasks: false,
      createShift: false,
      endShift: false,
      updateTask: false,
      areaCover: false, // Loading state for area cover operations
      supportServices: false, // Loading state for support service operations
      porterPool: false, // Loading state for porter pool operations
      deleteShift: false
    },
    error: null
  }),
  
  getters: {
    // Get active day shifts (week_day and weekend_day)
    activeDayShifts: (state) => {
      return state.activeShifts.filter(shift => 
        shift.shift_type === 'week_day' || shift.shift_type === 'weekend_day'
      );
    },
    
    // Get active night shifts (week_night and weekend_night)
    activeNightShifts: (state) => {
      return state.activeShifts.filter(shift => 
        shift.shift_type === 'week_night' || shift.shift_type === 'weekend_night'
      );
    },
    
    // Get pending tasks for current shift
    pendingTasks: (state) => {
      return state.shiftTasks.filter(task => task.status === 'pending');
    },
    
    // Get completed tasks for current shift
    completedTasks: (state) => {
      return state.shiftTasks.filter(task => task.status === 'completed');
    },
    
    // Get area cover assignments for current shift sorted by department name
    sortedAreaCoverAssignments: (state) => {
      return [...state.shiftAreaCoverAssignments].sort((a, b) => {
        return a.department?.name?.localeCompare(b.department?.name) || 0;
      });
    },
    
    // Get support service assignments for current shift sorted by service name
    sortedSupportServiceAssignments: (state) => {
      return [...state.shiftSupportServiceAssignments].sort((a, b) => {
        return a.service?.name?.localeCompare(b.service?.name) || 0;
      });
    },
    
    // Get area cover assignments for day shifts (week_day and weekend_day)
    shiftDayAreaCoverAssignments: (state) => {
      return state.shiftAreaCoverAssignments.filter(assignment => 
        assignment.shift_type === 'week_day' || assignment.shift_type === 'weekend_day'
      );
    },
    
    // Get area cover assignments for night shifts (week_night and weekend_night)
    shiftNightAreaCoverAssignments: (state) => {
      return state.shiftAreaCoverAssignments.filter(assignment => 
        assignment.shift_type === 'week_night' || assignment.shift_type === 'weekend_night'
      );
    },
    
    // Get area cover assignment by ID
    getAreaCoverAssignmentById: (state) => (id) => {
      return state.shiftAreaCoverAssignments.find(a => a.id === id);
    },
    
    // Get support service assignment by ID
    getSupportServiceAssignmentById: (state) => (id) => {
      return state.shiftSupportServiceAssignments.find(a => a.id === id);
    },
    
    // Get porter assignments for a specific area cover assignment
    getPorterAssignmentsByAreaId: (state) => (areaCoverId) => {
      return state.shiftAreaCoverPorterAssignments.filter(
        pa => pa.shift_area_cover_assignment_id === areaCoverId
      );
    },
    
    // Get porter assignments for a specific support service assignment
    getPorterAssignmentsByServiceId: (state) => (serviceId) => {
      return state.shiftSupportServicePorterAssignments.filter(
        pa => pa.shift_support_service_assignment_id === serviceId
      );
    }
  },
  
  actions: {
    // Fetch all active shifts
    async fetchActiveShifts() {
      this.loading.activeShifts = true;
      this.error = null;
      
      try {
        const data = await shiftsApi.getAll({ is_active: true });
        this.activeShifts = data || [];
      } catch (error) {
        console.error('Error fetching active shifts:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load active shifts';
      } finally {
        this.loading.activeShifts = false;
      }
    },
    
    // Fetch all archived shifts
    async fetchArchivedShifts() {
      this.loading.archivedShifts = true;
      this.error = null;
      
      try {
        const data = await shiftsApi.getAll({ is_active: false });
        this.archivedShifts = data || [];
      } catch (error) {
        console.error('Error fetching archived shifts:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load archived shifts';
      } finally {
        this.loading.archivedShifts = false;
      }
    },
    
    // Fetch a specific shift by ID
    async fetchShiftById(shiftId) {
      this.loading.currentShift = true;
      this.error = null;
      
      try {
        const data = await shiftsApi.getById(shiftId);
        this.currentShift = data;
        return data;
      } catch (error) {
        console.error('Error fetching shift:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load shift details';
        return null;
      } finally {
        this.loading.currentShift = false;
      }
    },
    
    // Fetch tasks for a specific shift
    async fetchShiftTasks(shiftId) {
      this.loading.shiftTasks = true;
      this.error = null;
      
      try {
        const data = await tasksApi.getByShiftId(shiftId);
        this.shiftTasks = Array.isArray(data) ? data : [];
        return this.shiftTasks;
      } catch (error) {
        console.error('Error fetching shift tasks:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load shift tasks';
        this.shiftTasks = []; // Ensure it's always an array
        return [];
      } finally {
        this.loading.shiftTasks = false;
      }
    },
    
    // Create a new shift
    async createShift(supervisorId, shiftType, shiftDate = null) {
      this.loading.createShift = true;
      this.error = null;
      
      try {
        // Use provided shift date or default to current date
        const targetShiftDate = shiftDate ? new Date(shiftDate) : new Date();
        
        // Format the shift date as YYYY-MM-DD
        const shiftDateString = targetShiftDate.toISOString().split('T')[0];
        
        console.log(`Creating new shift: type=${shiftType}`);
        console.log(`Creating new shift with supervisor: ${supervisorId}, type: ${shiftType}`);
        
        const shiftData = {
          supervisor_id: supervisorId,
          shift_type: shiftType,
          shift_date: shiftDateString,
          start_time: new Date().toISOString(),
          is_active: true
        };
        
        const data = await shiftsApi.create(shiftData);
        
        if (data) {
          console.log(`Created new shift with ID: ${data.id}, type: ${data.shift_type}`);
          
          // Add the new shift to activeShifts array
          this.activeShifts.unshift(data);
          
          // Initialize area cover and support services from defaults
          try {
            console.log(`Initializing default assignments for new shift ${data.id}`);
            
            // Initialize area cover assignments
            const areaCoverResult = await shiftsApi.initializeAreaCover(data.id);
            if (areaCoverResult && areaCoverResult.assignments) {
              console.log(`Initialized ${areaCoverResult.assignments.length} area cover assignments`);
            }
            
            // Initialize support service assignments
            const supportServicesResult = await shiftsApi.initializeSupportServices(data.id);
            if (supportServicesResult && supportServicesResult.assignments) {
              console.log(`Initialized ${supportServicesResult.assignments.length} support service assignments`);
            }
            
          } catch (initError) {
            console.warn('Error initializing default assignments for new shift:', initError);
            // Don't fail the shift creation if initialization fails
          }
          
          return data;
        }
        
        return null;
      } catch (error) {
        console.error('Error creating shift:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to create shift';
        return null;
      } finally {
        this.loading.createShift = false;
      }
    },
    
    // End an active shift
    async endShift(shiftId) {
      this.loading.endShift = true;
      this.error = null;
      
      try {
        const data = await shiftsApi.endShift(shiftId);
        
        if (data) {
          // Remove the shift from activeShifts array
          this.activeShifts = this.activeShifts.filter(shift => shift.id !== shiftId);
          
          // If this was the current shift, update it
          if (this.currentShift && this.currentShift.id === shiftId) {
            this.currentShift = data;
          }
          
          // Add to archived shifts if we have that loaded
          if (this.archivedShifts.length > 0) {
            this.archivedShifts.unshift(data);
          }
          
          return data;
        }
        
        return null;
      } catch (error) {
        console.error('Error ending shift:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to end shift';
        return null;
      } finally {
        this.loading.endShift = false;
      }
    },
    
    // Add a task to a shift
    async addTaskToShift(shiftId, taskData) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        const data = await tasksApi.create({ ...taskData, shift_id: shiftId });
        
        if (data) {
          // Add the new task to shiftTasks array
          this.shiftTasks.unshift(data);
          return data;
        }
        
        return null;
      } catch (error) {
        console.error('Error adding task to shift:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to add task';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Update task status
    async updateTaskStatus(taskId, status) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        const data = await tasksApi.update(taskId, { status });
        
        if (data) {
          // Update the task in shiftTasks array
          const index = this.shiftTasks.findIndex(task => task.id === taskId);
          if (index !== -1) {
            this.shiftTasks[index] = data;
          }
          return data;
        }
        
        return null;
      } catch (error) {
        console.error('Error updating task status:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update task status';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Update an existing task
    async updateTask(taskId, taskData) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        const data = await tasksApi.update(taskId, taskData);
        
        if (data) {
          // Update the task in shiftTasks array
          const index = this.shiftTasks.findIndex(task => task.id === taskId);
          if (index !== -1) {
            this.shiftTasks[index] = data;
          }
          return data;
        }
        
        return null;
      } catch (error) {
        console.error('Error updating task:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update task';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Update shift supervisor
    async updateShiftSupervisor(shiftId, supervisorId) {
      this.loading.currentShift = true;
      this.error = null;
      
      try {
        const data = await shiftsApi.update(shiftId, { supervisor_id: supervisorId });
        
        if (data) {
          // Update current shift if it matches
          if (this.currentShift && this.currentShift.id === shiftId) {
            this.currentShift = data;
          }
          
          // Update in active shifts array
          const index = this.activeShifts.findIndex(shift => shift.id === shiftId);
          if (index !== -1) {
            this.activeShifts[index] = data;
          }
          
          return data;
        }
        
        return null;
      } catch (error) {
        console.error('Error updating shift supervisor:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update supervisor';
        return null;
      } finally {
        this.loading.currentShift = false;
      }
    },
    
    // Delete a shift
    async deleteShift(shiftId) {
      this.loading.deleteShift = true;
      this.error = null;
      
      try {
        await shiftsApi.delete(shiftId);
        
        // Remove from local state
        this.archivedShifts = this.archivedShifts.filter(shift => shift.id !== shiftId);
        this.activeShifts = this.activeShifts.filter(shift => shift.id !== shiftId);
        
        return true;
      } catch (error) {
        console.error('Error deleting shift:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete shift';
        return false;
      } finally {
        this.loading.deleteShift = false;
      }
    },
    
    // Clear current shift and tasks
    clearCurrentShift() {
      this.currentShift = null;
      this.shiftTasks = [];
      this.shiftAreaCoverAssignments = [];
      this.shiftAreaCoverPorterAssignments = [];
      this.shiftSupportServiceAssignments = [];
      this.shiftSupportServicePorterAssignments = [];
      this.shiftPorterPool = [];
      this.shiftPorterAbsences = [];
    },
    
    // Initialize store data
    async initialize() {
      await this.fetchActiveShifts();
    },
    
    // Placeholder methods for area cover, support services, and porter pool
    // These would need to be implemented when the corresponding API endpoints are available
    
    async fetchShiftAreaCover(shiftId) {
      this.loading.areaCover = true;
      try {
        const data = await shiftsApi.getAreaCover(shiftId);
        this.shiftAreaCoverAssignments = Array.isArray(data) ? data : [];
        
        // Extract porter assignments from the area cover assignments
        this.shiftAreaCoverPorterAssignments = [];
        this.shiftAreaCoverAssignments.forEach(assignment => {
          if (assignment.porter_assignments) {
            this.shiftAreaCoverPorterAssignments.push(...assignment.porter_assignments);
          }
        });
        
        return this.shiftAreaCoverAssignments;
      } catch (error) {
        console.error('Error fetching shift area cover:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load shift area cover';
        this.shiftAreaCoverAssignments = [];
        this.shiftAreaCoverPorterAssignments = [];
        return [];
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    async fetchShiftSupportServices(shiftId) {
      this.loading.supportServices = true;
      try {
        const data = await shiftsApi.getSupportServices(shiftId);
        this.shiftSupportServiceAssignments = Array.isArray(data) ? data : [];
        
        // Extract porter assignments from the support service assignments
        this.shiftSupportServicePorterAssignments = [];
        this.shiftSupportServiceAssignments.forEach(assignment => {
          if (assignment.porter_assignments) {
            this.shiftSupportServicePorterAssignments.push(...assignment.porter_assignments);
          }
        });
        
        return this.shiftSupportServiceAssignments;
      } catch (error) {
        console.error('Error fetching shift support services:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load shift support services';
        this.shiftSupportServiceAssignments = [];
        this.shiftSupportServicePorterAssignments = [];
        return [];
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    async fetchShiftPorterPool(shiftId) {
      this.loading.porterPool = true;
      try {
        const data = await shiftsApi.getPorterPool(shiftId);
        this.shiftPorterPool = Array.isArray(data) ? data : [];
        return this.shiftPorterPool;
      } catch (error) {
        console.error('Error fetching shift porter pool:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load shift porter pool';
        this.shiftPorterPool = [];
        return [];
      } finally {
        this.loading.porterPool = false;
      }
    },
    
    async fetchShiftPorterAbsences(shiftId) {
      // Note: Porter absences are handled by the staff store for global absences
      // Shift-specific absences would need a separate API endpoint if implemented
      console.log(`fetchShiftPorterAbsences called for shift ${shiftId} - using global absences from staff store`);
      this.shiftPorterAbsences = [];
      return [];
    },
    
    async setupShiftAreaCoverFromDefaults(shiftId, shiftType) {
      this.loading.areaCover = true;
      try {
        console.log(`Setting up area cover from defaults for shift ${shiftId}, type ${shiftType}`);
        const result = await shiftsApi.initializeAreaCover(shiftId);
        
        if (result && result.assignments) {
          console.log(`Successfully initialized ${result.assignments.length} area cover assignments`);
          // Refresh the area cover assignments after initialization
          await this.fetchShiftAreaCover(shiftId);
          return true;
        }
        
        return false;
      } catch (error) {
        console.error('Error setting up shift area cover from defaults:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to initialize area cover from defaults';
        return false;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    async cleanupAllExpiredAssignments() {
      console.log('cleanupAllExpiredAssignments called - not yet implemented');
      return { total: 0 };
    },
    
    // Fetch task counts for archived shifts
    async fetchArchivedShiftTaskCounts() {
      try {
        console.log('Loading archived shifts...');
        await this.fetchArchivedShifts();
        console.log(`Loaded ${this.archivedShifts.length} archived shifts`);
        
        // For now, return empty task counts since the tasks API is not fully implemented
        // This prevents the error while maintaining functionality
        const taskCounts = {};
        this.archivedShifts.forEach(shift => {
          taskCounts[shift.id] = 0; // Simple count for now
        });
        
        // Store the task counts in the state
        this.archivedShiftTaskCounts = taskCounts;
        
        return taskCounts;
      } catch (error) {
        console.error('Error loading archived shifts:', error);
        this.archivedShiftTaskCounts = {};
        return {};
      }
    }
  }
});
