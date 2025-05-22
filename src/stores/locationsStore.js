import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useLocationsStore = defineStore('locations', {
  state: () => ({
    buildings: [],
    departments: [],
    loading: {
      buildings: false,
      departments: false
    },
    error: null
  }),
  
  getters: {
    buildingsWithDepartments: (state) => {
      return state.buildings.map(building => {
        const buildingDepartments = state.departments.filter(
          dept => dept.building_id === building.id
        );
        return {
          ...building,
          departments: buildingDepartments
        };
      });
    },
    
    frequentDepartments: (state) => {
      return state.departments.filter(dept => dept.is_frequent);
    }
  },
  
  actions: {
    // Building CRUD operations
    async fetchBuildings() {
      this.loading.buildings = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('buildings')
          .select('*')
          .order('name');
        
        if (error) throw error;
        
        this.buildings = data || [];
      } catch (error) {
        console.error('Error fetching buildings:', error);
        this.error = 'Failed to load buildings';
      } finally {
        this.loading.buildings = false;
      }
    },
    
    async addBuilding(building) {
      this.loading.buildings = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('buildings')
          .insert(building)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          this.buildings.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding building:', error);
        this.error = 'Failed to add building';
        return null;
      } finally {
        this.loading.buildings = false;
      }
    },
    
    async updateBuilding(id, updates) {
      this.loading.buildings = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('buildings')
          .update(updates)
          .eq('id', id)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const index = this.buildings.findIndex(b => b.id === id);
          if (index !== -1) {
            this.buildings[index] = data[0];
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating building:', error);
        this.error = 'Failed to update building';
        return false;
      } finally {
        this.loading.buildings = false;
      }
    },
    
    async deleteBuilding(id) {
      this.loading.buildings = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('buildings')
          .delete()
          .eq('id', id);
        
        if (error) throw error;
        
        // Remove from local state
        this.buildings = this.buildings.filter(b => b.id !== id);
        // Also remove associated departments
        this.departments = this.departments.filter(d => d.building_id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting building:', error);
        this.error = 'Failed to delete building';
        return false;
      } finally {
        this.loading.buildings = false;
      }
    },
    
    // Department CRUD operations
    async fetchDepartments() {
      this.loading.departments = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('departments')
          .select('*')
          .order('name');
        
        if (error) throw error;
        
        this.departments = data || [];
      } catch (error) {
        console.error('Error fetching departments:', error);
        this.error = 'Failed to load departments';
      } finally {
        this.loading.departments = false;
      }
    },
    
    async addDepartment(department) {
      this.loading.departments = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('departments')
          .insert(department)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          this.departments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding department:', error);
        this.error = 'Failed to add department';
        return null;
      } finally {
        this.loading.departments = false;
      }
    },
    
    async updateDepartment(id, updates) {
      this.loading.departments = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('departments')
          .update(updates)
          .eq('id', id)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const index = this.departments.findIndex(d => d.id === id);
          if (index !== -1) {
            this.departments[index] = data[0];
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating department:', error);
        this.error = 'Failed to update department';
        return false;
      } finally {
        this.loading.departments = false;
      }
    },
    
    async toggleFrequent(id) {
      const department = this.departments.find(d => d.id === id);
      if (!department) return false;
      
      return this.updateDepartment(id, { is_frequent: !department.is_frequent });
    },
    
    async deleteDepartment(id) {
      this.loading.departments = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('departments')
          .delete()
          .eq('id', id);
        
        if (error) throw error;
        
        // Remove from local state
        this.departments = this.departments.filter(d => d.id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting department:', error);
        this.error = 'Failed to delete department';
        return false;
      } finally {
        this.loading.departments = false;
      }
    },
    
    // Initialize data
    async initialize() {
      await Promise.all([
        this.fetchBuildings(),
        this.fetchDepartments()
      ]);
    }
  }
});
