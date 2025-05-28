import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useLocationsStore = defineStore('locations', {
  state: () => ({
    buildings: [],
    departments: [],
    loading: {
      buildings: false,
      departments: false,
      sorting: false
    },
    error: null
  }),
  
  getters: {
    sortedBuildings: (state) => {
      return [...state.buildings].sort((a, b) => a.sort_order - b.sort_order);
    },

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
    
    sortedBuildingsWithDepartments: (state) => {
      // Get buildings sorted by sort_order
      const sortedBuildings = [...state.buildings].sort((a, b) => a.sort_order - b.sort_order);
      
      return sortedBuildings.map(building => {
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
      return state.departments
        .filter(dept => dept.is_frequent)
        .sort((a, b) => a.sort_order - b.sort_order);
    },
    
    sortedDepartmentsByBuilding: (state) => (buildingId) => {
      return state.departments
        .filter(dept => dept.building_id === buildingId)
        .sort((a, b) => a.sort_order - b.sort_order);
    },
    
    sortedDepartmentsForDropdown: (state) => {
      // First, get all frequent departments sorted by sort_order
      const frequentDepts = state.departments
        .filter(dept => dept.is_frequent)
        .sort((a, b) => a.sort_order - b.sort_order);
      
      // Then, get non-frequent departments sorted by name
      const regularDepts = state.departments
        .filter(dept => !dept.is_frequent)
        .sort((a, b) => a.name.localeCompare(b.name));
      
      // Return frequent departments first, then regular departments
      return [...frequentDepts, ...regularDepts];
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
    
    // Sort order operations
    async updateBuildingSortOrder(buildingId, newSortOrder) {
      this.loading.sorting = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('buildings')
          .update({ sort_order: newSortOrder })
          .eq('id', buildingId);
        
        if (error) throw error;
        
        // Update in local state
        const index = this.buildings.findIndex(b => b.id === buildingId);
        if (index !== -1) {
          this.buildings[index].sort_order = newSortOrder;
        }
        
        return true;
      } catch (error) {
        console.error('Error updating building sort order:', error);
        this.error = 'Failed to update building order';
        return false;
      } finally {
        this.loading.sorting = false;
      }
    },
    
    async updateDepartmentSortOrder(departmentId, newSortOrder) {
      this.loading.sorting = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('departments')
          .update({ sort_order: newSortOrder })
          .eq('id', departmentId);
        
        if (error) throw error;
        
        // Update in local state
        const index = this.departments.findIndex(d => d.id === departmentId);
        if (index !== -1) {
          this.departments[index].sort_order = newSortOrder;
        }
        
        return true;
      } catch (error) {
        console.error('Error updating department sort order:', error);
        this.error = 'Failed to update department order';
        return false;
      } finally {
        this.loading.sorting = false;
      }
    },
    
    // Batch update multiple building sort orders at once (for drag and drop)
    async updateBuildingsSortOrder(buildingsWithNewOrder) {
      this.loading.sorting = true;
      this.error = null;
      
      try {
        // Find the original building objects to get all required fields
        const buildingsToUpdate = buildingsWithNewOrder.map(newOrderBuilding => {
          // Find the original building with all its fields
          const originalBuilding = this.buildings.find(b => b.id === newOrderBuilding.id);
          if (!originalBuilding) {
            console.warn(`Building with ID ${newOrderBuilding.id} not found in store`);
            return null;
          }
          
          // Return a new object with all original fields plus the new sort_order
          return {
            ...originalBuilding,
            sort_order: newOrderBuilding.sort_order
          };
        }).filter(Boolean); // Remove any null values
        
        if (buildingsToUpdate.length === 0) {
          console.warn('No valid buildings to update');
          return false;
        }
        
        // Execute the updates as a batch
        const { error } = await supabase
          .from('buildings')
          .upsert(buildingsToUpdate, { onConflict: 'id' });
        
        if (error) throw error;
        
        // Update local state for each building
        buildingsToUpdate.forEach(updatedBuilding => {
          const index = this.buildings.findIndex(b => b.id === updatedBuilding.id);
          if (index !== -1) {
            this.buildings[index].sort_order = updatedBuilding.sort_order;
          }
        });
        
        return true;
      } catch (error) {
        console.error('Error batch updating building sort orders:', error);
        this.error = 'Failed to update building orders';
        return false;
      } finally {
        this.loading.sorting = false;
      }
    },
    
    // Batch update multiple department sort orders at once (for drag and drop)
    async updateDepartmentsSortOrder(departmentsWithNewOrder) {
      this.loading.sorting = true;
      this.error = null;
      
      try {
        // Find the original department objects to get all required fields
        const departmentsToUpdate = departmentsWithNewOrder.map(newOrderDept => {
          // Find the original department with all its fields
          const originalDept = this.departments.find(d => d.id === newOrderDept.id);
          if (!originalDept) {
            console.warn(`Department with ID ${newOrderDept.id} not found in store`);
            return null;
          }
          
          // Return a new object with all original fields plus the new sort_order
          return {
            ...originalDept,
            sort_order: newOrderDept.sort_order
          };
        }).filter(Boolean); // Remove any null values
        
        if (departmentsToUpdate.length === 0) {
          console.warn('No valid departments to update');
          return false;
        }
        
        // Execute the updates as a batch
        const { error } = await supabase
          .from('departments')
          .upsert(departmentsToUpdate, { onConflict: 'id' });
        
        if (error) throw error;
        
        // Update local state for each department
        departmentsToUpdate.forEach(updatedDepartment => {
          const index = this.departments.findIndex(d => d.id === updatedDepartment.id);
          if (index !== -1) {
            this.departments[index].sort_order = updatedDepartment.sort_order;
          }
        });
        
        return true;
      } catch (error) {
        console.error('Error batch updating department sort orders:', error);
        this.error = 'Failed to update department orders';
        return false;
      } finally {
        this.loading.sorting = false;
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
