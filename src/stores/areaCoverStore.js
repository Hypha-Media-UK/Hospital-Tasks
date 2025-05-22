import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useAreaCoverStore = defineStore('areaCover', {
  state: () => ({
    dayAssignments: [],
    nightAssignments: [],
    porterAssignments: [], // New state for porter assignments
    loading: {
      day: false,
      night: false,
      save: false,
      porters: false
    },
    error: null
  }),
  
  getters: {
    // Get day assignments sorted by department name
    sortedDayAssignments: (state) => {
      return [...state.dayAssignments].sort((a, b) => {
        return a.department.name.localeCompare(b.department.name);
      });
    },
    
    // Get night assignments sorted by department name
    sortedNightAssignments: (state) => {
      return [...state.nightAssignments].sort((a, b) => {
        return a.department.name.localeCompare(b.department.name);
      });
    },
    
    // Get assignment by ID
    getAssignmentById: (state) => (id) => {
      return [...state.dayAssignments, ...state.nightAssignments].find(a => a.id === id);
    },
    
    // Get porter assignments for a specific area cover assignment
    getPorterAssignmentsByAreaId: (state) => (areaCoverId) => {
      return state.porterAssignments.filter(pa => pa.area_cover_assignment_id === areaCoverId);
    },
    
    // Check for coverage gaps in a specific area cover assignment
    hasCoverageGap: (state) => (areaCoverId) => {
      const assignment = state.getAssignmentById(areaCoverId);
      if (!assignment) return false;
      
      const porterAssignments = state.getPorterAssignmentsByAreaId(areaCoverId);
      if (porterAssignments.length === 0) return true; // No porters means complete gap
      
      // Convert department times to minutes for easier comparison
      const departmentStart = timeToMinutes(assignment.start_time);
      const departmentEnd = timeToMinutes(assignment.end_time);
      
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
    },
    
    // Get departments that can be added to day shift (not already added)
    availableDayDepartments: (state, getters, rootState, rootGetters) => {
      const locationsStore = rootGetters['locations/buildingsWithDepartments'] ? 
        { buildingsWithDepartments: rootGetters['locations/buildingsWithDepartments'] } : 
        { buildingsWithDepartments: [] };
      
      // Create a flat list of all departments
      const allDepartments = [];
      locationsStore.buildingsWithDepartments.forEach(building => {
        building.departments.forEach(dept => {
          allDepartments.push({
            ...dept,
            building_name: building.name
          });
        });
      });
      
      // Filter out departments that are already assigned to day shift
      const assignedDeptIds = state.dayAssignments.map(a => a.department_id);
      return allDepartments.filter(dept => !assignedDeptIds.includes(dept.id));
    },
    
    // Get departments that can be added to night shift (not already added)
    availableNightDepartments: (state, getters, rootState, rootGetters) => {
      const locationsStore = rootGetters['locations/buildingsWithDepartments'] ? 
        { buildingsWithDepartments: rootGetters['locations/buildingsWithDepartments'] } : 
        { buildingsWithDepartments: [] };
      
      // Create a flat list of all departments
      const allDepartments = [];
      locationsStore.buildingsWithDepartments.forEach(building => {
        building.departments.forEach(dept => {
          allDepartments.push({
            ...dept,
            building_name: building.name
          });
        });
      });
      
      // Filter out departments that are already assigned to night shift
      const assignedDeptIds = state.nightAssignments.map(a => a.department_id);
      return allDepartments.filter(dept => !assignedDeptIds.includes(dept.id));
    }
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
        
        if (shiftType === 'day') {
          this.dayAssignments = data || [];
        } else {
          this.nightAssignments = data || [];
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
          if (shiftType === 'day') {
            this.dayAssignments.push(data[0]);
          } else {
            this.nightAssignments.push(data[0]);
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
          
          if (shiftType === 'day') {
            const index = this.dayAssignments.findIndex(a => a.id === assignmentId);
            if (index !== -1) {
              this.dayAssignments[index] = updatedAssignment;
            }
          } else {
            const index = this.nightAssignments.findIndex(a => a.id === assignmentId);
            if (index !== -1) {
              this.nightAssignments[index] = updatedAssignment;
            }
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
        // Find the assignment to determine its shift type
        const assignment = this.getAssignmentById(assignmentId);
        if (!assignment) {
          throw new Error('Assignment not found');
        }
        
        const shiftType = assignment.shift_type;
        
        const { error } = await supabase
          .from('area_cover_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        if (shiftType === 'day') {
          this.dayAssignments = this.dayAssignments.filter(a => a.id !== assignmentId);
        } else {
          this.nightAssignments = this.nightAssignments.filter(a => a.id !== assignmentId);
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
      await Promise.all([
        this.fetchAssignments('day'),
        this.fetchAssignments('night')
      ]);
    }
  }
});

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}
