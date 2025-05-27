import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}

export const useAreaCoverStore = defineStore('areaCover', {
  state: () => ({
    departments: [],
    areaAssignments: [],
    porterAssignments: [],
    loading: {
      departments: false,
      save: false
    },
    error: null
  }),
  
  getters: {
    // Get area assignments by department ID
    getAssignmentsByDepartmentId: (state) => (departmentId) => {
      return state.areaAssignments.filter(a => a.department_id === departmentId);
    },
    
    // Get area assignment by ID
    getAssignmentById: (state) => (id) => {
      return state.areaAssignments.find(a => a.id === id);
    },
    
    // Get area assignments by shift type
    getAssignmentsByShiftType: (state) => (shiftType) => {
      return state.areaAssignments.filter(a => a.shift_type === shiftType);
    },
    
    // Get porter assignments for a specific area assignment
    getPorterAssignmentsByAreaId: (state) => (areaAssignmentId) => {
      return state.porterAssignments.filter(
        pa => pa.default_area_cover_assignment_id === areaAssignmentId
      );
    },
    
    // Get sorted assignments by shift type (migrated from defaultAreaCoverStore)
    getSortedAssignmentsByType: (state) => (shiftType) => {
      const assignments = state.areaAssignments.filter(a => a.shift_type === shiftType);
      return [...assignments].sort((a, b) => {
        return a.department.name.localeCompare(b.department.name);
      });
    },
    
    // Check for coverage gaps (migrated from defaultAreaCoverStore)
    hasCoverageGap: (state) => (areaCoverId) => {
      try {
        const assignment = state.areaAssignments.find(a => a.id === areaCoverId);
        if (!assignment) return false;
        
        const porterAssignments = state.porterAssignments.filter(
          pa => pa.default_area_cover_assignment_id === areaCoverId
        );
        
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
    }
  },
  
  actions: {
    // Make sure assignments are loaded for a specific shift type
    async ensureAssignmentsLoaded(shiftType) {
      if (!this.areaAssignments || this.areaAssignments.length === 0) {
        await this.fetchAreaAssignments();
      }
      return this.getAssignmentsByShiftType(shiftType);
    },
    
    // Fetch assignments by shift type (for compatibility with components)
    async fetchAssignments(shiftType) {
      await this.fetchAreaAssignments();
      return this.getAssignmentsByShiftType(shiftType);
    },
    
    // For compatibility with DefaultAreaCoverSection component
    async addDepartment(departmentId, shiftType, startTime, endTime, color = '#4285F4') {
      return this.addAreaAssignment(departmentId, shiftType, startTime, endTime, color);
    },
    
    // For compatibility with DefaultAreaCoverSection component
    async updateDepartment(assignmentId, updates) {
      return this.updateAreaAssignment(assignmentId, updates);
    },
    
    // For compatibility with DefaultAreaCoverSection component
    async removeDepartment(assignmentId) {
      return this.deleteAreaAssignment(assignmentId);
    },
    
    // Fetch all area assignments (for settings/defaults)
    async fetchAreaAssignments() {
      this.loading.departments = true;
      this.error = null;
      
      try {
        // Fetch area cover assignments from default_area_cover_assignments
        const { data, error } = await supabase
          .from('default_area_cover_assignments')
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              building:building_id(id, name)
            )
          `)
          .order('department_id');
        
        if (error) throw error;
        
        this.areaAssignments = data || [];
        
        // Also fetch porter assignments for these area assignments
        if (data && data.length > 0) {
          const assignmentIds = data.map(a => a.id);
          
          const { data: porterData, error: porterError } = await supabase
            .from('default_area_cover_porter_assignments')
            .select(`
              *,
              porter:porter_id(id, first_name, last_name, role)
            `)
            .in('default_area_cover_assignment_id', assignmentIds);
          
          if (porterError) throw porterError;
          
          this.porterAssignments = porterData || [];
        } else {
          this.porterAssignments = [];
        }
        
        return this.areaAssignments;
      } catch (error) {
        console.error('Error fetching area assignments:', error);
        this.error = 'Failed to load area assignments';
        return [];
      } finally {
        this.loading.departments = false;
      }
    },
    
    // Add a new area assignment (for settings/defaults)
    async addAreaAssignment(departmentId, shiftType, startTime, endTime, color = '#4285F4') {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('default_area_cover_assignments')
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
          this.areaAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding area assignment:', error);
        this.error = 'Failed to add area assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Update an area assignment
    async updateAreaAssignment(assignmentId, updates) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('default_area_cover_assignments')
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
          // Update in local state
          const index = this.areaAssignments.findIndex(a => a.id === assignmentId);
          if (index !== -1) {
            this.areaAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating area assignment:', error);
        this.error = 'Failed to update area assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Delete an area assignment
    async deleteAreaAssignment(assignmentId) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('default_area_cover_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.areaAssignments = this.areaAssignments.filter(a => a.id !== assignmentId);
        
        // Also remove all associated porter assignments
        this.porterAssignments = this.porterAssignments.filter(
          pa => pa.default_area_cover_assignment_id !== assignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error deleting area assignment:', error);
        this.error = 'Failed to delete area assignment';
        return false;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Add a porter assignment to a default area cover
    async addPorterAssignment(areaCoverId, porterId, startTime, endTime) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('default_area_cover_porter_assignments')
          .insert({
            default_area_cover_assignment_id: areaCoverId,
            porter_id: porterId,
            start_time: startTime,
            end_time: endTime
          })
          .select(`
            *,
            porter:porter_id(id, first_name, last_name, role)
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
    
    // Update a porter assignment
    async updatePorterAssignment(porterAssignmentId, updates) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('default_area_cover_porter_assignments')
          .update(updates)
          .eq('id', porterAssignmentId)
          .select(`
            *,
            porter:porter_id(id, first_name, last_name, role)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update in local state
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
          .from('default_area_cover_porter_assignments')
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
    
    // Initialize store
    async initialize() {
      await this.fetchAreaAssignments();
    }
  }
});
