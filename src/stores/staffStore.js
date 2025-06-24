import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

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
          return `${porter.availability_pattern} (${porter.contracted_hours_start.substring(0, 5)}-${porter.contracted_hours_end.substring(0, 5)})`;
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
        const { data, error } = await supabase
          .from('staff')
          .select('*, department:department_id(id, name, building_id)')
          .eq('role', 'supervisor')
          .order('first_name');
        
        if (error) throw error;
        
        this.supervisors = data || [];
      } catch (error) {
        console.error('Error fetching supervisors:', error);
        this.error = 'Failed to load supervisors';
      } finally {
        this.loading.supervisors = false;
      }
    },
    
    // Fetch all porters
    async fetchPorters() {
      this.loading.porters = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('staff')
          .select('*, department:department_id(id, name, building_id)')
          .eq('role', 'porter')
          .order('first_name');
        
        if (error) throw error;
        
        this.porters = data || [];
      } catch (error) {
        console.error('Error fetching porters:', error);
        this.error = 'Failed to load porters';
      } finally {
        this.loading.porters = false;
      }
    },
    
    // Add a new staff member
    async addStaff(staffData) {
      this.loading.staff = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('staff')
          .insert(staffData)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          if (staffData.role === 'supervisor') {
            this.supervisors.push(data[0]);
          } else {
            this.porters.push(data[0]);
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding staff member:', error);
        this.error = 'Failed to add staff member';
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
        const { data, error } = await supabase
          .from('staff')
          .update(updates)
          .eq('id', id)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const updatedStaff = data[0];
          
          if (updatedStaff.role === 'supervisor') {
            const index = this.supervisors.findIndex(s => s.id === id);
            if (index !== -1) {
              this.supervisors[index] = updatedStaff;
            }
          } else {
            const index = this.porters.findIndex(p => p.id === id);
            if (index !== -1) {
              this.porters[index] = updatedStaff;
            }
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating staff member:', error);
        this.error = 'Failed to update staff member';
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
        const { error } = await supabase
          .from('staff')
          .delete()
          .eq('id', id);
        
        if (error) throw error;
        
        // Remove from local state
        if (role === 'supervisor') {
          this.supervisors = this.supervisors.filter(s => s.id !== id);
        } else {
          this.porters = this.porters.filter(p => p.id !== id);
        }
        
        return true;
      } catch (error) {
        console.error('Error deleting staff member:', error);
        this.error = 'Failed to delete staff member';
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
        // First, update the staff record with the department ID
        const { data, error } = await supabase
          .from('staff')
          .update({ department_id: departmentId })
          .eq('id', staffId)
          .select('*, department:department_id(id, name, building_id)');
        
        if (error) throw error;
        
        // Update local state
        if (data && data.length > 0) {
          const updatedStaff = data[0];
          
          if (updatedStaff.role === 'supervisor') {
            const index = this.supervisors.findIndex(s => s.id === staffId);
            if (index !== -1) {
              this.supervisors[index] = updatedStaff;
            }
          } else {
            const index = this.porters.findIndex(p => p.id === staffId);
            if (index !== -1) {
              this.porters[index] = updatedStaff;
            }
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error assigning department:', error);
        this.error = 'Failed to assign department';
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
    async fetchPorterAbsences() {
      this.loading.absences = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('porter_absences')
          .select('*, porter:porter_id(id, first_name, last_name)')
          .order('start_date');
        
        if (error) throw error;
        
        this.porterAbsences = data || [];
        return this.porterAbsences;
      } catch (error) {
        console.error('Error fetching porter absences:', error);
        this.error = 'Failed to load porter absences';
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
        const { data, error } = await supabase
          .from('porter_absences')
          .insert(porterAbsence)
          .select('*, porter:porter_id(id, first_name, last_name)');
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          this.porterAbsences.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding porter absence:', error);
        this.error = 'Failed to add porter absence';
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
        const { data, error } = await supabase
          .from('porter_absences')
          .update(updates)
          .eq('id', id)
          .select('*, porter:porter_id(id, first_name, last_name)');
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const index = this.porterAbsences.findIndex(a => a.id === id);
          if (index !== -1) {
            this.porterAbsences[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating porter absence:', error);
        this.error = 'Failed to update porter absence';
        return null;
      } finally {
        this.loading.absences = false;
      }
    },
    
    // Delete a porter absence
    async deletePorterAbsence(id) {
      this.loading.absences = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('porter_absences')
          .delete()
          .eq('id', id);
        
        if (error) throw error;
        
        // Remove from local state
        this.porterAbsences = this.porterAbsences.filter(a => a.id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting porter absence:', error);
        this.error = 'Failed to delete porter absence';
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
