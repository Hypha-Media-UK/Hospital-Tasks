import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

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
    }
  },
  
  actions: {
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
