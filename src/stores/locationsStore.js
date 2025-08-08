import { defineStore } from 'pinia';
import { buildingsApi, departmentsApi, ApiError, apiRequest } from '../services/api';

export const useLocationsStore = defineStore('locations', {
  state: () => ({
    buildings: [],
    departments: [],
    departmentTaskAssignments: [],
    loading: {
      buildings: false,
      departments: false,
      sorting: false,
      departmentTaskAssignments: false
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
      // First, get a map of building IDs to their sort order
      const buildingSortMap = new Map();
      [...state.buildings].sort((a, b) => a.sort_order - b.sort_order)
        .forEach((building, index) => {
          buildingSortMap.set(building.id, index);
        });
      
      // Get all frequent departments
      const frequentDepts = state.departments.filter(dept => dept.is_frequent);
      
      // Sort frequent departments by building order first, then by department sort_order
      return frequentDepts.sort((a, b) => {
        // Get building sort order (or a high number if building not found)
        const buildingOrderA = buildingSortMap.get(a.building_id) ?? 999;
        const buildingOrderB = buildingSortMap.get(b.building_id) ?? 999;
        
        // First sort by building order
        if (buildingOrderA !== buildingOrderB) {
          return buildingOrderA - buildingOrderB;
        }
        
        // If same building, sort by department sort_order
        return a.sort_order - b.sort_order;
      });
    },
    
    sortedDepartmentsByBuilding: (state) => (buildingId) => {
      return state.departments
        .filter(dept => dept.building_id === buildingId)
        .sort((a, b) => a.sort_order - b.sort_order);
    },
    
    sortedDepartmentsForDropdown: (state) => {
      // First, get a map of building IDs to their sort order
      const buildingSortMap = new Map();
      [...state.buildings].sort((a, b) => a.sort_order - b.sort_order)
        .forEach((building, index) => {
          buildingSortMap.set(building.id, index);
        });
      
      // First, get all frequent departments sorted by building order then by sort_order
      const frequentDepts = state.departments
        .filter(dept => dept.is_frequent)
        .sort((a, b) => {
          // Get building sort order (or a high number if building not found)
          const buildingOrderA = buildingSortMap.get(a.building_id) ?? 999;
          const buildingOrderB = buildingSortMap.get(b.building_id) ?? 999;
          
          // First sort by building order
          if (buildingOrderA !== buildingOrderB) {
            return buildingOrderA - buildingOrderB;
          }
          
          // If same building, sort by department sort_order
          return a.sort_order - b.sort_order;
        });
      
      // Then, get non-frequent departments sorted by name
      const regularDepts = state.departments
        .filter(dept => !dept.is_frequent)
        .sort((a, b) => a.name.localeCompare(b.name));
      
      // Return frequent departments first, then regular departments
      return [...frequentDepts, ...regularDepts];
    },
    
    // Get buildings that require porter service
    porterServicedBuildings: (state) => {
      return state.buildings
        .filter(building => building.porter_serviced)
        .sort((a, b) => a.sort_order - b.sort_order);
    },
    
    // Get task type and item assignment for a department
    getDepartmentTaskAssignment: (state) => (departmentId) => {
      return state.departmentTaskAssignments.find(
        assignment => assignment.department_id === departmentId
      ) || null;
    }
  },
  
  actions: {
    // Building CRUD operations
    async fetchBuildings() {
      this.loading.buildings = true;
      this.error = null;
      
      try {
        const data = await buildingsApi.getAll();
        this.buildings = data || [];
      } catch (error) {
        console.error('Error fetching buildings:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load buildings';
      } finally {
        this.loading.buildings = false;
      }
    },
    
    async addBuilding(building) {
      this.loading.buildings = true;
      this.error = null;
      
      try {
        const data = await buildingsApi.create(building);
        
        if (data) {
          this.buildings.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error adding building:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to add building';
        return null;
      } finally {
        this.loading.buildings = false;
      }
    },
    
    async updateBuilding(id, updates) {
      this.loading.buildings = true;
      this.error = null;
      
      try {
        const data = await buildingsApi.update(id, updates);
        
        if (data) {
          const index = this.buildings.findIndex(b => b.id === id);
          if (index !== -1) {
            this.buildings[index] = data;
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating building:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update building';
        return false;
      } finally {
        this.loading.buildings = false;
      }
    },
    
    async deleteBuilding(id) {
      this.loading.buildings = true;
      this.error = null;
      
      try {
        await buildingsApi.delete(id);
        
        // Remove from local state
        this.buildings = this.buildings.filter(b => b.id !== id);
        // Also remove associated departments
        this.departments = this.departments.filter(d => d.building_id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting building:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete building';
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
        const data = await departmentsApi.getAll();
        this.departments = data || [];
      } catch (error) {
        console.error('Error fetching departments:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load departments';
      } finally {
        this.loading.departments = false;
      }
    },
    
    async addDepartment(department) {
      this.loading.departments = true;
      this.error = null;
      
      try {
        const data = await departmentsApi.create(department);
        
        if (data) {
          this.departments.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error adding department:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to add department';
        return null;
      } finally {
        this.loading.departments = false;
      }
    },
    
    async updateDepartment(id, updates) {
      this.loading.departments = true;
      this.error = null;
      
      try {
        const data = await departmentsApi.update(id, updates);
        
        if (data) {
          const index = this.departments.findIndex(d => d.id === id);
          if (index !== -1) {
            this.departments[index] = data;
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating department:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update department';
        return false;
      } finally {
        this.loading.departments = false;
      }
    },
    
    async toggleFrequent(id) {
      this.loading.departments = true;
      this.error = null;
      
      try {
        const data = await departmentsApi.toggleFrequent(id);
        
        if (data) {
          const index = this.departments.findIndex(d => d.id === id);
          if (index !== -1) {
            this.departments[index] = data;
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error toggling department frequent status:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to toggle frequent status';
        return false;
      } finally {
        this.loading.departments = false;
      }
    },
    
    async deleteDepartment(id) {
      this.loading.departments = true;
      this.error = null;
      
      try {
        await departmentsApi.delete(id);
        
        // Remove from local state
        this.departments = this.departments.filter(d => d.id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting department:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete department';
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
        await buildingsApi.update(buildingId, { sort_order: newSortOrder });
        
        // Update in local state
        const index = this.buildings.findIndex(b => b.id === buildingId);
        if (index !== -1) {
          this.buildings[index].sort_order = newSortOrder;
        }
        
        return true;
      } catch (error) {
        console.error('Error updating building sort order:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update building order';
        return false;
      } finally {
        this.loading.sorting = false;
      }
    },
    
    async updateDepartmentSortOrder(departmentId, newSortOrder) {
      this.loading.sorting = true;
      this.error = null;
      
      try {
        await departmentsApi.update(departmentId, { sort_order: newSortOrder });
        
        // Update in local state
        const index = this.departments.findIndex(d => d.id === departmentId);
        if (index !== -1) {
          this.departments[index].sort_order = newSortOrder;
        }
        
        return true;
      } catch (error) {
        console.error('Error updating department sort order:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update department order';
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
        // Update each building individually
        const updatePromises = buildingsWithNewOrder.map(building => 
          buildingsApi.update(building.id, { sort_order: building.sort_order })
        );
        
        await Promise.all(updatePromises);
        
        // Update local state for each building
        buildingsWithNewOrder.forEach(updatedBuilding => {
          const index = this.buildings.findIndex(b => b.id === updatedBuilding.id);
          if (index !== -1) {
            this.buildings[index].sort_order = updatedBuilding.sort_order;
          }
        });
        
        return true;
      } catch (error) {
        console.error('Error batch updating building sort orders:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update building orders';
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
        // Update each department individually
        const updatePromises = departmentsWithNewOrder.map(department => 
          departmentsApi.update(department.id, { sort_order: department.sort_order })
        );
        
        await Promise.all(updatePromises);
        
        // Update local state for each department
        departmentsWithNewOrder.forEach(updatedDepartment => {
          const index = this.departments.findIndex(d => d.id === updatedDepartment.id);
          if (index !== -1) {
            this.departments[index].sort_order = updatedDepartment.sort_order;
          }
        });
        
        return true;
      } catch (error) {
        console.error('Error batch updating department sort orders:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update department orders';
        return false;
      } finally {
        this.loading.sorting = false;
      }
    },
    
    // Department Task Assignment operations
    async fetchDepartmentTaskAssignments() {
      this.loading.departmentTaskAssignments = true;
      this.error = null;
      
      try {
        const data = await apiRequest('/departments/task-assignments/all');
        this.departmentTaskAssignments = Array.isArray(data) ? data : [];
      } catch (error) {
        console.error('Error fetching department task assignments:', error);
        this.error = 'Failed to load department task assignments';
        this.departmentTaskAssignments = [];
      } finally {
        this.loading.departmentTaskAssignments = false;
      }
    },
    
    async updateDepartmentTaskAssignment(departmentId, taskTypeId, taskItemId) {
      this.loading.departmentTaskAssignments = true;
      this.error = null;
      
      try {
        const data = await apiRequest(`/departments/${departmentId}/task-assignments`, {
          method: 'POST',
          body: JSON.stringify({
            task_type_id: taskTypeId,
            task_item_id: taskItemId
          })
        });
        
        // Update local state
        const existingIndex = this.departmentTaskAssignments.findIndex(
          assignment => assignment.department_id === departmentId
        );
        
        if (existingIndex !== -1) {
          this.departmentTaskAssignments[existingIndex] = data;
        } else {
          this.departmentTaskAssignments.push(data);
        }
        
        return true;
      } catch (error) {
        console.error('Error updating department task assignment:', error);
        this.error = 'Failed to update department task assignment';
        return false;
      } finally {
        this.loading.departmentTaskAssignments = false;
      }
    },
    
    async removeDepartmentTaskAssignment(departmentId) {
      this.loading.departmentTaskAssignments = true;
      this.error = null;
      
      try {
        // Find the assignment to delete
        const assignment = this.departmentTaskAssignments.find(
          assignment => assignment.department_id === departmentId
        );
        
        if (!assignment) {
          return true; // Already removed
        }
        
        await apiRequest(`/departments/task-assignments/${assignment.id}`, {
          method: 'DELETE'
        });
        
        // Remove from local state
        this.departmentTaskAssignments = this.departmentTaskAssignments.filter(
          assignment => assignment.department_id !== departmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing department task assignment:', error);
        this.error = 'Failed to remove department task assignment';
        return false;
      } finally {
        this.loading.departmentTaskAssignments = false;
      }
    },
    
    // Initialize data
    async initialize() {
      await Promise.all([
        this.fetchBuildings(),
        this.fetchDepartments(),
        this.fetchDepartmentTaskAssignments()
      ]);
    }
  }
});
