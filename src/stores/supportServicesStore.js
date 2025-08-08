import { defineStore } from 'pinia';
import { supportServicesApi, shiftsApi, ApiError } from '../services/api';

export const useSupportServicesStore = defineStore('supportServices', {
  state: () => ({
    supportServices: [],
    serviceAssignments: [],
    defaultServiceAssignments: [],
    loading: {
      services: false,
      assignments: false,
      creating: false,
      updating: false,
      deleting: false
    },
    error: null
  }),
  
  getters: {
    // Get active support services
    activeServices: (state) => {
      return state.supportServices.filter(service => service.is_active);
    },
    
    // Get inactive support services
    inactiveServices: (state) => {
      return state.supportServices.filter(service => !service.is_active);
    },
    
    // Get services sorted by name
    sortedServices: (state) => {
      return [...state.supportServices].sort((a, b) => a.name.localeCompare(b.name));
    },
    
    // Get active services sorted by name
    sortedActiveServices: (state) => {
      return state.supportServices
        .filter(service => service.is_active)
        .sort((a, b) => a.name.localeCompare(b.name));
    },
    
    // Get service by ID
    getServiceById: (state) => (id) => {
      return state.supportServices.find(service => service.id === id);
    },
    
    // Get assignments for a specific service
    getAssignmentsByService: (state) => (serviceId) => {
      return state.serviceAssignments.filter(assignment => assignment.service_id === serviceId);
    },
    
    // Get assignments for a specific service and shift type
    getAssignmentsByServiceAndShift: (state) => (serviceId, shiftType) => {
      return state.serviceAssignments.filter(assignment => 
        assignment.service_id === serviceId && assignment.shift_type === shiftType
      );
    },
    
    // Get sorted assignments by shift type (for compatibility with area cover store)
    getSortedAssignmentsByType: (state) => (shiftType) => {
      const assignments = state.defaultServiceAssignments.filter(assignment => assignment.shift_type === shiftType);
      return [...assignments].sort((a, b) => {
        return a.support_services?.name?.localeCompare(b.support_services?.name) || 0;
      });
    },

    // Get default assignments for a specific shift type
    getDefaultAssignmentsByType: (state) => (shiftType) => {
      return state.defaultServiceAssignments.filter(assignment => assignment.shift_type === shiftType);
    },

    // Get all default assignments
    allDefaultAssignments: (state) => {
      return state.defaultServiceAssignments;
    },

    // Alias for services property (for compatibility)
    services: (state) => {
      return state.supportServices;
    },

    // Get porter assignments for a specific service (for compatibility with SupportServiceItem)
    getPorterAssignmentsByServiceId: (state) => (serviceId) => {
      // For default service assignments, we need to find the assignment and return its porter assignments
      const assignment = state.defaultServiceAssignments.find(a => a.id === serviceId);
      return assignment?.default_service_cover_porter_assignments || [];
    },

    // Get service coverage gaps (for compatibility with components)
    getServiceCoverageGaps: (state) => (serviceId) => {
      try {
        const assignment = state.defaultServiceAssignments.find(a => a.id === serviceId);
        if (!assignment) {
          return { hasGap: false, gaps: [] };
        }

        const porterAssignments = assignment.default_service_cover_porter_assignments || [];
        if (porterAssignments.length === 0) {
          // No porters assigned - entire period is a gap
          return {
            hasGap: true,
            gaps: [{
              startTime: assignment.start_time,
              endTime: assignment.end_time,
              type: 'no_coverage',
              missingPorters: assignment.minimum_porters || 1
            }]
          };
        }

        // For now, simplified gap detection - assume no gaps if porters are assigned
        return { hasGap: false, gaps: [] };
      } catch (error) {
        console.error('Error in getServiceCoverageGaps:', error);
        return { hasGap: false, gaps: [] };
      }
    }
  },
  
  actions: {
    // Support Services CRUD operations
    async fetchSupportServices(includeInactive = true) {
      this.loading.services = true;
      this.error = null;
      
      try {
        const filters = includeInactive ? {} : { is_active: true };
        const data = await supportServicesApi.getAll(filters);
        this.supportServices = data || [];
      } catch (error) {
        console.error('Error fetching support services:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load support services';
      } finally {
        this.loading.services = false;
      }
    },
    
    async fetchSupportService(id) {
      this.loading.services = true;
      this.error = null;
      
      try {
        const data = await supportServicesApi.getById(id);
        
        if (data) {
          // Update or add to support services
          const index = this.supportServices.findIndex(s => s.id === id);
          if (index !== -1) {
            this.supportServices[index] = data;
          } else {
            this.supportServices.push(data);
          }
        }
        
        return data;
      } catch (error) {
        console.error('Error fetching support service:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load support service';
        return null;
      } finally {
        this.loading.services = false;
      }
    },
    
    async createSupportService(serviceData) {
      this.loading.creating = true;
      this.error = null;
      
      try {
        const data = await supportServicesApi.create(serviceData);
        
        if (data) {
          this.supportServices.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error creating support service:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to create support service';
        return null;
      } finally {
        this.loading.creating = false;
      }
    },
    
    async updateSupportService(id, updates) {
      this.loading.updating = true;
      this.error = null;
      
      try {
        const data = await supportServicesApi.update(id, updates);
        
        if (data) {
          const index = this.supportServices.findIndex(s => s.id === id);
          if (index !== -1) {
            this.supportServices[index] = data;
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error updating support service:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update support service';
        return false;
      } finally {
        this.loading.updating = false;
      }
    },
    
    async toggleServiceActive(id) {
      this.loading.updating = true;
      this.error = null;
      
      try {
        const data = await supportServicesApi.toggleActive(id);
        
        if (data) {
          const index = this.supportServices.findIndex(s => s.id === id);
          if (index !== -1) {
            this.supportServices[index] = data;
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error toggling service active status:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to toggle active status';
        return false;
      } finally {
        this.loading.updating = false;
      }
    },
    
    async deleteSupportService(id) {
      this.loading.deleting = true;
      this.error = null;
      
      try {
        await supportServicesApi.delete(id);
        
        // Remove from local state
        this.supportServices = this.supportServices.filter(s => s.id !== id);
        // Also remove associated assignments
        this.serviceAssignments = this.serviceAssignments.filter(a => a.service_id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting support service:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete support service';
        return false;
      } finally {
        this.loading.deleting = false;
      }
    },
    
    // Service Assignments operations
    async fetchServiceAssignments(serviceId, shiftType = null) {
      this.loading.assignments = true;
      this.error = null;
      
      try {
        const data = await supportServicesApi.getAssignments(serviceId, shiftType);
        
        // Replace assignments for this service
        this.serviceAssignments = this.serviceAssignments.filter(a => a.service_id !== serviceId);
        if (data) {
          this.serviceAssignments.push(...data);
        }
        
        return data;
      } catch (error) {
        console.error('Error fetching service assignments:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load service assignments';
        return [];
      } finally {
        this.loading.assignments = false;
      }
    },
    
    async createServiceAssignment(serviceId, assignmentData) {
      this.loading.creating = true;
      this.error = null;
      
      try {
        const data = await supportServicesApi.createAssignment(serviceId, assignmentData);
        
        if (data) {
          this.serviceAssignments.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error creating service assignment:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to create service assignment';
        return null;
      } finally {
        this.loading.creating = false;
      }
    },
    
    // Utility methods
    async refreshService(id) {
      return this.fetchSupportService(id);
    },
    
    async refreshServiceAssignments(serviceId) {
      return this.fetchServiceAssignments(serviceId);
    },
    
    // Get service statistics
    getServiceStats: () => (state) => {
      return {
        total: state.supportServices.length,
        active: state.supportServices.filter(s => s.is_active).length,
        inactive: state.supportServices.filter(s => !s.is_active).length
      };
    },
    
    // Alias for compatibility
    async fetchServices(includeInactive = true) {
      return this.fetchSupportServices(includeInactive);
    },
    
    // Default Service Cover Assignments operations
    async fetchDefaultServiceAssignments(shiftType = null) {
      this.loading.assignments = true;
      this.error = null;
      
      try {
        const data = await supportServicesApi.getDefaultAssignments(shiftType);
        
        if (shiftType) {
          // Replace assignments for this shift type
          this.defaultServiceAssignments = this.defaultServiceAssignments.filter(a => a.shift_type !== shiftType);
          if (data) {
            this.defaultServiceAssignments.push(...data);
          }
        } else {
          // Replace all assignments
          this.defaultServiceAssignments = data || [];
        }
        
        return data;
      } catch (error) {
        console.error('Error fetching default service assignments:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load default service assignments';
        return [];
      } finally {
        this.loading.assignments = false;
      }
    },

    async createDefaultServiceAssignment(assignmentData) {
      this.loading.creating = true;
      this.error = null;
      
      try {
        const data = await supportServicesApi.createDefaultAssignment(assignmentData);
        
        if (data) {
          this.defaultServiceAssignments.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error creating default service assignment:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to create default service assignment';
        return null;
      } finally {
        this.loading.creating = false;
      }
    },

    async updateDefaultServiceAssignment(id, updates) {
      this.loading.updating = true;
      this.error = null;
      
      try {
        const data = await supportServicesApi.updateDefaultAssignment(id, updates);
        
        if (data) {
          const index = this.defaultServiceAssignments.findIndex(a => a.id === id);
          if (index !== -1) {
            this.defaultServiceAssignments[index] = data;
          }
        }
        
        return data;
      } catch (error) {
        console.error('Error updating default service assignment:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update default service assignment';
        return null;
      } finally {
        this.loading.updating = false;
      }
    },

    async deleteDefaultServiceAssignment(id) {
      this.loading.deleting = true;
      this.error = null;
      
      try {
        await supportServicesApi.deleteDefaultAssignment(id);
        
        // Remove from local state
        this.defaultServiceAssignments = this.defaultServiceAssignments.filter(a => a.id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting default service assignment:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete default service assignment';
        return false;
      } finally {
        this.loading.deleting = false;
      }
    },

    // Convenience methods for adding/removing service assignments
    async addServiceAssignment(serviceId, shiftType, startTime, endTime, color) {
      return this.createDefaultServiceAssignment({
        service_id: serviceId,
        shift_type: shiftType,
        start_time: startTime,
        end_time: endTime,
        color: color
      });
    },

    async updateServiceAssignment(id, updates) {
      return this.updateDefaultServiceAssignment(id, updates);
    },

    async deleteServiceAssignment(id) {
      return this.deleteDefaultServiceAssignment(id);
    },

    // Initialize data
    async initialize() {
      await Promise.all([
        this.fetchSupportServices(true), // Include inactive services
        this.fetchDefaultServiceAssignments() // Load all default assignments
      ]);
    },
    
    // Ensure assignments are loaded for a specific shift type
    async ensureAssignmentsLoaded(shiftType) {
      // Check if we already have assignments for this shift type
      const existingAssignments = this.defaultServiceAssignments.filter(a => a.shift_type === shiftType);
      
      if (existingAssignments.length === 0) {
        // Load assignments for this shift type
        await this.fetchDefaultServiceAssignments(shiftType);
      }
      
      return this.getDefaultAssignmentsByType(shiftType);
    },

    // Setup shift support services from defaults
    async setupShiftSupportServicesFromDefaults(shiftId, shiftType) {
      this.loading.creating = true;
      this.error = null;
      
      try {
        console.log(`Setting up support services from defaults for shift ${shiftId}, type ${shiftType}`);
        const result = await shiftsApi.initializeSupportServices(shiftId);
        
        if (result && result.assignments) {
          console.log(`Successfully initialized ${result.assignments.length} support service assignments`);
          return true;
        }
        
        return false;
      } catch (error) {
        console.error('Error setting up shift support services from defaults:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to initialize support services from defaults';
        return false;
      } finally {
        this.loading.creating = false;
      }
    }
  }
});
