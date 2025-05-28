import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}

export const useSupportServicesStore = defineStore('supportServices', {
  state: () => ({
    services: [],
    serviceAssignments: [],
    porterAssignments: [],
    loading: {
      services: false,
      save: false
    },
    error: null
  }),
  
  getters: {
    // Get sorted list of services by name
    sortedServices: (state) => {
      return [...state.services].sort((a, b) => a.name.localeCompare(b.name));
    },
    
    // Get all active support services
    activeSupportServices: (state) => {
      return state.services.filter(service => service.is_active !== false);
    },
    
    // Get service assignment by ID
    getAssignmentById: (state) => (id) => {
      return state.serviceAssignments.find(a => a.id === id);
    },
    
    // Get service assignments by shift type
    getAssignmentsByShiftType: (state) => (shiftType) => {
      return state.serviceAssignments.filter(a => a.shift_type === shiftType);
    },
    
    // Get porter assignments for a specific service assignment
    getPorterAssignmentsByServiceId: (state) => (serviceAssignmentId) => {
      return state.porterAssignments.filter(pa => pa.support_service_assignment_id === serviceAssignmentId ||
                                                 pa.default_service_cover_assignment_id === serviceAssignmentId);
    },
    
    // Get sorted assignments by shift type (migrated from defaultServiceCoverStore)
    getSortedAssignmentsByType: (state) => (shiftType) => {
      const assignments = state.serviceAssignments.filter(a => a.shift_type === shiftType);
      return [...assignments].sort((a, b) => {
        return a.service.name.localeCompare(b.service.name);
      });
    },
    
    // Check for coverage gaps in a specific service assignment (migrated from defaultServiceCoverStore)
    hasCoverageGap: (state) => (serviceId) => {
      try {
        const assignment = state.serviceAssignments.find(a => a.id === serviceId);
        if (!assignment) return false;
        
        const porterAssignments = state.porterAssignments.filter(
          pa => pa.default_service_cover_assignment_id === serviceId ||
                pa.support_service_assignment_id === serviceId
        );
        
        if (porterAssignments.length === 0) return true; // No porters means complete gap
        
        // Convert service times to minutes for easier comparison
        const serviceStart = timeToMinutes(assignment.start_time);
        const serviceEnd = timeToMinutes(assignment.end_time);
      
        // First check if any single porter covers the entire time period
        const fullCoverageExists = porterAssignments.some(assignment => {
          const porterStart = timeToMinutes(assignment.start_time);
          const porterEnd = timeToMinutes(assignment.end_time);
          return porterStart <= serviceStart && porterEnd >= serviceEnd;
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
        if (timeToMinutes(sortedAssignments[0].start_time) > serviceStart) {
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
        if (lastEnd < serviceEnd) {
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
      if (!this.serviceAssignments || this.serviceAssignments.length === 0) {
        await this.fetchServiceAssignments();
      }
      return this.getAssignmentsByShiftType(shiftType);
    },
    
    // Load all service assignments for all shift types
    async loadAllServiceAssignments() {
      return await this.fetchServiceAssignments();
    },
    
    // Fetch all support services
    async fetchServices() {
      this.loading.services = true;
      
      try {
        const { data, error } = await supabase
          .from('support_services')
          .select('*')
          .order('name');
        
        if (error) throw error;
        
        this.services = data || [];
      } catch (error) {
        console.error('Error fetching support services:', error);
        this.error = error.message;
      } finally {
        this.loading.services = false;
      }
    },
    
    // Add a new support service
    async addService(name, description) {
      this.loading.save = true;
      
      try {
        const { data, error } = await supabase
          .from('support_services')
          .insert({
            name,
            description
          })
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add the new service to the state
          this.services.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding support service:', error);
        this.error = error.message;
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Update an existing support service
    async updateService(id, updates) {
      this.loading.save = true;
      
      try {
        const { data, error } = await supabase
          .from('support_services')
          .update(updates)
          .eq('id', id)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the service in the state
          const index = this.services.findIndex(s => s.id === id);
          if (index !== -1) {
            this.services[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating support service:', error);
        this.error = error.message;
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Delete a support service
    async deleteService(id) {
      this.loading.save = true;
      
      try {
        const { error } = await supabase
          .from('support_services')
          .delete()
          .eq('id', id);
        
        if (error) throw error;
        
        // Remove the service from the state
        this.services = this.services.filter(s => s.id !== id);
        
        return true;
      } catch (error) {
        console.error('Error deleting support service:', error);
        this.error = error.message;
        return false;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Fetch service assignments
    async fetchServiceAssignments() {
      this.loading.services = true;
      
      try {
        const { data, error } = await supabase
          .from('default_service_cover_assignments')
          .select(`
            *,
            service:service_id(id, name, description)
          `)
          .order('service_id');
        
        if (error) throw error;
        
        this.serviceAssignments = data || [];
        
        // Also fetch porter assignments
        if (data && data.length > 0) {
          const assignmentIds = data.map(a => a.id);
          
          const { data: porterData, error: porterError } = await supabase
            .from('default_service_cover_porter_assignments')
            .select(`
              *,
              porter:porter_id(id, first_name, last_name, role)
            `)
            .in('default_service_cover_assignment_id', assignmentIds);
          
          if (porterError) throw porterError;
          
          this.porterAssignments = porterData || [];
        } else {
          this.porterAssignments = [];
        }
        
        return this.serviceAssignments;
      } catch (error) {
        console.error('Error fetching service assignments:', error);
        this.error = error.message;
        return [];
      } finally {
        this.loading.services = false;
      }
    },
    
    // Add a service assignment (for default settings)
    async addServiceAssignment(serviceId, shiftType, startTime, endTime, color = '#4285F4') {
      this.loading.save = true;
      
      try {
        const { data, error } = await supabase
          .from('default_service_cover_assignments')
          .insert({
            service_id: serviceId,
            shift_type: shiftType,
            start_time: startTime,
            end_time: endTime,
            color: color
          })
          .select(`
            *,
            service:service_id(id, name, description)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add the assignment to the state
          this.serviceAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding service assignment:', error);
        this.error = error.message;
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Update a service assignment
    async updateServiceAssignment(assignmentId, updates) {
      this.loading.save = true;
      
      try {
        const { data, error } = await supabase
          .from('default_service_cover_assignments')
          .update(updates)
          .eq('id', assignmentId)
          .select(`
            *,
            service:service_id(id, name, description)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the assignment in the state
          const index = this.serviceAssignments.findIndex(a => a.id === assignmentId);
          if (index !== -1) {
            this.serviceAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating service assignment:', error);
        this.error = error.message;
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Delete a service assignment
    async deleteServiceAssignment(assignmentId) {
      this.loading.save = true;
      
      try {
        // First, delete any porter assignments related to this service assignment
        console.log('Deleting porter assignments for service assignment ID:', assignmentId);
        const { error: porterError } = await supabase
          .from('default_service_cover_porter_assignments')
          .delete()
          .eq('default_service_cover_assignment_id', assignmentId);
        
        if (porterError) {
          console.error('Error deleting related porter assignments:', porterError);
          throw porterError;
        }
        
        // Now delete the service assignment itself
        console.log('Deleting service assignment with ID:', assignmentId);
        const { error } = await supabase
          .from('default_service_cover_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove the assignment from the state
        this.serviceAssignments = this.serviceAssignments.filter(a => a.id !== assignmentId);
        
        // Also remove associated porter assignments from state
        this.porterAssignments = this.porterAssignments.filter(
          pa => pa.default_service_cover_assignment_id !== assignmentId
        );
        
        console.log('Service assignment successfully deleted');
        return true;
      } catch (error) {
        console.error('Error deleting service assignment:', error);
        this.error = error.message;
        return false;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Add a porter to a service assignment
    async addPorterToServiceAssignment(assignmentId, porterId, startTime, endTime) {
      this.loading = true;
      
      try {
        const { data, error } = await supabase
          .from('default_service_cover_porter_assignments')
          .insert({
            default_service_cover_assignment_id: assignmentId,
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
          // Add the porter assignment to the state
          this.porterAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding porter to service assignment:', error);
        this.error = error.message;
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Update a porter assignment
    async updatePorterAssignment(porterAssignmentId, updates) {
      this.loading.save = true;
      
      try {
        const { data, error } = await supabase
          .from('default_service_cover_porter_assignments')
          .update(updates)
          .eq('id', porterAssignmentId)
          .select(`
            *,
            porter:porter_id(id, first_name, last_name, role)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the porter assignment in the state
          const index = this.porterAssignments.findIndex(pa => pa.id === porterAssignmentId);
          if (index !== -1) {
            this.porterAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating porter assignment:', error);
        this.error = error.message;
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Remove a porter from a service assignment
    async removePorterAssignment(porterAssignmentId) {
      this.loading = true;
      
      try {
        const { error } = await supabase
          .from('default_service_cover_porter_assignments')
          .delete()
          .eq('id', porterAssignmentId);
        
        if (error) throw error;
        
        // Remove the porter assignment from the state
        this.porterAssignments = this.porterAssignments.filter(pa => pa.id !== porterAssignmentId);
        
        return true;
      } catch (error) {
        console.error('Error removing porter assignment:', error);
        this.error = error.message;
        return false;
      } finally {
        this.loading = false;
      }
    },
    
    // Initialize store
    async initialize() {
      await this.fetchServices();
      await this.fetchServiceAssignments();
    }
  }
});
