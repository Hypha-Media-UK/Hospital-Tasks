import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}

// Helper function to convert minutes back to time string (HH:MM:SS)
function minutesToTime(minutes) {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}:00`;
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
    
    // Get staffing shortages with detailed information
    getStaffingShortages: (state) => (serviceId) => {
      try {
        const assignment = state.serviceAssignments.find(a => a.id === serviceId);
        if (!assignment) return { hasShortage: false, shortages: [] };
        
        // If minimum_porters is not set or is 0, there's no staffing requirement
        if (!assignment.minimum_porters && 
            !assignment.minimum_porters_mon && 
            !assignment.minimum_porters_tue && 
            !assignment.minimum_porters_wed && 
            !assignment.minimum_porters_thu && 
            !assignment.minimum_porters_fri && 
            !assignment.minimum_porters_sat && 
            !assignment.minimum_porters_sun) {
          return { hasShortage: false, shortages: [] };
        }
        
        const porterAssignments = state.porterAssignments.filter(
          pa => pa.default_service_cover_assignment_id === serviceId ||
                pa.support_service_assignment_id === serviceId
        );
        
        if (porterAssignments.length === 0) {
          // No porters assigned - the entire period is a shortage
          return {
            hasShortage: true,
            shortages: [
              {
                startTime: assignment.start_time,
                endTime: assignment.end_time,
                type: 'shortage',
                porterCount: 0,
                requiredCount: assignment.minimum_porters || 1
              }
            ]
          };
        }
        
        // Convert service times to minutes for easier comparison
        const serviceStart = timeToMinutes(assignment.start_time);
        const serviceEnd = timeToMinutes(assignment.end_time);
        
        // Create a timeline of porter counts
        // First, collect all the time points where porter count changes
        let timePoints = new Set();
        timePoints.add(serviceStart);
        timePoints.add(serviceEnd);
        
        porterAssignments.forEach(pa => {
          const porterStart = timeToMinutes(pa.start_time);
          const porterEnd = timeToMinutes(pa.end_time);
          
          // Only add time points that are within the service's time range
          if (porterStart >= serviceStart && porterStart <= serviceEnd) {
            timePoints.add(porterStart);
          }
          if (porterEnd >= serviceStart && porterEnd <= serviceEnd) {
            timePoints.add(porterEnd);
          }
        });
        
        // Convert to array and sort
        timePoints = Array.from(timePoints).sort((a, b) => a - b);
        
        // Check each time segment between time points
        const shortages = [];
        
        for (let i = 0; i < timePoints.length - 1; i++) {
          const segmentStart = timePoints[i];
          const segmentEnd = timePoints[i + 1];
          
          // Skip segments with zero duration
          if (segmentStart === segmentEnd) continue;
          
          // Count porters active during this segment
          const activePorters = porterAssignments.filter(pa => {
            const porterStart = timeToMinutes(pa.start_time);
            const porterEnd = timeToMinutes(pa.end_time);
            return porterStart <= segmentStart && porterEnd >= segmentEnd;
          }).length;
          
          // Get the day of week for this segment (0 = Sunday, 1 = Monday, etc.)
          // For simplicity, we're using the start of the segment to determine the day
          const date = new Date();
          const hours = Math.floor(segmentStart / 60);
          const minutes = segmentStart % 60;
          date.setHours(hours, minutes, 0, 0);
          const dayOfWeek = date.getDay(); // 0 = Sunday, 1 = Monday, etc.
          
          // Get the minimum porter count for this day
          let requiredCount = assignment.minimum_porters || 1; // Default to global minimum
          
          // Override with day-specific minimum if available
          switch (dayOfWeek) {
            case 1: // Monday
              requiredCount = assignment.minimum_porters_mon ?? requiredCount;
              break;
            case 2: // Tuesday
              requiredCount = assignment.minimum_porters_tue ?? requiredCount;
              break;
            case 3: // Wednesday
              requiredCount = assignment.minimum_porters_wed ?? requiredCount;
              break;
            case 4: // Thursday
              requiredCount = assignment.minimum_porters_thu ?? requiredCount;
              break;
            case 5: // Friday
              requiredCount = assignment.minimum_porters_fri ?? requiredCount;
              break;
            case 6: // Saturday
              requiredCount = assignment.minimum_porters_sat ?? requiredCount;
              break;
            case 0: // Sunday
              requiredCount = assignment.minimum_porters_sun ?? requiredCount;
              break;
          }
          
          // Check if active porter count is below minimum
          if (activePorters < requiredCount) {
            shortages.push({
              startTime: minutesToTime(segmentStart),
              endTime: minutesToTime(segmentEnd),
              type: 'shortage',
              porterCount: activePorters,
              requiredCount: requiredCount
            });
          }
        }
        
        return {
          hasShortage: shortages.length > 0,
          shortages
        };
      } catch (error) {
        console.error('Error in getStaffingShortages:', error);
        return { hasShortage: false, shortages: [] };
      }
    },
    
    // Legacy method for compatibility
    hasStaffingShortage: (state) => (serviceId) => {
      return state.getStaffingShortages(serviceId).hasShortage;
    },
    
    // Get coverage gaps with detailed information
    getCoverageGaps: (state) => (serviceId) => {
      try {
        const assignment = state.serviceAssignments.find(a => a.id === serviceId);
        if (!assignment) return { hasGap: false, gaps: [] };
        
        const porterAssignments = state.porterAssignments.filter(
          pa => pa.default_service_cover_assignment_id === serviceId ||
                pa.support_service_assignment_id === serviceId
        );
        
        if (porterAssignments.length === 0) {
          // No porters assigned - the entire period is a gap
          return {
            hasGap: true,
            gaps: [
              {
                startTime: assignment.start_time,
                endTime: assignment.end_time,
                type: 'gap'
              }
            ]
          };
        }
        
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
          return { hasGap: false, gaps: [] };
        }
        
        // Sort porter assignments by start time
        const sortedAssignments = [...porterAssignments].sort((a, b) => {
          return timeToMinutes(a.start_time) - timeToMinutes(b.start_time);
        });
        
        const gaps = [];
        
        // Check for gap at the beginning
        if (timeToMinutes(sortedAssignments[0].start_time) > serviceStart) {
          gaps.push({
            startTime: assignment.start_time,
            endTime: sortedAssignments[0].start_time,
            type: 'gap'
          });
        }
        
        // Check for gaps between porter assignments
        for (let i = 0; i < sortedAssignments.length - 1; i++) {
          const currentEnd = timeToMinutes(sortedAssignments[i].end_time);
          const nextStart = timeToMinutes(sortedAssignments[i + 1].start_time);
          
          if (nextStart > currentEnd) {
            gaps.push({
              startTime: sortedAssignments[i].end_time,
              endTime: sortedAssignments[i + 1].start_time,
              type: 'gap'
            });
          }
        }
        
        // Check for gap at the end
        const lastEnd = timeToMinutes(sortedAssignments[sortedAssignments.length - 1].end_time);
        if (lastEnd < serviceEnd) {
          gaps.push({
            startTime: sortedAssignments[sortedAssignments.length - 1].end_time,
            endTime: assignment.end_time,
            type: 'gap'
          });
        }
        
        return {
          hasGap: gaps.length > 0,
          gaps
        };
      } catch (error) {
        console.error('Error in getCoverageGaps:', error);
        return { hasGap: false, gaps: [] };
      }
    },
    
    // Legacy method for compatibility
    hasCoverageGap: (state) => (serviceId) => {
      return state.getCoverageGaps(serviceId).hasGap;
    },
    
    // Get all coverage issues (both gaps and staffing shortages)
    getCoverageIssues: (state) => (serviceId) => {
      const gaps = state.getCoverageGaps(serviceId).gaps;
      const shortages = state.getStaffingShortages(serviceId).shortages;
      
      const allIssues = [...gaps, ...shortages].sort((a, b) => {
        return timeToMinutes(a.startTime) - timeToMinutes(b.startTime);
      });
      
      return {
        hasIssues: allIssues.length > 0,
        issues: allIssues
      };
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
