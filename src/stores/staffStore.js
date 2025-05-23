import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useStaffStore = defineStore('staff', {
  state: () => ({
    supervisors: [],
    porters: [],
    loading: {
      supervisors: false,
      porters: false,
      staff: false
    },
    sortBy: 'firstName', // 'firstName' or 'lastName'
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
    
    // Get sorted porters
    sortedPorters: (state) => {
      return [...state.porters].sort((a, b) => {
        if (state.sortBy === 'firstName') {
          return a.first_name.localeCompare(b.first_name);
        } else {
          return a.last_name.localeCompare(b.last_name);
        }
      });
    },
    
    // Get staff member by ID
    getStaffById: (state) => (id) => {
      return [...state.supervisors, ...state.porters].find(staff => staff.id === id);
    }
  },
  
  actions: {
    // Set sort method
    setSortBy(sortField) {
      this.sortBy = sortField;
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
    
    // Initialize data
    async initialize() {
      await Promise.all([
        this.fetchSupervisors(),
        this.fetchPorters()
      ]);
    }
  }
});
