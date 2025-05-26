import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useDefaultServiceCoverStore = defineStore('defaultServiceCover', {
  state: () => ({
    serviceAssignments: {
      week_day: [],
      week_night: [],
      weekend_day: [],
      weekend_night: []
    },
    porterAssignments: [], // Porter assignments for all services and shift types
    loading: {
      week_day: false,
      week_night: false,
      weekend_day: false,
      weekend_night: false,
      save: false,
      porters: false
    },
    error: null
  }),
  
  getters: {
    // Get sorted assignments for a specific shift type
    getSortedAssignmentsByType: (state) => (shiftType) => {
      if (!state.serviceAssignments[shiftType]) return [];
      
      return [...state.serviceAssignments[shiftType]].sort((a, b) => {
        return a.service.name.localeCompare(b.service.name);
      });
    },
    
    // Get a service assignment by ID
    getAssignmentById: (state) => (id) => {
      // Search through all shift types
      for (const shiftType in state.serviceAssignments) {
        const found = state.serviceAssignments[shiftType].find(a => a.id === id);
        if (found) return found;
      }
      return null;
    },
    
    // Get porter assignments for a specific service assignment
    getPorterAssignmentsByServiceId: (state) => (serviceId) => {
      return state.porterAssignments.filter(
        pa => pa.default_service_cover_assignment_id === serviceId
      );
    },
    
    // Check for coverage gaps in a specific service assignment
    hasCoverageGap: (state) => (serviceId) => {
      try {
        // Find the assignment
        let assignment = null;
        
        // Search through all shift types
        for (const shiftType in state.serviceAssignments) {
          assignment = state.serviceAssignments[shiftType].find(a => a.id === serviceId);
          if (assignment) break;
        }
        
        if (!assignment) return false;
        
        // Get porter assignments for this service
        const porterAssignments = state.porterAssignments.filter(
          pa => pa.default_service_cover_assignment_id === serviceId
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
    // Fetch service assignments for a specific shift type
    async fetchAssignments(shiftType) {
      if (!['week_day', 'week_night', 'weekend_day', 'weekend_night'].includes(shiftType)) {
        console.error('Invalid shift type:', shiftType);
        return [];
      }
      
      this.loading[shiftType] = true;
      this.error = null;
      
      try {
        console.log(`Fetching default service cover assignments for shift type: ${shiftType}`);
        
        const { data, error } = await supabase
          .from('default_service_cover_assignments')
          .select(`
            *,
            service:service_id(id, name, description)
          `)
          .eq('shift_type', shiftType);
        
        if (error) throw error;
        
        console.log(`Found ${data?.length || 0} default service assignments for ${shiftType}`);
        
        // Format the data
        const formattedData = data.map(assignment => ({
          id: assignment.id,
          service: assignment.service,
          service_id: assignment.service_id,
          start_time: assignment.start_time,
          end_time: assignment.end_time,
          color: assignment.color,
          shift_type: assignment.shift_type,
          created_at: assignment.created_at,
          updated_at: assignment.updated_at
        }));
        
        // Store in the appropriate state property
        this.serviceAssignments[shiftType] = formattedData;
        
        // Fetch porter assignments for these services
        if (data && data.length > 0) {
          const serviceIds = data.map(a => a.id);
          await this.fetchPorterAssignments(serviceIds);
        }
        
        return formattedData;
      } catch (error) {
        console.error(`Error loading ${shiftType} default service assignments:`, error);
        this.error = `Failed to load ${shiftType} default service assignments`;
        return [];
      } finally {
        this.loading[shiftType] = false;
      }
    },
    
    // Fetch porter assignments for specified service assignments
    async fetchPorterAssignments(serviceIds) {
      if (!serviceIds || serviceIds.length === 0) return [];
      
      this.loading.porters = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('default_service_cover_porter_assignments')
          .select(`
            *,
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `)
          .in('default_service_cover_assignment_id', serviceIds);
        
        if (error) throw error;
        
        // Add new porter assignments to our state
        // We use this approach to avoid duplicates while keeping assignments for other shift types
        const newAssignmentIds = data.map(a => a.id);
        this.porterAssignments = [
          ...this.porterAssignments.filter(pa => !newAssignmentIds.includes(pa.id)),
          ...data
        ];
        
        return data;
      } catch (error) {
        console.error('Error fetching default service porter assignments:', error);
        this.error = 'Failed to load porter assignments';
        return [];
      } finally {
        this.loading.porters = false;
      }
    },
    
    // Add a service to shift type defaults
    async addService(serviceId, shiftType, startTime = '08:00:00', endTime = '16:00:00', color = '#4285F4') {
      this.loading.save = true;
      this.error = null;
      
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
          // Format the data
          const formattedAssignment = {
            id: data[0].id,
            service: data[0].service,
            service_id: data[0].service_id,
            start_time: data[0].start_time,
            end_time: data[0].end_time,
            color: data[0].color,
            shift_type: data[0].shift_type,
            created_at: data[0].created_at,
            updated_at: data[0].updated_at
          };
          
          // Add to the appropriate shift type array
          this.serviceAssignments[shiftType].push(formattedAssignment);
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error adding service to default service cover:', error);
        this.error = 'Failed to add service to default service cover';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Update a service assignment
    async updateService(assignmentId, updates) {
      this.loading.save = true;
      this.error = null;
      
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
          // Find and update the assignment in our state
          const shiftType = data[0].shift_type;
          const index = this.serviceAssignments[shiftType].findIndex(a => a.id === assignmentId);
          
          if (index !== -1) {
            // Format the data
            const formattedAssignment = {
              id: data[0].id,
              service: data[0].service,
              service_id: data[0].service_id,
              start_time: data[0].start_time,
              end_time: data[0].end_time,
              color: data[0].color,
              shift_type: data[0].shift_type,
              created_at: data[0].created_at,
              updated_at: data[0].updated_at
            };
            
            this.serviceAssignments[shiftType][index] = formattedAssignment;
          }
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error updating default service assignment:', error);
        this.error = 'Failed to update service assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Remove a service from shift type defaults
    async removeService(assignmentId) {
      this.loading.save = true;
      this.error = null;
      
      try {
        // First, get the assignment to know which shift type it belongs to
        let shiftType = null;
        let assignment = null;
        
        // Find the assignment in our state
        for (const type in this.serviceAssignments) {
          assignment = this.serviceAssignments[type].find(a => a.id === assignmentId);
          if (assignment) {
            shiftType = type;
            break;
          }
        }
        
        if (!shiftType) {
          // Try to get it from the database if not found in state
          const { data: assignmentData } = await supabase
            .from('default_service_cover_assignments')
            .select('shift_type')
            .eq('id', assignmentId)
            .single();
          
          shiftType = assignmentData?.shift_type;
        }
        
        if (!shiftType) {
          throw new Error('Assignment not found');
        }
        
        // Now delete the assignment
        const { error } = await supabase
          .from('default_service_cover_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove from our state
        if (shiftType) {
          this.serviceAssignments[shiftType] = this.serviceAssignments[shiftType].filter(
            a => a.id !== assignmentId
          );
        }
        
        // Also remove all porter assignments for this service
        this.porterAssignments = this.porterAssignments.filter(
          pa => pa.default_service_cover_assignment_id !== assignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing service from default service cover:', error);
        this.error = 'Failed to remove service assignment';
        return false;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Add a porter to a service assignment
    async addPorterToService(serviceId, porterId, startTime, endTime) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('default_service_cover_porter_assignments')
          .insert({
            default_service_cover_assignment_id: serviceId,
            porter_id: porterId,
            start_time: startTime,
            end_time: endTime
          })
          .select(`
            *,
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add the new porter assignment to our state
          this.porterAssignments.push(data[0]);
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error adding porter to default service assignment:', error);
        this.error = 'Failed to add porter to service';
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
          .from('default_service_cover_porter_assignments')
          .update(updates)
          .eq('id', porterAssignmentId)
          .select(`
            *,
            porter:porter_id(
              id,
              first_name,
              last_name
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the porter assignment in our state
          const index = this.porterAssignments.findIndex(pa => pa.id === porterAssignmentId);
          if (index !== -1) {
            this.porterAssignments[index] = data[0];
          }
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error updating default service porter assignment:', error);
        this.error = 'Failed to update porter assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Remove a porter from a service assignment
    async removePorterAssignment(porterAssignmentId) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('default_service_cover_porter_assignments')
          .delete()
          .eq('id', porterAssignmentId);
        
        if (error) throw error;
        
        // Remove from our state
        this.porterAssignments = this.porterAssignments.filter(pa => pa.id !== porterAssignmentId);
        
        return true;
      } catch (error) {
        console.error('Error removing porter from default service assignment:', error);
        this.error = 'Failed to remove porter assignment';
        return false;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Load all service assignments for all shift types
    async loadAllAssignments() {
      const shiftTypes = ['week_day', 'week_night', 'weekend_day', 'weekend_night'];
      
      for (const type of shiftTypes) {
        await this.fetchAssignments(type);
      }
      
      return this.serviceAssignments;
    },
    
    // Initialize data
    async initialize() {
      console.log('Initializing default service cover store...');
      await this.loadAllAssignments();
      console.log('Default service cover store initialized');
      return true;
    },
    
    // Clear error
    clearError() {
      this.error = null;
    }
  }
});

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}
