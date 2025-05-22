import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useAreaCoverStore = defineStore('areaCover', {
  state: () => ({
    dayAssignments: [],
    nightAssignments: [],
    loading: {
      day: false,
      night: false,
      save: false
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
            ),
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `)
          .eq('shift_type', shiftType);
        
        if (error) throw error;
        
        if (shiftType === 'day') {
          this.dayAssignments = data || [];
        } else {
          this.nightAssignments = data || [];
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
            ),
            porter:porter_id(
              id,
              first_name,
              last_name
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
        
        return true;
      } catch (error) {
        console.error('Error removing department from area cover:', error);
        this.error = 'Failed to remove department from area cover';
        return false;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Assign porter to department
    async assignPorter(assignmentId, porterId) {
      return this.updateDepartment(assignmentId, { porter_id: porterId });
    },
    
    // Remove porter assignment
    async removePorter(assignmentId) {
      return this.updateDepartment(assignmentId, { porter_id: null });
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
