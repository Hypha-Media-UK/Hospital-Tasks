import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useSupportServicesStore = defineStore('supportServices', {
  state: () => ({
    supportServices: [],
    serviceAssignments: {
      week_day: [],
      week_night: [],
      weekend_day: [],
      weekend_night: []
    },
    servicePorterAssignments: {},
    loading: false,
    loadingAssignments: false,
    error: null
  }),
  
  actions: {
    // Initialize store data
    async initialize() {
      await this.loadSupportServices();
      await this.loadAllServiceAssignments();
    },
    
    // Load all support services from Supabase
    async loadSupportServices() {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_services')
          .select('*')
          .order('name');
        
        if (error) throw error;
        
        this.supportServices = data || [];
        return data;
      } catch (error) {
        console.error('Error loading support services:', error);
        this.error = 'Failed to load support services';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Load support service assignments for a specific shift type
    async loadServiceAssignments(shiftType) {
      if (!['week_day', 'week_night', 'weekend_day', 'weekend_night'].includes(shiftType)) {
        console.error('Invalid shift type:', shiftType);
        return [];
      }
      
      this.loadingAssignments = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_service_assignments')
          .select(`
            *,
            service:service_id(id, name, description),
            porter_assignments:support_service_porter_assignments(
              id,
              porter_id,
              start_time,
              end_time,
              porter:porter_id(id, first_name, last_name)
            )
          `)
          .eq('shift_type', shiftType);
        
        if (error) throw error;
        
        // Format the data
        const formattedData = data.map(assignment => ({
          id: assignment.id,
          service: assignment.service,
          start_time: assignment.start_time,
          end_time: assignment.end_time,
          color: assignment.color,
          shift_type: assignment.shift_type,
          porter_assignments: assignment.porter_assignments || []
        }));
        
        // Store in the appropriate state property
        this.serviceAssignments[shiftType] = formattedData;
        
        return formattedData;
      } catch (error) {
        console.error(`Error loading ${shiftType} service assignments:`, error);
        this.error = `Failed to load ${shiftType} service assignments`;
        return [];
      } finally {
        this.loadingAssignments = false;
      }
    },
    
    // Load all service assignments for all shift types
    async loadAllServiceAssignments() {
      const shiftTypes = ['week_day', 'week_night', 'weekend_day', 'weekend_night'];
      
      for (const type of shiftTypes) {
        await this.loadServiceAssignments(type);
      }
      
      return this.serviceAssignments;
    },
    
    // Add a new support service
    async addSupportService(service) {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_services')
          .insert({
            name: service.name,
            description: service.description || null,
            is_active: true
          })
          .select();
        
        if (error) throw error;
        
        // Add the new service to the local array
        if (data && data.length > 0) {
          this.supportServices.push(data[0]);
          // Sort the array by name
          this.supportServices.sort((a, b) => a.name.localeCompare(b.name));
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error adding support service:', error);
        this.error = 'Failed to add support service';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Update an existing support service
    async updateSupportService(service) {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_services')
          .update({
            name: service.name,
            description: service.description,
            is_active: service.is_active,
            updated_at: new Date().toISOString()
          })
          .eq('id', service.id)
          .select();
        
        if (error) throw error;
        
        // Update the service in the local array
        if (data && data.length > 0) {
          const index = this.supportServices.findIndex(s => s.id === service.id);
          if (index !== -1) {
            this.supportServices[index] = data[0];
          }
          // Sort the array by name
          this.supportServices.sort((a, b) => a.name.localeCompare(b.name));
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error updating support service:', error);
        this.error = 'Failed to update support service';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Remove a support service
    async removeSupportService(serviceId) {
      this.loading = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('support_services')
          .delete()
          .eq('id', serviceId);
        
        if (error) throw error;
        
        // Remove the service from the local array
        this.supportServices = this.supportServices.filter(s => s.id !== serviceId);
        
        return true;
      } catch (error) {
        console.error('Error removing support service:', error);
        this.error = 'Failed to remove support service';
        return false;
      } finally {
        this.loading = false;
      }
    },
    
    // Add a new service assignment (for default settings)
    async addServiceAssignment(serviceId, shiftType, startTime, endTime, color) {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_service_assignments')
          .insert({
            service_id: serviceId,
            shift_type: shiftType,
            start_time: startTime,
            end_time: endTime,
            color: color || '#4285F4'
          })
          .select(`
            *,
            service:service_id(id, name, description)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Format the data to match our state structure
          const formattedAssignment = {
            id: data[0].id,
            service: data[0].service,
            start_time: data[0].start_time,
            end_time: data[0].end_time,
            color: data[0].color,
            shift_type: data[0].shift_type,
            porter_assignments: []
          };
          
          // Add to the appropriate shift type array
          this.serviceAssignments[shiftType].push(formattedAssignment);
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error adding service assignment:', error);
        this.error = 'Failed to add service assignment';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Update a service assignment
    async updateServiceAssignment(assignmentId, updates) {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_service_assignments')
          .update(updates)
          .eq('id', assignmentId)
          .select(`
            *,
            service:service_id(id, name, description)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Find and update the assignment in our state
          const shiftType = data[0].shift_type;
          const index = this.serviceAssignments[shiftType].findIndex(a => a.id === assignmentId);
          
          if (index !== -1) {
            // Preserve porter_assignments when updating
            const porterAssignments = this.serviceAssignments[shiftType][index].porter_assignments;
            
            // Update with new data
            this.serviceAssignments[shiftType][index] = {
              id: data[0].id,
              service: data[0].service,
              start_time: data[0].start_time,
              end_time: data[0].end_time,
              color: data[0].color,
              shift_type: data[0].shift_type,
              porter_assignments: porterAssignments
            };
          }
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error updating service assignment:', error);
        this.error = 'Failed to update service assignment';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Remove a service assignment
    async removeServiceAssignment(assignmentId) {
      this.loading = true;
      this.error = null;
      
      try {
        // First, get the assignment to know which shift type it belongs to
        const { data: assignmentData } = await supabase
          .from('support_service_assignments')
          .select('shift_type')
          .eq('id', assignmentId)
          .single();
        
        const shiftType = assignmentData?.shift_type;
        
        if (!shiftType) {
          throw new Error('Assignment not found');
        }
        
        // Now delete the assignment
        const { error } = await supabase
          .from('support_service_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove from our state
        if (shiftType) {
          this.serviceAssignments[shiftType] = this.serviceAssignments[shiftType].filter(
            a => a.id !== assignmentId
          );
        }
        
        return true;
      } catch (error) {
        console.error('Error removing service assignment:', error);
        this.error = 'Failed to remove service assignment';
        return false;
      } finally {
        this.loading = false;
      }
    },
    
    // Add a porter to a service assignment
    async addPorterToServiceAssignment(assignmentId, porterId, startTime, endTime) {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_service_porter_assignments')
          .insert({
            support_service_assignment_id: assignmentId,
            porter_id: porterId,
            start_time: startTime,
            end_time: endTime
          })
          .select(`
            *,
            porter:porter_id(id, first_name, last_name)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Find the assignment in our state to add the porter to it
          for (const shiftType in this.serviceAssignments) {
            const assignmentIndex = this.serviceAssignments[shiftType].findIndex(
              a => a.id === assignmentId
            );
            
            if (assignmentIndex !== -1) {
              // Add the porter assignment
              this.serviceAssignments[shiftType][assignmentIndex].porter_assignments.push(data[0]);
              break;
            }
          }
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error adding porter to service assignment:', error);
        this.error = 'Failed to add porter to service';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Update a porter assignment
    async updatePorterAssignment(porterAssignmentId, updates) {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_service_porter_assignments')
          .update(updates)
          .eq('id', porterAssignmentId)
          .select(`
            *,
            porter:porter_id(id, first_name, last_name)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Find and update the porter assignment in our state
          const assignmentId = data[0].support_service_assignment_id;
          
          // Iterate through shift types to find the assignment
          for (const shiftType in this.serviceAssignments) {
            const assignmentIndex = this.serviceAssignments[shiftType].findIndex(
              a => a.id === assignmentId
            );
            
            if (assignmentIndex !== -1) {
              // Find and update the porter assignment
              const porterAssignments = this.serviceAssignments[shiftType][assignmentIndex].porter_assignments;
              const porterIndex = porterAssignments.findIndex(p => p.id === porterAssignmentId);
              
              if (porterIndex !== -1) {
                porterAssignments[porterIndex] = data[0];
              }
              
              break;
            }
          }
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error updating porter assignment:', error);
        this.error = 'Failed to update porter assignment';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Remove a porter from a service assignment
    async removePorterAssignment(porterAssignmentId) {
      this.loading = true;
      this.error = null;
      
      try {
        // First, get the assignment details
        const { data: assignmentData } = await supabase
          .from('support_service_porter_assignments')
          .select('support_service_assignment_id')
          .eq('id', porterAssignmentId)
          .single();
        
        const serviceAssignmentId = assignmentData?.support_service_assignment_id;
        
        if (!serviceAssignmentId) {
          throw new Error('Porter assignment not found');
        }
        
        // Delete the porter assignment
        const { error } = await supabase
          .from('support_service_porter_assignments')
          .delete()
          .eq('id', porterAssignmentId);
        
        if (error) throw error;
        
        // Update our state
        for (const shiftType in this.serviceAssignments) {
          const assignmentIndex = this.serviceAssignments[shiftType].findIndex(
            a => a.id === serviceAssignmentId
          );
          
          if (assignmentIndex !== -1) {
            // Filter out the removed porter assignment
            this.serviceAssignments[shiftType][assignmentIndex].porter_assignments = 
              this.serviceAssignments[shiftType][assignmentIndex].porter_assignments.filter(
                p => p.id !== porterAssignmentId
              );
            break;
          }
        }
        
        return true;
      } catch (error) {
        console.error('Error removing porter assignment:', error);
        this.error = 'Failed to remove porter assignment';
        return false;
      } finally {
        this.loading = false;
      }
    },
    
    // Clear error
    clearError() {
      this.error = null;
    },
    
    // Check if a service assignment has coverage gaps
    hasCoverageGap(assignmentId) {
      try {
        // Find the assignment across all shift types
        let assignment = null;
        let porterAssignments = [];
        
        // Search in all shift types
        for (const shiftType in this.serviceAssignments) {
          assignment = this.serviceAssignments[shiftType].find(a => a.id === assignmentId);
          if (assignment) {
            porterAssignments = assignment.porter_assignments || [];
            break;
          }
        }
        
        if (!assignment) return false;
        if (porterAssignments.length === 0) return true; // No porters means complete gap
        
        // Helper function to convert time string (HH:MM:SS) to minutes
        const timeToMinutes = (timeStr) => {
          if (!timeStr) return 0;
          const [hours, minutes] = timeStr.split(':').map(Number);
          return (hours * 60) + minutes;
        };
        
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
  }
});
