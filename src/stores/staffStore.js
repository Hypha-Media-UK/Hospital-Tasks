import { defineStore } from 'pinia';
import { staffApi, absencesApi, ApiError } from '../services/api';

export const useStaffStore = defineStore('staff', {
  state: () => ({
    supervisors: [],
    porters: [],
    porterAbsences: [],
    loading: {
      supervisors: false,
      porters: false,
      staff: false,
      absences: false
    },
    sortBy: 'firstName', // 'firstName' or 'lastName'
    porterTypeFilter: 'all', // 'all', 'shift', or 'relief'
    shiftTimeFilter: 'all', // 'all', 'day', or 'night'
    sortDirection: 'asc', // 'asc' or 'desc'
    searchQuery: '', // For filtering porters by name
    availabilityPatterns: [
      'Weekdays - Days',
      'Weekdays - Nights',
      'Weekdays - Days and Nights',
      'Weekends - Days',
      'Weekends - Nights',
      'Weekends - Days and Nights',
      '4 on 4 off - Days',
      '4 on 4 off - Nights',
      '4 on 4 off - Days and Nights'
    ],
    error: null
  }),
  
  getters: {
    // Get sorted supervisors
    sortedSupervisors: (state) => {
      return [...state.supervisors].sort((a, b) => {
        if (state.sortBy === 'firstName') {
          return a.first_name.localeCompare(b.first_name);
        } else {
          return a.last_name.localeCompare(b.last_name);
        }
      });
    },
    
    // Get sorted porters (basic filtering without shift time filter)
    sortedPorters: (state) => {
      // First apply type filter, then sort
      let filteredPorters = [...state.porters];
      
      // Apply porter type filter if not set to 'all'
      if (state.porterTypeFilter !== 'all') {
        filteredPorters = filteredPorters.filter(porter => 
          porter.porter_type === state.porterTypeFilter
        );
      }
      
      // Apply search query filter if there is one
      if (state.searchQuery.trim()) {
        const query = state.searchQuery.toLowerCase().trim();
        filteredPorters = filteredPorters.filter(porter => {
          const fullName = `${porter.first_name} ${porter.last_name}`.toLowerCase();
          return fullName.includes(query);
        });
      }
      
      // Then sort the filtered list
      return filteredPorters.sort((a, b) => {
        let comparison = 0;
        if (state.sortBy === 'firstName') {
          comparison = a.first_name.localeCompare(b.first_name);
        } else {
          comparison = a.last_name.localeCompare(b.last_name);
        }
        
        // Apply sort direction
        return state.sortDirection === 'asc' ? comparison : -comparison;
      });
    },
    
    // Get staff member by ID
    getStaffById: (state) => (id) => {
      return [...state.supervisors, ...state.porters].find(staff => staff.id === id);
    },
    
    // Check if a porter is absent for a given date
    isPorterAbsent: (state) => (porterId, date) => {
      // Convert string date to Date object if needed
      const checkDate = typeof date === 'string' ? new Date(date) : date;
      
      return state.porterAbsences.some(absence => {
        const startDate = new Date(absence.start_date);
        const endDate = new Date(absence.end_date);
        return absence.porter_id === porterId && 
               checkDate >= startDate && 
               checkDate <= endDate;
      });
    },
    
    // Get absence details for a porter on a specific date
    getPorterAbsenceDetails: (state) => (porterId, date) => {
      // Convert string date to Date object if needed
      const checkDate = typeof date === 'string' ? new Date(date) : date;
      
      return state.porterAbsences.find(absence => {
        const startDate = new Date(absence.start_date);
        const endDate = new Date(absence.end_date);
        return absence.porter_id === porterId && 
               checkDate >= startDate && 
               checkDate <= endDate;
      }) || null;
    },
    
    // Format availability for display
    formatAvailability: () => (porter) => {
      if (porter.availability_pattern) {
        // For 24-hour patterns (Days and Nights), don't show time range
        if (porter.availability_pattern.includes('Days and Nights')) {
          return `${porter.availability_pattern} (24hrs)`;
        } else if (porter.contracted_hours_start && porter.contracted_hours_end) {
          // Helper function to safely format time
          const formatTime = (timeValue) => {
            if (!timeValue) return '00:00';
            
            // If it's already a string in HH:MM format, return first 5 chars
            if (typeof timeValue === 'string' && timeValue.includes(':')) {
              return timeValue.substring(0, 5);
            }
            
            // If it's a Date object, format it
            if (timeValue instanceof Date) {
              return timeValue.toTimeString().substring(0, 5);
            }
            
            // If it's a timestamp or other format, try to convert
            try {
              const date = new Date(timeValue);
              if (!isNaN(date.getTime())) {
                return date.toTimeString().substring(0, 5);
              }
            } catch (error) {
              console.warn('Invalid time format:', timeValue);
            }
            
            // Fallback to default time
            return '00:00';
          };
          
          const startTime = formatTime(porter.contracted_hours_start);
          const endTime = formatTime(porter.contracted_hours_end);
          
          return `${porter.availability_pattern} (${startTime}-${endTime})`;
        } else {
          return porter.availability_pattern;
        }
      }
      return 'No availability set';
    },
    
    // Determine porter shift type based on contracted hours vs shift defaults
    getPorterShiftType: () => (porter, shiftDefaults) => {
      if (!porter.contracted_hours_start || !porter.contracted_hours_end || !shiftDefaults) {
        return 'unknown';
      }
      
      // Check if shiftDefaults has the expected structure
      if (!shiftDefaults.week_day || !shiftDefaults.week_night || 
          !shiftDefaults.week_day.startTime || !shiftDefaults.week_day.endTime ||
          !shiftDefaults.week_night.startTime || !shiftDefaults.week_night.endTime) {
        return 'unknown';
      }
      
      const porterStart = porter.contracted_hours_start.substring(0, 5);
      const porterEnd = porter.contracted_hours_end.substring(0, 5);
      
      const dayStart = shiftDefaults.week_day.startTime;
      const dayEnd = shiftDefaults.week_day.endTime;
      const nightStart = shiftDefaults.week_night.startTime;
      const nightEnd = shiftDefaults.week_night.endTime;
      
      // Helper function to convert time string to minutes for comparison
      const timeToMinutes = (timeStr) => {
        const [hours, minutes] = timeStr.split(':').map(Number);
        return hours * 60 + minutes;
      };
      
      const porterStartMin = timeToMinutes(porterStart);
      const porterEndMin = timeToMinutes(porterEnd);
      const dayStartMin = timeToMinutes(dayStart);
      const dayEndMin = timeToMinutes(dayEnd);
      const nightStartMin = timeToMinutes(nightStart);
      const nightEndMin = timeToMinutes(nightEnd);
      
      // Handle night shifts that cross midnight
      const isNightShiftCrossingMidnight = nightStartMin > nightEndMin;
      const isPorterShiftCrossingMidnight = porterStartMin > porterEndMin;
      
      // Calculate overlap with day shift
      let dayOverlap = 0;
      if (porterStartMin <= dayEndMin && porterEndMin >= dayStartMin) {
        const overlapStart = Math.max(porterStartMin, dayStartMin);
        const overlapEnd = Math.min(porterEndMin, dayEndMin);
        dayOverlap = Math.max(0, overlapEnd - overlapStart);
      }
      
      // Calculate overlap with night shift
      let nightOverlap = 0;
      if (isNightShiftCrossingMidnight) {
        // Night shift crosses midnight (e.g., 20:00-08:00)
        if (isPorterShiftCrossingMidnight) {
          // Porter shift also crosses midnight
          const beforeMidnightOverlap = Math.max(0, Math.min(porterEndMin + 1440, nightEndMin + 1440) - Math.max(porterStartMin, nightStartMin));
          const afterMidnightOverlap = Math.max(0, Math.min(porterEndMin, nightEndMin) - Math.max(porterStartMin - 1440, nightStartMin - 1440));
          nightOverlap = beforeMidnightOverlap + afterMidnightOverlap;
        } else {
          // Porter shift doesn't cross midnight
          // Check overlap with night shift before midnight
          if (porterStartMin >= nightStartMin) {
            nightOverlap = porterEndMin - porterStartMin;
          }
          // Check overlap with night shift after midnight
          else if (porterEndMin <= nightEndMin) {
            nightOverlap = porterEndMin - porterStartMin;
          }
        }
      } else {
        // Night shift doesn't cross midnight
        if (porterStartMin <= nightEndMin && porterEndMin >= nightStartMin) {
          const overlapStart = Math.max(porterStartMin, nightStartMin);
          const overlapEnd = Math.min(porterEndMin, nightEndMin);
          nightOverlap = Math.max(0, overlapEnd - overlapStart);
        }
      }
      
      // Determine shift type based on which has more overlap
      if (dayOverlap > nightOverlap) {
        return 'day';
      } else if (nightOverlap > dayOverlap) {
        return 'night';
      } else {
        return 'unknown';
      }
    }
  },
  
  actions: {
    // Set sort method
    setSortBy(sortField) {
      this.sortBy = sortField;
    },
    
    // Set porter type filter
    setPorterTypeFilter(filterType) {
      // Validate filter type
      if (['all', 'shift', 'relief'].includes(filterType)) {
        this.porterTypeFilter = filterType;
      }
    },
    
    // Set shift time filter
    setShiftTimeFilter(filterType) {
      // Validate filter type
      if (['all', 'day', 'night'].includes(filterType)) {
        this.shiftTimeFilter = filterType;
      }
    },
    
    // Set search query
    setSearchQuery(query) {
      this.searchQuery = query;
    },
    
    // Toggle sort direction
    toggleSortDirection() {
      this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
    },
    
    // Reset to default A-Z sort
    resetToAZSort() {
      this.sortBy = 'firstName';
      this.sortDirection = 'asc';
    },
    
    // Fetch all supervisors
    async fetchSupervisors() {
      this.loading.supervisors = true;
      this.error = null;
      
      try {
        const data = await staffApi.getAll({ role: 'supervisor' });
        this.supervisors = data || [];
      } catch (error) {
        console.error('Error fetching supervisors:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load supervisors';
      } finally {
        this.loading.supervisors = false;
      }
    },
    
    // Fetch all porters
    async fetchPorters() {
      this.loading.porters = true;
      this.error = null;
      
      try {
        const data = await staffApi.getAll({ role: 'porter' });
        this.porters = data || [];
      } catch (error) {
        console.error('Error fetching porters:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load porters';
      } finally {
        this.loading.porters = false;
      }
    },
    
    // Add a new staff member
    async addStaff(staffData) {
      this.loading.staff = true;
      this.error = null;
      
      try {
        const data = await staffApi.create(staffData);
        
        if (data) {
          if (staffData.role === 'supervisor') {
            this.supervisors.push(data);
          } else {
            this.porters.push(data);
          }
        }
        
        return data;
      } catch (error) {
        console.error('Error adding staff member:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to add staff member';
        return null;
      } finally {
        this.loading.staff = false;
      }
    },
    
    // Update a staff member
    async updateStaff(id, updates) {
      this.loading.staff = true;
      this.error = null;
      
      try {
        const data = await staffApi.update(id, updates);
        
        if (data) {
          if (data.role === 'supervisor') {
            const index = this.supervisors.findIndex(s => s.id === id);
            if (index !== -1) {
              this.supervisors[index] = data;
            }
          } else {
            const index = this.porters.findIndex(p => p.id === id);
            if (index !== -1) {
              this.porters[index] = data;
            }
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating staff member:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update staff member';
        return false;
      } finally {
        this.loading.staff = false;
      }
    },
    
    // Delete a staff member
    async deleteStaff(id, role) {
      this.loading.staff = true;
      this.error = null;
      
      try {
        await staffApi.delete(id);
        
        // Remove from local state
        if (role === 'supervisor') {
          this.supervisors = this.supervisors.filter(s => s.id !== id);
        } else {
          this.porters = this.porters.filter(p => p.id !== id);
        }
        
        return true;
      } catch (error) {
        console.error('Error deleting staff member:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete staff member';
        return false;
      } finally {
        this.loading.staff = false;
      }
    },
    
    // Assign staff to a department
    async assignDepartment(staffId, departmentId) {
      this.loading.staff = true;
      this.error = null;
      
      try {
        const data = await staffApi.update(staffId, { department_id: departmentId });
        
        // Update local state
        if (data) {
          if (data.role === 'supervisor') {
            const index = this.supervisors.findIndex(s => s.id === staffId);
            if (index !== -1) {
              this.supervisors[index] = data;
            }
          } else {
            const index = this.porters.findIndex(p => p.id === staffId);
            if (index !== -1) {
              this.porters[index] = data;
            }
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error assigning department:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to assign department';
        return false;
      } finally {
        this.loading.staff = false;
      }
    },
    
    // Remove department assignment
    async removeDepartmentAssignment(staffId) {
      return this.assignDepartment(staffId, null);
    },
    
    // Fetch porter absences
    async fetchPorterAbsences(filters = {}) {
      this.loading.absences = true;
      this.error = null;
      
      try {
        const data = await absencesApi.getAll(filters);
        this.porterAbsences = data || [];
        return this.porterAbsences;
      } catch (error) {
        console.error('Error fetching porter absences:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load porter absences';
        return [];
      } finally {
        this.loading.absences = false;
      }
    },
    
    // Fetch absences for a specific porter
    async fetchPorterAbsencesById(porterId, filters = {}) {
      this.loading.absences = true;
      this.error = null;
      
      try {
        const data = await absencesApi.getByPorter(porterId, filters);
        
        // Replace absences for this porter in local state
        this.porterAbsences = this.porterAbsences.filter(absence => absence.porter_id !== porterId);
        if (data) {
          this.porterAbsences.push(...data);
        }
        
        return data;
      } catch (error) {
        console.error('Error fetching porter absences:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load porter absences';
        return [];
      } finally {
        this.loading.absences = false;
      }
    },
    
    // Add a new porter absence
    async addPorterAbsence(porterAbsence) {
      this.loading.absences = true;
      this.error = null;
      
      try {
        const data = await absencesApi.create(porterAbsence);
        
        if (data) {
          this.porterAbsences.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error adding porter absence:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to add porter absence';
        return null;
      } finally {
        this.loading.absences = false;
      }
    },
    
    // Update a porter absence
    async updatePorterAbsence(id, updates) {
      this.loading.absences = true;
      this.error = null;
      
      try {
        const data = await absencesApi.update(id, updates);
        
        if (data) {
          const index = this.porterAbsences.findIndex(absence => absence.id === id);
          if (index !== -1) {
            this.porterAbsences[index] = data;
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating porter absence:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update porter absence';
        return false;
      } finally {
        this.loading.absences = false;
      }
    },
    
    // Delete a porter absence
    async deletePorterAbsence(id) {
      this.loading.absences = true;
      this.error = null;
      
      try {
        await absencesApi.delete(id);
        
        // Remove from local state
        this.porterAbsences = this.porterAbsences.filter(absence => absence.id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting porter absence:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete porter absence';
        return false;
      } finally {
        this.loading.absences = false;
      }
    },
    
    // Initialize data
    async initialize() {
      await Promise.all([
        this.fetchSupervisors(),
        this.fetchPorters(),
        this.fetchPorterAbsences()
      ]);
    }
  }
});
