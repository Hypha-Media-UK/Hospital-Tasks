import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useAreaCoverStore = defineStore('areaCover', {
  state: () => ({
    weekDayAssignments: [],
    weekNightAssignments: [],
    weekendDayAssignments: [],
    weekendNightAssignments: [],
    porterAssignments: [], // Porter assignments
    loading: {
      week_day: false,
      week_night: false,
      weekend_day: false,
      weekend_night: false,
      save: false,
      porters: false
    },
    error: null
  }),
  
  getters: {
    // Get week day assignments sorted by department name
    sortedWeekDayAssignments: (state) => {
      return [...state.weekDayAssignments].sort((a, b) => {
        return a.department.name.localeCompare(b.department.name);
      });
    },
    
    // Get week night assignments sorted by department name
    sortedWeekNightAssignments: (state) => {
      return [...state.weekNightAssignments].sort((a, b) => {
        return a.department.name.localeCompare(b.department.name);
      });
    },
    
    // Get weekend day assignments sorted by department name
    sortedWeekendDayAssignments: (state) => {
      return [...state.weekendDayAssignments].sort((a, b) => {
        return a.department.name.localeCompare(b.department.name);
      });
    },
    
    // Get weekend night assignments sorted by department name
    sortedWeekendNightAssignments: (state) => {
      return [...state.weekendNightAssignments].sort((a, b) => {
        return a.department.name.localeCompare(b.department.name);
      });
    },
    
    // Get assignments for any shift type
    getSortedAssignmentsByType: (state) => (shiftType) => {
      let assignments;
      switch(shiftType) {
        case 'week_day':
          assignments = state.weekDayAssignments;
          break;
        case 'week_night':
          assignments = state.weekNightAssignments;
          break;
        case 'weekend_day':
          assignments = state.weekendDayAssignments;
          break;
        case 'weekend_night':
          assignments = state.weekendNightAssignments;
          break;
        default:
          assignments = [];
      }
      
      return [...assignments].sort((a, b) => {
        return a.department.name.localeCompare(b.department.name);
      });
    },
    
    // Get assignment by ID
    getAssignmentById: (state) => (id) => {
      return [...state.weekDayAssignments, 
              ...state.weekNightAssignments, 
              ...state.weekendDayAssignments, 
              ...state.weekendNightAssignments].find(a => a.id === id);
    },
    
    // Get porter assignments for a specific area cover assignment
    getPorterAssignmentsByAreaId: (state) => (areaCoverId) => {
      return state.porterAssignments.filter(pa => pa.area_cover_assignment_id === areaCoverId);
    },
    
    // Check for coverage gaps in a specific area cover assignment
    hasCoverageGap: (state) => (areaCoverId) => {
      try {
        // Find the assignment directly from state arrays instead of using another getter
        const assignment = [...state.weekDayAssignments, 
                           ...state.weekNightAssignments, 
                           ...state.weekendDayAssignments, 
                           ...state.weekendNightAssignments].find(a => a.id === areaCoverId);
        
        if (!assignment) return false;
        
        // Directly access porter assignments from state instead of using another getter
        const porterAssignments = state.porterAssignments.filter(pa => pa.area_cover_assignment_id === areaCoverId);
        if (porterAssignments.length === 0) return true; // No porters means complete gap
        
        // Convert department times to minutes for easier comparison
        const departmentStart = timeToMinutes(assignment.start_time);
        const departmentEnd = timeToMinutes(assignment.end_time);
      
        // First check if any single porter covers the entire time period
        const fullCoverageExists = porterAssignments.some(assignment => {
          const porterStart = timeToMinutes(assignment.start_time);
          const porterEnd = timeToMinutes(assignment.end_time);
          return porterStart <= departmentStart && porterEnd >= departmentEnd;
        });
        
        // If at least one porter provides full coverage, there's no gap
        if (fullCoverageExists) {
          return false;
        }
        
        // Sort porter assignments by start time
        const sortedAssignments = [...porterAssignments].sort((a, b) => {
          return timeToMinutes(a.start_time) - timeToMinutes(b.start_time);
        });
        
        // Check for gap at the beginning
        if (timeToMinutes(sortedAssignments[0].start_time) > departmentStart) {
          return true;
        }
        
        // Check for gaps between porter assignments
        for (let i = 0; i < sortedAssignments.length - 1; i++) {
          const currentEnd = timeToMinutes(sortedAssignments[i].end_time);
          const nextStart = timeToMinutes(sortedAssignments[i + 1].start_time);
          
          if (nextStart > currentEnd) {
            return true;
          }
        }
        
        // Check for gap at the end
        const lastEnd = timeToMinutes(sortedAssignments[sortedAssignments.length - 1].end_time);
        if (lastEnd < departmentEnd) {
          return true;
        }
        
        return false;
      } catch (error) {
        console.error('Error in hasCoverageGap:', error);
        return false;
      }
    },
    
    // Removed legacy getters for day/night departments
  },
  
  actions: {
    // Fetch assignments by shift type
    async fetchAssignments(shiftType) {
      this.loading[shiftType] = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('area_cover_assignments')
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              building:building_id(id, name)
            )
          `)
          .eq('shift_type', shiftType);
        
        if (error) throw error;
        
        // Update the appropriate state array based on shift type
        switch(shiftType) {
          case 'week_day':
            this.weekDayAssignments = data || [];
            break;
          case 'week_night':
            this.weekNightAssignments = data || [];
            break;
          case 'weekend_day':
            this.weekendDayAssignments = data || [];
            break;
          case 'weekend_night':
            this.weekendNightAssignments = data || [];
            break;
          // Legacy support for old shift types has been removed
        }
        
        // Fetch porter assignments for these area covers
        if (data && data.length > 0) {
          const areaCoverIds = data.map(a => a.id);
          await this.fetchPorterAssignments(areaCoverIds);
        }
        
        return data;
      } catch (error) {
        console.error(`Error fetching ${shiftType} assignments:`, error);
        this.error = `Failed to load ${shiftType} shift assignments`;
        return [];
      } finally {
        this.loading[shiftType] = false;
      }
    },
    
    // Fetch porter assignments for specified area cover assignments
    async fetchPorterAssignments(areaCoverIds) {
      if (!areaCoverIds || areaCoverIds.length === 0) return [];
      
      this.loading.porters = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('area_cover_porter_assignments')
          .select(`
            *,
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `)
          .in('area_cover_assignment_id', areaCoverIds);
        
        if (error) throw error;
        
        this.porterAssignments = data || [];
        return data;
      } catch (error) {
        console.error('Error fetching porter assignments:', error);
        this.error = 'Failed to load porter assignments';
        return [];
      } finally {
        this.loading.porters = false;
      }
    },
    
    // Add department to shift
    async addDepartment(departmentId, shiftType, startTime = '08:00:00', endTime = '16:00:00', color = '#4285F4') {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('area_cover_assignments')
          .insert({
            department_id: departmentId,
            shift_type: shiftType,
            start_time: startTime,
            end_time: endTime,
            color: color
          })
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              building:building_id(id, name)
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the appropriate state array based on shift type
          switch(shiftType) {
            case 'week_day':
              this.weekDayAssignments.push(data[0]);
              break;
            case 'week_night':
              this.weekNightAssignments.push(data[0]);
              break;
            case 'weekend_day':
              this.weekendDayAssignments.push(data[0]);
              break;
            case 'weekend_night':
              this.weekendNightAssignments.push(data[0]);
              break;
            // Legacy support has been removed
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding department to area cover:', error);
        this.error = 'Failed to add department to area cover';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Update department settings
    async updateDepartment(assignmentId, updates) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('area_cover_assignments')
          .update(updates)
          .eq('id', assignmentId)
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              building:building_id(id, name)
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const updatedAssignment = data[0];
          const shiftType = updatedAssignment.shift_type;
          
          // Update the appropriate state array based on shift type
          switch(shiftType) {
            case 'week_day':
              {
                const index = this.weekDayAssignments.findIndex(a => a.id === assignmentId);
                if (index !== -1) {
                  this.weekDayAssignments[index] = updatedAssignment;
                }
              }
              break;
            case 'week_night':
              {
                const index = this.weekNightAssignments.findIndex(a => a.id === assignmentId);
                if (index !== -1) {
                  this.weekNightAssignments[index] = updatedAssignment;
                }
              }
              break;
            case 'weekend_day':
              {
                const index = this.weekendDayAssignments.findIndex(a => a.id === assignmentId);
                if (index !== -1) {
                  this.weekendDayAssignments[index] = updatedAssignment;
                }
              }
              break;
            case 'weekend_night':
              {
                const index = this.weekendNightAssignments.findIndex(a => a.id === assignmentId);
                if (index !== -1) {
                  this.weekendNightAssignments[index] = updatedAssignment;
                }
              }
              break;
            // Legacy support has been removed
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating area cover assignment:', error);
        this.error = 'Failed to update area cover assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Remove department from shift
    async removeDepartment(assignmentId) {
      this.loading.save = true;
      this.error = null;
      
      try {
        // Find the assignment among all assignments
        const assignment = [...this.weekDayAssignments, 
                           ...this.weekNightAssignments,
                           ...this.weekendDayAssignments,
                           ...this.weekendNightAssignments].find(a => a.id === assignmentId);
        
        if (!assignment) {
          throw new Error('Assignment not found');
        }
        
        const shiftType = assignment.shift_type;
        
        const { error } = await supabase
          .from('area_cover_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove from local state based on shift type
        switch(shiftType) {
          case 'week_day':
            this.weekDayAssignments = this.weekDayAssignments.filter(a => a.id !== assignmentId);
            break;
          case 'week_night':
            this.weekNightAssignments = this.weekNightAssignments.filter(a => a.id !== assignmentId);
            break;
          case 'weekend_day':
            this.weekendDayAssignments = this.weekendDayAssignments.filter(a => a.id !== assignmentId);
            break;
          case 'weekend_night':
            this.weekendNightAssignments = this.weekendNightAssignments.filter(a => a.id !== assignmentId);
            break;
          // Legacy support has been removed
        }
        
        // Also remove all porter assignments for this area cover
        this.porterAssignments = this.porterAssignments.filter(
          pa => pa.area_cover_assignment_id !== assignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing department from area cover:', error);
        this.error = 'Failed to remove department from area cover';
        return false;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Add porter assignment to an area cover
    async addPorterAssignment(areaCoverId, porterId, startTime, endTime) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('area_cover_porter_assignments')
          .insert({
            area_cover_assignment_id: areaCoverId,
            porter_id: porterId,
            start_time: startTime,
            end_time: endTime
          })
          .select(`
            *,
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          this.porterAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding porter assignment:', error);
        this.error = 'Failed to add porter assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Update porter assignment
    async updatePorterAssignment(porterAssignmentId, updates) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('area_cover_porter_assignments')
          .update(updates)
          .eq('id', porterAssignmentId)
          .select(`
            *,
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const index = this.porterAssignments.findIndex(pa => pa.id === porterAssignmentId);
          if (index !== -1) {
            this.porterAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating porter assignment:', error);
        this.error = 'Failed to update porter assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Remove porter assignment
    async removePorterAssignment(porterAssignmentId) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('area_cover_porter_assignments')
          .delete()
          .eq('id', porterAssignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.porterAssignments = this.porterAssignments.filter(pa => pa.id !== porterAssignmentId);
        
        return true;
      } catch (error) {
        console.error('Error removing porter assignment:', error);
        this.error = 'Failed to remove porter assignment';
        return false;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Initialize data
    async initialize() {
      console.log('Initializing area cover store...');
      
      // Fetch all assignment types in parallel
      const results = await Promise.all([
        this.fetchAssignments('week_day'),
        this.fetchAssignments('week_night'),
        this.fetchAssignments('weekend_day'),
        this.fetchAssignments('weekend_night')
      ]);
      
      console.log(`Area cover store initialized with:
        - week_day: ${this.weekDayAssignments.length} assignments
        - week_night: ${this.weekNightAssignments.length} assignments
        - weekend_day: ${this.weekendDayAssignments.length} assignments
        - weekend_night: ${this.weekendNightAssignments.length} assignments`);
      
      return results;
    },
    
    // Ensure specific shift type assignments are loaded
    async ensureAssignmentsLoaded(shiftType) {
      console.log(`Ensuring ${shiftType} assignments are loaded...`);
      
      // Check if assignments are already loaded
      let assignmentsArray;
      switch(shiftType) {
        case 'week_day':
          assignmentsArray = this.weekDayAssignments;
          break;
        case 'week_night':
          assignmentsArray = this.weekNightAssignments;
          break;
        case 'weekend_day':
          assignmentsArray = this.weekendDayAssignments;
          break;
        case 'weekend_night':
          assignmentsArray = this.weekendNightAssignments;
          break;
        default:
          console.warn(`Unknown shift type: ${shiftType}`);
          return [];
      }
      
      // If assignments are not loaded yet, fetch them
      if (!assignmentsArray.length) {
        console.log(`No ${shiftType} assignments found, fetching from database...`);
        return await this.fetchAssignments(shiftType);
      }
      
      console.log(`${assignmentsArray.length} ${shiftType} assignments already loaded`);
      return assignmentsArray;
    }
  }
});

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}
