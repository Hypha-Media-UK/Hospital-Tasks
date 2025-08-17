import { defineStore } from 'pinia';
import { areaCoverApi, ApiError } from '../services/api';
import { apiRequest } from '../services/api';
import { timeToMinutes, minutesToTime } from '../utils/timeUtils';

export const useAreaCoverStore = defineStore('areaCover', {
  state: () => ({
    departments: [],
    areaAssignments: [],
    porterAssignments: [],
    loading: {
      departments: false,
      save: false
    },
    error: null
  }),
  
  getters: {
    // Get area assignments by department ID
    getAssignmentsByDepartmentId: (state) => (departmentId) => {
      return state.areaAssignments.filter(a => a.department_id === departmentId);
    },
    
    // Get area assignment by ID
    getAssignmentById: (state) => (id) => {
      return state.areaAssignments.find(a => a.id === id);
    },
    
    // Get area assignments by shift type
    getAssignmentsByShiftType: (state) => (shiftType) => {
      return state.areaAssignments.filter(a => a.shift_type === shiftType);
    },
    
    // Get porter assignments for a specific area assignment
    getPorterAssignmentsByAreaId: (state) => (areaAssignmentId) => {
      return state.porterAssignments.filter(
        pa => pa.default_area_cover_assignment_id === areaAssignmentId
      );
    },
    
    // Get sorted assignments by shift type (migrated from defaultAreaCoverStore)
    getSortedAssignmentsByType: (state) => (shiftType) => {
      const assignments = state.areaAssignments.filter(a => a.shift_type === shiftType);
      return [...assignments].sort((a, b) => {
        return a.department?.name?.localeCompare(b.department?.name) || 0;
      });
    },
    
    // Get unique porter assignments (remove duplicates by porter_id and time overlap)
    getUniquePorterAssignmentsByAreaId: (state) => (areaAssignmentId) => {
      const assignments = state.porterAssignments.filter(
        pa => pa.default_area_cover_assignment_id === areaAssignmentId
      );
      
      // Group by porter_id and merge overlapping time slots
      const porterGroups = {};
      assignments.forEach(assignment => {
        const porterId = assignment.porter_id;
        if (!porterGroups[porterId]) {
          porterGroups[porterId] = [];
        }
        porterGroups[porterId].push(assignment);
      });
      
      // For each porter, merge overlapping assignments and keep the most comprehensive one
      const uniqueAssignments = [];
      Object.values(porterGroups).forEach(porterAssignments => {
        if (porterAssignments.length === 1) {
          uniqueAssignments.push(porterAssignments[0]);
        } else {
          // Sort by start time and merge overlapping periods
          const sorted = porterAssignments.sort((a, b) => 
            timeToMinutes(a.start_time) - timeToMinutes(b.start_time)
          );
          
          // Take the assignment with the widest time coverage
          const earliest = sorted[0];
          const latest = sorted[sorted.length - 1];
          const merged = {
            ...earliest,
            start_time: earliest.start_time,
            end_time: timeToMinutes(latest.end_time) > timeToMinutes(earliest.end_time) 
              ? latest.end_time 
              : earliest.end_time
          };
          uniqueAssignments.push(merged);
        }
      });
      
      return uniqueAssignments;
    },

    // Calculate coverage gaps for an area assignment
    getCoverageGaps: (state) => (areaCoverId) => {
      try {
        const assignment = state.areaAssignments.find(a => a.id === areaCoverId);
        if (!assignment) {
          return { hasGap: false, gaps: [] };
        }

        // Access the getter method directly from the store instance
        const store = useAreaCoverStore();
        const porterAssignments = store.getUniquePorterAssignmentsByAreaId(areaCoverId);
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

        // For now, simplified gap detection - check if we have coverage gaps based on time
        const departmentStart = timeToMinutes(assignment.start_time);
        const departmentEnd = timeToMinutes(assignment.end_time);
        
        // Sort porter assignments by start time
        const sortedAssignments = [...porterAssignments].sort((a, b) => 
          timeToMinutes(a.start_time) - timeToMinutes(b.start_time)
        );

        const gaps = [];

        // Simple gap detection - check if first porter starts after department start
        if (sortedAssignments.length > 0) {
          const firstPorterStart = timeToMinutes(sortedAssignments[0].start_time);
          if (firstPorterStart > departmentStart) {
            gaps.push({
              startTime: assignment.start_time,
              endTime: sortedAssignments[0].start_time,
              type: 'start_gap',
              missingPorters: assignment.minimum_porters || 1
            });
          }
        }

        return {
          hasGap: gaps.length > 0,
          gaps: gaps
        };
      } catch (error) {
        console.error('Error in getCoverageGaps:', error);
        return { hasGap: false, gaps: [] };
      }
    },

    // Check for staffing shortages (when we have porters but not enough)
    getStaffingShortages: (state) => (areaCoverId) => {
      const assignment = state.areaAssignments.find(a => a.id === areaCoverId);
      if (!assignment) {
        return { hasShortage: false, shortages: [] };
      }

      const store = useAreaCoverStore();
      const porterAssignments = store.getUniquePorterAssignmentsByAreaId(areaCoverId);
      const minimumPorters = assignment.minimum_porters || 1;
      
      // For now, simple check: if we have fewer porters than minimum required
      const actualPorters = porterAssignments.length;
      
      if (actualPorters > 0 && actualPorters < minimumPorters) {
        return {
          hasShortage: true,
          shortages: [{
            period: `${assignment.start_time} - ${assignment.end_time}`,
            required: minimumPorters,
            actual: actualPorters,
            shortage: minimumPorters - actualPorters
          }]
        };
      }

      return { hasShortage: false, shortages: [] };
    },
    
    
    // Alias for hasAreaCoverageGap (used by components)
    hasAreaCoverageGap: (state) => (areaCoverId) => {
      const store = useAreaCoverStore();
      const gaps = store.getCoverageGaps(areaCoverId);
      return gaps.hasGap;
    },
    
    // Get all coverage issues (both gaps and staffing shortages)
    getCoverageIssues: (state) => (areaCoverId) => {
      const store = useAreaCoverStore();
      const gaps = store.getCoverageGaps(areaCoverId);
      const shortages = store.getStaffingShortages(areaCoverId);
      
      const issues = [];
      if (gaps.hasGap) {
        issues.push(...gaps.gaps.map(gap => ({ ...gap, issueType: 'gap' })));
      }
      if (shortages.hasShortage) {
        issues.push(...shortages.shortages.map(shortage => ({ ...shortage, issueType: 'shortage' })));
      }
      
      return {
        hasIssues: issues.length > 0,
        issues: issues
      };
    }
  },
  
  actions: {
    // Make sure assignments are loaded for a specific shift type
    async ensureAssignmentsLoaded(shiftType) {
      if (!this.areaAssignments || this.areaAssignments.length === 0) {
        await this.fetchAreaAssignments();
      }
      return this.getAssignmentsByShiftType(shiftType);
    },
    
    // Fetch assignments by shift type (for compatibility with components)
    async fetchAssignments(shiftType) {
      await this.fetchAreaAssignments();
      return this.getAssignmentsByShiftType(shiftType);
    },
    
    // For compatibility with DefaultAreaCoverSection component
    async addDepartment(departmentId, shiftType, startTime, endTime, color = '#4285F4') {
      return this.addAreaAssignment(departmentId, shiftType, startTime, endTime, color);
    },
    
    // For compatibility with DefaultAreaCoverSection component
    async updateDepartment(assignmentId, updates) {
      return this.updateAreaAssignment(assignmentId, updates);
    },
    
    // For compatibility with DefaultAreaCoverSection component
    async removeDepartment(assignmentId) {
      return this.deleteAreaAssignment(assignmentId);
    },
    
    // Fetch all area assignments
    async fetchAreaAssignments(shiftType = null) {
      this.loading.departments = true;
      this.error = null;
      
      try {
        const filters = shiftType ? { shift_type: shiftType } : {};
        const data = await areaCoverApi.getAll(filters);
        this.areaAssignments = data || [];
        
        // Also fetch porter assignments for each area assignment
        await this.fetchAllPorterAssignments();
        
        return this.areaAssignments;
      } catch (error) {
        console.error('Error fetching area assignments:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to load area assignments';
        return [];
      } finally {
        this.loading.departments = false;
      }
    },

    // Fetch porter assignments for all area assignments
    async fetchAllPorterAssignments() {
      try {
        // Clear existing porter assignments
        this.porterAssignments = [];
        
        // Fetch porter assignments for each area assignment
        for (const assignment of this.areaAssignments) {
          const porterAssignments = await this.fetchPorterAssignments(assignment.id);
          this.porterAssignments.push(...porterAssignments);
        }
      } catch (error) {
        console.error('Error fetching porter assignments:', error);
      }
    },

    // Fetch porter assignments for a specific area assignment
    async fetchPorterAssignments(areaAssignmentId) {
      try {
        // Use the directly imported apiRequest function
        const data = await apiRequest(`/area-cover/assignments/${areaAssignmentId}/porter-assignments`);
        return Array.isArray(data) ? data : [];
      } catch (error) {
        console.error('Error fetching porter assignments for area:', areaAssignmentId, error);
        return [];
      }
    },
    
    // Add a new area assignment
    async addAreaAssignment(departmentId, shiftType, startTime, endTime, color = '#4285F4') {
      this.loading.save = true;
      this.error = null;
      
      try {
        const assignmentData = {
          department_id: departmentId,
          shift_type: shiftType,
          start_time: startTime,
          end_time: endTime,
          color,
          minimum_porters: 1
        };
        
        const data = await areaCoverApi.create(assignmentData);
        
        if (data) {
          this.areaAssignments.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error adding area assignment:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to add area assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Update an area assignment
    async updateAreaAssignment(assignmentId, updates) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const data = await areaCoverApi.update(assignmentId, updates);
        
        if (data) {
          const index = this.areaAssignments.findIndex(a => a.id === assignmentId);
          if (index !== -1) {
            this.areaAssignments[index] = data;
          }
        }
        
        return data;
      } catch (error) {
        console.error('Error updating area assignment:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update area assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Delete an area assignment
    async deleteAreaAssignment(assignmentId) {
      this.loading.save = true;
      this.error = null;
      
      try {
        await areaCoverApi.delete(assignmentId);
        
        // Remove from local state
        this.areaAssignments = this.areaAssignments.filter(a => a.id !== assignmentId);
        
        return true;
      } catch (error) {
        console.error('Error deleting area assignment:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to delete area assignment';
        return false;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Porter assignment methods - now fully implemented
    async addPorterAssignment(areaCoverId, porterId, startTime, endTime) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const assignmentData = {
          porter_id: porterId,
          start_time: startTime,
          end_time: endTime
        };
        
        const data = await apiRequest(`/area-cover/assignments/${areaCoverId}/porter-assignments`, {
          method: 'POST',
          body: JSON.stringify(assignmentData)
        });
        
        if (data) {
          // Add to local state
          this.porterAssignments.push(data);
        }
        
        return data;
      } catch (error) {
        console.error('Error adding porter assignment:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to add porter assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    async updatePorterAssignment(porterAssignmentId, updates) {
      this.loading.save = true;
      this.error = null;
      
      try {
        const data = await apiRequest(`/area-cover/porter-assignments/${porterAssignmentId}`, {
          method: 'PUT',
          body: JSON.stringify(updates)
        });
        
        if (data) {
          // Update local state
          const index = this.porterAssignments.findIndex(pa => pa.id === porterAssignmentId);
          if (index !== -1) {
            this.porterAssignments[index] = data;
          }
        }
        
        return data;
      } catch (error) {
        console.error('Error updating porter assignment:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to update porter assignment';
        return null;
      } finally {
        this.loading.save = false;
      }
    },
    
    async removePorterAssignment(porterAssignmentId) {
      this.loading.save = true;
      this.error = null;
      
      try {
        await apiRequest(`/area-cover/porter-assignments/${porterAssignmentId}`, {
          method: 'DELETE'
        });
        
        // Remove from local state
        this.porterAssignments = this.porterAssignments.filter(pa => pa.id !== porterAssignmentId);
        
        return true;
      } catch (error) {
        console.error('Error removing porter assignment:', error);
        this.error = error instanceof ApiError ? error.message : 'Failed to remove porter assignment';
        return false;
      } finally {
        this.loading.save = false;
      }
    },
    
    // Initialize store
    async initialize() {
      await this.fetchAreaAssignments();
    },

    // Fetch shift porter building assignments
    async fetchShiftPorterBuildingAssignments(shiftId) {
      try {
        // This would typically fetch building assignments for porters in a specific shift
        // For now, return empty array as this functionality may not be implemented yet
        return [];
      } catch (error) {
        console.error('Error fetching shift porter building assignments:', error);
        return [];
      }
    }
  }
});
