import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';
import { useStaffStore } from './staffStore';
import { getCurrentDateTime, convertToUserTimezone } from '../utils/timezone';

// Helper function to determine if a date is on a weekend
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}

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

export const useShiftsStore = defineStore('shifts', {
  state: () => ({
    activeShifts: [],
    archivedShifts: [],
    archivedShiftTaskCounts: {}, // Object mapping shift IDs to their task counts
    currentShift: null,
    shiftTasks: [],
    shiftAreaCoverAssignments: [], // Shift-specific area cover assignments
    shiftAreaCoverPorterAssignments: [], // Porter assignments for shift area cover
    shiftSupportServiceAssignments: [], // Shift-specific support service assignments
    shiftSupportServicePorterAssignments: [], // Porter assignments for shift support services
    shiftPorterPool: [], // Porters assigned to the current shift
    shiftPorterAbsences: [], // Scheduled absences for porters in the current shift
    loading: {
      activeShifts: false,
      archivedShifts: false,
      currentShift: false,
      shiftTasks: false,
      createShift: false,
      endShift: false,
      updateTask: false,
      areaCover: false, // Loading state for area cover operations
      supportServices: false, // Loading state for support service operations
      porterPool: false, // Loading state for porter pool operations
      porterAbsences: false, // Loading state for porter absences operations
      deleteShift: false
    },
    error: null
  }),
  
  getters: {
    // Check if area has a staffing shortage based on minimum porter count
    hasAreaStaffingShortage: (state) => (areaId) => {
      try {
        const assignment = state.shiftAreaCoverAssignments.find(a => a.id === areaId);
        if (!assignment || !assignment.department || !assignment.department.id) return false;
        
        // Get the default area cover assignment to find the minimum_porters setting
        // We'll need to access this from localStorage or another source since we don't
        // have direct access to the default settings from the shift store
        const defaultMinPorters = localStorage.getItem(`area_${assignment.department.id}_min_porters`);
        const minPorters = defaultMinPorters ? parseInt(defaultMinPorters) : 1;
        
        // If minimum_porters is not set or is 0, there's no staffing requirement
        if (!minPorters) return false;
        
        const porterAssignments = state.shiftAreaCoverPorterAssignments.filter(
          pa => pa.shift_area_cover_assignment_id === areaId
        );
        
        if (porterAssignments.length === 0) return true; // No porters assigned
        
        // Convert area times to minutes for easier comparison
        const areaStart = timeToMinutes(assignment.start_time);
        const areaEnd = timeToMinutes(assignment.end_time);
        
        // Create a timeline of porter counts
        // First, collect all the time points where porter count changes
        let timePoints = new Set();
        timePoints.add(areaStart);
        timePoints.add(areaEnd);
        
        porterAssignments.forEach(pa => {
          const porterStart = timeToMinutes(pa.start_time);
          const porterEnd = timeToMinutes(pa.end_time);
          
          // Only add time points that are within the area's time range
          if (porterStart >= areaStart && porterStart <= areaEnd) {
            timePoints.add(porterStart);
          }
          if (porterEnd >= areaStart && porterEnd <= areaEnd) {
            timePoints.add(porterEnd);
          }
        });
        
        // Convert to array and sort
        timePoints = Array.from(timePoints).sort((a, b) => a - b);
        
        // Check each time segment between time points
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
          
          // Check if active porter count is below minimum
          if (activePorters < minPorters) {
            return true;
          }
        }
        
        return false;
      } catch (error) {
        console.error('Error in hasAreaStaffingShortage:', error);
        return false;
      }
    },
    
    // Get service staffing shortages with detailed information
    getServiceStaffingShortages: (state) => (serviceId) => {
      try {
        const assignment = state.shiftSupportServiceAssignments.find(a => a.id === serviceId);
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
        
        const porterAssignments = state.shiftSupportServicePorterAssignments.filter(
          pa => pa.shift_support_service_assignment_id === serviceId
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
        console.error('Error in getServiceStaffingShortages:', error);
        return { hasShortage: false, shortages: [] };
      }
    },
    
    // Legacy method for compatibility
    hasServiceStaffingShortage: (state) => (serviceId) => {
      return state.getServiceStaffingShortages(serviceId).hasShortage;
    },
    
    // Get active day shifts (week_day and weekend_day)
    activeDayShifts: (state) => {
      return state.activeShifts.filter(shift => 
        shift.shift_type === 'week_day' || shift.shift_type === 'weekend_day'
      );
    },
    
    // Get active night shifts (week_night and weekend_night)
    activeNightShifts: (state) => {
      return state.activeShifts.filter(shift => 
        shift.shift_type === 'week_night' || shift.shift_type === 'weekend_night'
      );
    },
    
    // Get pending tasks for current shift
    pendingTasks: (state) => {
      return state.shiftTasks.filter(task => task.status === 'pending');
    },
    
    // Get completed tasks for current shift
    completedTasks: (state) => {
      return state.shiftTasks.filter(task => task.status === 'completed');
    },
    
    // Get area cover assignments for current shift sorted by department name
    sortedAreaCoverAssignments: (state) => {
      return [...state.shiftAreaCoverAssignments].sort((a, b) => {
        return a.department.name.localeCompare(b.department.name);
      });
    },
    
    // Check if a porter is absent for the current shift
    isPorterAbsent: () => (porterId, date) => {
      const staffStore = useStaffStore();
      return staffStore.isPorterAbsent(porterId, date);
    },
    
    // Get absence details for a porter
    getPorterAbsenceDetails: () => (porterId, date) => {
      const staffStore = useStaffStore();
      return staffStore.getPorterAbsenceDetails(porterId, date);
    },
    
    // Get support service assignments for current shift sorted by service name
    sortedSupportServiceAssignments: (state) => {
      return [...state.shiftSupportServiceAssignments].sort((a, b) => {
        return a.service.name.localeCompare(b.service.name);
      });
    },
    
    // Get area cover assignments for day shifts (week_day and weekend_day)
    shiftDayAreaCoverAssignments: (state) => {
      return state.shiftAreaCoverAssignments.filter(assignment => 
        assignment.shift_type === 'week_day' || assignment.shift_type === 'weekend_day'
      );
    },
    
    // Get area cover assignments for night shifts (week_night and weekend_night)
    shiftNightAreaCoverAssignments: (state) => {
      return state.shiftAreaCoverAssignments.filter(assignment => 
        assignment.shift_type === 'week_night' || assignment.shift_type === 'weekend_night'
      );
    },
    
    // Get area cover assignment by ID
    getAreaCoverAssignmentById: (state) => (id) => {
      return state.shiftAreaCoverAssignments.find(a => a.id === id);
    },
    
    // Get support service assignment by ID
    getSupportServiceAssignmentById: (state) => (id) => {
      return state.shiftSupportServiceAssignments.find(a => a.id === id);
    },
    
    // Get porter assignments for a specific area cover assignment
    getPorterAssignmentsByAreaId: (state) => (areaCoverId) => {
      return state.shiftAreaCoverPorterAssignments.filter(
        pa => pa.shift_area_cover_assignment_id === areaCoverId
      );
    },
    
  // Get porter assignments for a specific support service assignment
  getPorterAssignmentsByServiceId: (state) => (serviceId) => {
    if (!serviceId || !state.shiftSupportServicePorterAssignments) {
      return [];
    }
    return state.shiftSupportServicePorterAssignments.filter(
      pa => pa.shift_support_service_assignment_id === serviceId
    ) || [];
  },
  
  // Get scheduled absences for a porter in the current shift
  getPorterAbsences: (state) => (porterId) => {
    if (!porterId || !state.shiftPorterAbsences) {
      return [];
    }
    return state.shiftPorterAbsences.filter(
      absence => absence.porter_id === porterId
    ) || [];
  },
  
  // Check if a porter is currently on a scheduled absence
  isPorterOnScheduledAbsence: (state) => (porterId) => {
    if (!porterId || !state.shiftPorterAbsences) {
      return false;
    }
    
    // Get current time in minutes
    const now = new Date();
    const currentHours = now.getHours();
    const currentMinutes = now.getMinutes();
    const currentTimeMinutes = (currentHours * 60) + currentMinutes;
    
    // Check if any absence is currently active
    return state.shiftPorterAbsences.some(absence => {
      const porterStart = timeToMinutes(absence.start_time);
      const porterEnd = timeToMinutes(absence.end_time);
      return absence.porter_id === porterId && 
             porterStart <= currentTimeMinutes && 
             porterEnd >= currentTimeMinutes;
    });
  },
    
    // Get coverage gaps with detailed information for an area
    getAreaCoverageGaps: (state) => (areaCoverId) => {
      try {
        const assignment = state.shiftAreaCoverAssignments.find(a => a.id === areaCoverId);
        if (!assignment) return { hasGap: false, gaps: [] };
        
        // Get shift date from the current shift
        const shiftDate = new Date();
        const staffStore = useStaffStore();
        
        const porterAssignments = state.shiftAreaCoverPorterAssignments.filter(
          pa => pa.shift_area_cover_assignment_id === areaCoverId
        );
        
        // Filter out absent porters
        const availablePorterAssignments = porterAssignments.filter(
          pa => !staffStore.isPorterAbsent(pa.porter_id, shiftDate)
        );
        
        if (porterAssignments.length === 0 || availablePorterAssignments.length === 0) {
          // No porters assigned or all porters are absent - the entire period is a gap
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
        
        // Convert department times to minutes for easier comparison
        const departmentStart = timeToMinutes(assignment.start_time);
        const departmentEnd = timeToMinutes(assignment.end_time);
      
        // First check if any single non-absent porter covers the entire time period
        const fullCoverageExists = availablePorterAssignments.some(assignment => {
          const porterStart = timeToMinutes(assignment.start_time);
          const porterEnd = timeToMinutes(assignment.end_time);
          return porterStart <= departmentStart && porterEnd >= departmentEnd;
        });
        
        // If at least one porter provides full coverage, there's no gap
        if (fullCoverageExists) {
          return { hasGap: false, gaps: [] };
        }
        
        // Sort available porter assignments by start time
        const sortedAssignments = [...availablePorterAssignments].sort((a, b) => {
          return timeToMinutes(a.start_time) - timeToMinutes(b.start_time);
        });
        
        const gaps = [];
        
        // Check for gap at the beginning
        if (timeToMinutes(sortedAssignments[0].start_time) > departmentStart) {
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
        if (lastEnd < departmentEnd) {
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
        console.error('Error in getAreaCoverageGaps:', error);
        return { hasGap: false, gaps: [] };
      }
    },
    
    // Legacy method for backward compatibility
    hasAreaCoverageGap: (state) => (areaCoverId) => {
      return state.getAreaCoverageGaps(areaCoverId).hasGap;
    },
    
    // Get staffing shortages for an area
    getAreaStaffingShortages: (state) => (areaCoverId) => {
      try {
        const assignment = state.shiftAreaCoverAssignments.find(a => a.id === areaCoverId);
        if (!assignment) return false;
        
        // Get shift date from the current shift
        const shiftDate = new Date();
        const staffStore = useStaffStore();
        
        const porterAssignments = state.shiftAreaCoverPorterAssignments.filter(
          pa => pa.shift_area_cover_assignment_id === areaCoverId
        );
        
        // Filter out absent porters
        const availablePorterAssignments = porterAssignments.filter(
          pa => !staffStore.isPorterAbsent(pa.porter_id, shiftDate)
        );
        
        if (porterAssignments.length === 0 || availablePorterAssignments.length === 0) return true; // No porters or all porters absent means complete gap
        
        // Convert department times to minutes for easier comparison
        const departmentStart = timeToMinutes(assignment.start_time);
        const departmentEnd = timeToMinutes(assignment.end_time);
        
        // First check if any single non-absent porter covers the entire time period
        const fullCoverageExists = availablePorterAssignments.some(assignment => {
          const porterStart = timeToMinutes(assignment.start_time);
          const porterEnd = timeToMinutes(assignment.end_time);
          return porterStart <= departmentStart && porterEnd >= departmentEnd;
        });
        
        // If at least one porter provides full coverage, there's no gap
        if (fullCoverageExists) {
          return false;
        }
        
        // Sort available porter assignments by start time
        const sortedAssignments = [...availablePorterAssignments].sort((a, b) => {
          return timeToMinutes(a.start_time) - timeToMinutes(b.start_time);
        });
        
        // Check for gap at the beginning
        if (timeToMinutes(sortedAssignments[0].start_time) > departmentStart) {
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
        if (lastEnd < departmentEnd) {
          return true;
        }
        
        return false;
      } catch (error) {
        console.error('Error in hasAreaCoverageGap:', error);
        return false;
      }
    },
    
    // Get coverage gaps with detailed information for a service
    getServiceCoverageGaps: (state) => (serviceId) => {
      try {
        const assignment = state.shiftSupportServiceAssignments.find(a => a.id === serviceId);
        if (!assignment) return { hasGap: false, gaps: [] };
        
        // Get shift date from the current shift
        const shiftDate = new Date();
        const staffStore = useStaffStore();
        
        const porterAssignments = state.shiftSupportServicePorterAssignments.filter(
          pa => pa.shift_support_service_assignment_id === serviceId
        );
        
        // Filter out absent porters
        const availablePorterAssignments = porterAssignments.filter(
          pa => !staffStore.isPorterAbsent(pa.porter_id, shiftDate)
        );
        
        if (porterAssignments.length === 0 || availablePorterAssignments.length === 0) {
          // No porters assigned or all porters are absent - the entire period is a gap
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
      
        // First check if any single non-absent porter covers the entire time period
        const fullCoverageExists = availablePorterAssignments.some(assignment => {
          const porterStart = timeToMinutes(assignment.start_time);
          const porterEnd = timeToMinutes(assignment.end_time);
          return porterStart <= serviceStart && porterEnd >= serviceEnd;
        });
        
        // If at least one porter provides full coverage, there's no gap
        if (fullCoverageExists) {
          return { hasGap: false, gaps: [] };
        }
        
        // Sort available porter assignments by start time
        const sortedAssignments = [...availablePorterAssignments].sort((a, b) => {
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
        console.error('Error in getServiceCoverageGaps:', error);
        return { hasGap: false, gaps: [] };
      }
    },
    
    // Legacy method for backward compatibility
    hasServiceCoverageGap: (state) => (serviceId) => {
      return state.getServiceCoverageGaps(serviceId).hasGap;
    },
    
    // Check if a shift is in setup mode (before shift start time) vs active mode (during/after shift start)
    isShiftInSetupMode: (state) => (shift) => {
      if (!shift) return false;
      
      const now = getCurrentDateTime();
      const shiftDate = convertToUserTimezone(shift.shift_date || shift.start_time);
      
      // Extract time from start_time (could be full datetime or just time)
      let startHours, startMinutes;
      if (shift.start_time.includes('T')) {
        // Full datetime string
        const startDateTime = convertToUserTimezone(shift.start_time);
        startHours = startDateTime.getHours();
        startMinutes = startDateTime.getMinutes();
      } else {
        // Just time string (HH:MM:SS or HH:MM)
        const timeParts = shift.start_time.split(':');
        startHours = parseInt(timeParts[0]);
        startMinutes = parseInt(timeParts[1]);
      }
      
      // Create shift start datetime in user's timezone
      const shiftStart = new Date(shiftDate);
      shiftStart.setHours(startHours, startMinutes, 0, 0);
      
      // If current time is before shift start, we're in setup mode
      return now < shiftStart;
    }
  },
  
  actions: {
    // Fetch all active shifts
    async fetchActiveShifts() {
      this.loading.activeShifts = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shifts')
          .select(`
            *,
            supervisor:supervisor_id(id, first_name, last_name, role)
          `)
          .eq('is_active', true)
          .order('start_time', { ascending: false });
        
        if (error) throw error;
        
        this.activeShifts = data || [];
      } catch (error) {
        console.error('Error fetching active shifts:', error);
        this.error = 'Failed to load active shifts';
      } finally {
        this.loading.activeShifts = false;
      }
    },
    
    // Fetch all archived shifts
    async fetchArchivedShifts() {
      this.loading.archivedShifts = true;
      this.error = null;
      
      try {
        console.log('Fetching archived shifts from database...');
        
        // First check that archived shifts exist
        const { count, error: countError } = await supabase
          .from('shifts')
          .select('*', { count: 'exact', head: true })
          .eq('is_active', false);
          
        if (countError) {
          console.error('Error counting archived shifts:', countError);
          throw countError;
        }
        
        console.log(`Found ${count} archived shifts in database`);
        
        // If no archived shifts, set empty array and return early
        if (count === 0) {
          this.archivedShifts = [];
          return;
        }
        
        // Fetch the actual shifts with supervisor data
        const { data, error } = await supabase
          .from('shifts')
          .select(`
            *,
            supervisor:supervisor_id(id, first_name, last_name, role)
          `)
          .eq('is_active', false)
          .order('end_time', { ascending: false });
        
        if (error) {
          console.error('Error fetching archived shifts data:', error);
          throw error;
        }
        
        console.log(`Retrieved ${data?.length || 0} archived shifts with supervisor data`);
        
        // Check if we got the expected number of shifts
        if (data && data.length !== count) {
          console.warn(`Count mismatch: Expected ${count} archived shifts but received ${data.length}`);
        }
        
        // Check for shifts with missing end_time and fix them
        const shiftsWithoutEndTime = data?.filter(shift => !shift.end_time) || [];
        if (shiftsWithoutEndTime.length > 0) {
          console.warn(`Found ${shiftsWithoutEndTime.length} archived shifts with missing end_time`);
        }
        
        this.archivedShifts = data || [];
      } catch (error) {
        console.error('Error fetching archived shifts:', error);
        this.error = 'Failed to load archived shifts';
      } finally {
        this.loading.archivedShifts = false;
      }
    },
    
    // Fetch a specific shift by ID
    async fetchShiftById(shiftId) {
      this.loading.currentShift = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shifts')
          .select(`
            *,
            supervisor:supervisor_id(id, first_name, last_name, role)
          `)
          .eq('id', shiftId)
          .single();
        
        if (error) throw error;
        
        this.currentShift = data;
        return data;
      } catch (error) {
        console.error('Error fetching shift:', error);
        this.error = 'Failed to load shift details';
        return null;
      } finally {
        this.loading.currentShift = false;
      }
    },
    
    // Fetch tasks for a specific shift
    async fetchShiftTasks(shiftId) {
      this.loading.shiftTasks = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_tasks')
          .select(`
            *,
            task_item:task_item_id(
              id, 
              name, 
              description, 
              task_type_id,
              task_type:task_type_id(id, name)
            ),
            porter:porter_id(id, first_name, last_name),
            origin_department:origin_department_id(id, name, building_id),
            destination_department:destination_department_id(id, name, building_id)
          `)
          .eq('shift_id', shiftId)
          .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        this.shiftTasks = data || [];
        return data;
      } catch (error) {
        console.error('Error fetching shift tasks:', error);
        this.error = 'Failed to load shift tasks';
        return [];
      } finally {
        this.loading.shiftTasks = false;
      }
    },
    
    // Create a new shift
    async createShift(supervisorId, shiftType, startTime = null) {
      this.loading.createShift = true;
      this.error = null;
      
      try {
        // Use provided start time or default to current time
        const shiftStartTime = startTime || new Date().toISOString();
        
        console.log(`Creating new shift with supervisor: ${supervisorId}, type: ${shiftType}, start time: ${shiftStartTime}`);
        
        const { data, error } = await supabase
          .from('shifts')
          .insert({
            supervisor_id: supervisorId,
            shift_type: shiftType,
            start_time: shiftStartTime,
            is_active: true
          })
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          const newShift = data[0];
          console.log(`Created new shift with ID: ${newShift.id}, type: ${newShift.shift_type}`);
          
          // Add the new shift to activeShifts array
          this.activeShifts.unshift(newShift);
          
          // The database trigger will automatically copy default assignments
          // Let's just fetch the assignments to update our local state
          console.log('Fetching shift data after creation...');
          await this.fetchShiftAreaCover(newShift.id);
          await this.fetchShiftSupportServices(newShift.id);
          
          // Debug: Check what porter assignments were copied
          console.log('Area cover porter assignments:', this.shiftAreaCoverPorterAssignments);
          console.log('Support service porter assignments:', this.shiftSupportServicePorterAssignments);
          
          return newShift;
        }
        
        return null;
      } catch (error) {
        console.error('Error creating shift:', error);
        this.error = 'Failed to create shift';
        return null;
      } finally {
        this.loading.createShift = false;
      }
    },
    
    // End an active shift
    async endShift(shiftId) {
      this.loading.endShift = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shifts')
          .update({
            end_time: new Date().toISOString(),
            is_active: false
          })
          .eq('id', shiftId)
          .select();
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Remove the shift from activeShifts array
          this.activeShifts = this.activeShifts.filter(shift => shift.id !== shiftId);
          
          // If this was the current shift, update it
          if (this.currentShift && this.currentShift.id === shiftId) {
            this.currentShift = data[0];
          }
          
          // Add to archived shifts if we have that loaded
          if (this.archivedShifts.length > 0) {
            this.archivedShifts.unshift(data[0]);
          }
          
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error ending shift:', error);
        this.error = 'Failed to end shift';
        return null;
      } finally {
        this.loading.endShift = false;
      }
    },
    
    // Add a task to a shift
    async addTaskToShift(shiftId, taskData) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        // First check if the shift is active
        const { data: shift } = await supabase
          .from('shifts')
          .select('is_active')
          .eq('id', shiftId)
          .single();
          
        if (!shift || !shift.is_active) {
          this.error = 'Cannot add tasks to archived shifts';
          return null;
        }
        
        // Create default time strings for the task if not provided
        const now = new Date();
        const hours = String(now.getHours()).padStart(2, '0');
        const minutes = String(now.getMinutes()).padStart(2, '0');
        const nowTimeString = `${hours}:${minutes}`;
        
        // Calculate time_allocated (+1 minute from now)
        const allocatedMinutes = now.getMinutes() + 1;
        const allocatedHours = now.getHours() + Math.floor(allocatedMinutes / 60);
        const normalizedAllocatedMinutes = allocatedMinutes % 60;
        const allocatedTimeString = `${String(allocatedHours % 24).padStart(2, '0')}:${String(normalizedAllocatedMinutes).padStart(2, '0')}`;
        
        // Calculate time_completed (+20 minutes from now)
        const completedMinutes = now.getMinutes() + 20;
        const completedHours = now.getHours() + Math.floor(completedMinutes / 60);
        const normalizedCompletedMinutes = completedMinutes % 60;
        const completedTimeString = `${String(completedHours % 24).padStart(2, '0')}:${String(normalizedCompletedMinutes).padStart(2, '0')}`;
        
        // Use provided time values or default ones
        const taskInsertData = {
          shift_id: shiftId,
          task_item_id: taskData.taskItemId,
          porter_id: taskData.porterId || null,
          origin_department_id: taskData.originDepartmentId || null,
          destination_department_id: taskData.destinationDepartmentId || null,
          status: taskData.status || 'pending',
          time_received: taskData.time_received || nowTimeString,
          time_allocated: taskData.time_allocated || allocatedTimeString,
          time_completed: taskData.time_completed || completedTimeString
        };
        
        // Proceed with adding the task
        const { data, error } = await supabase
          .from('shift_tasks')
          .insert(taskInsertData)
          .select(`
            *,
            task_item:task_item_id(
              id, 
              name, 
              description, 
              task_type_id,
              task_type:task_type_id(id, name)
            ),
            porter:porter_id(id, first_name, last_name),
            origin_department:origin_department_id(id, name, building_id),
            destination_department:destination_department_id(id, name, building_id)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add the new task to shiftTasks array
          this.shiftTasks.unshift(data[0]);
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error adding task to shift:', error);
        this.error = 'Failed to add task';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Update task status
    async updateTaskStatus(taskId, status) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        // First, get the current task to check the current status
        const { data: existingTask, error: fetchError } = await supabase
          .from('shift_tasks')
          .select('*')
          .eq('id', taskId)
          .single();
        
        if (fetchError) throw fetchError;
        
        let updates = { status };
        
        // If we're changing from completed to pending (reopening a completed task)
        // we keep all the original times as they were
        if (existingTask.status === 'completed' && status === 'pending') {
          // No time field updates needed - we keep the original times
          console.log('Reopening completed task - keeping original times');
        }
        // If we're marking a task as pending (but it wasn't completed)
        // we need to update the time_allocated and time_completed fields
        else if (status === 'pending' && existingTask.status === 'pending') {
          // Get current time
          const now = new Date();
          const hours = String(now.getHours()).padStart(2, '0');
          const minutes = String(now.getMinutes()).padStart(2, '0');
          const nowTimeString = `${hours}:${minutes}`;
          
          // Calculate time_completed (+20 minutes from now)
          const completedMinutes = now.getMinutes() + 20;
          const completedHours = now.getHours() + Math.floor(completedMinutes / 60);
          const normalizedCompletedMinutes = completedMinutes % 60;
          const completedTimeString = `${String(completedHours % 24).padStart(2, '0')}:${String(normalizedCompletedMinutes).padStart(2, '0')}`;
          
          // Update timestamps, but keep the original time_received
          updates = {
            ...updates,
            time_allocated: nowTimeString,
            time_completed: completedTimeString
          };
          
          console.log('Reopening pending task - updating time_allocated and time_completed');
        }
        
        // If we're changing from pending to completed (completing a task)
        // we keep the expected completion time already stored in the task
        else if (existingTask.status === 'pending' && status === 'completed') {
          // No time field updates needed - we keep the existing time_completed value
          console.log('Completing task - using existing expected completion time');
        }
        
        // Update the task with the new status and any time changes
        const { data, error } = await supabase
          .from('shift_tasks')
          .update(updates)
          .eq('id', taskId)
          .select(`
            *,
            task_item:task_item_id(
              id, 
              name, 
              description, 
              task_type_id,
              task_type:task_type_id(id, name)
            ),
            porter:porter_id(id, first_name, last_name),
            origin_department:origin_department_id(id, name, building_id),
            destination_department:destination_department_id(id, name, building_id)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the task in shiftTasks array
          const index = this.shiftTasks.findIndex(task => task.id === taskId);
          if (index !== -1) {
            this.shiftTasks[index] = data[0];
          }
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error updating task status:', error);
        this.error = 'Failed to update task status';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Assign porter to task
    async assignPorterToTask(taskId, porterId) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_tasks')
          .update({ porter_id: porterId })
          .eq('id', taskId)
          .select(`
            *,
            task_item:task_item_id(
              id, 
              name, 
              description, 
              task_type_id,
              task_type:task_type_id(id, name)
            ),
            porter:porter_id(id, first_name, last_name),
            origin_department:origin_department_id(id, name, building_id),
            destination_department:destination_department_id(id, name, building_id)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the task in shiftTasks array
          const index = this.shiftTasks.findIndex(task => task.id === taskId);
          if (index !== -1) {
            this.shiftTasks[index] = data[0];
          }
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error assigning porter to task:', error);
        this.error = 'Failed to assign porter to task';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Update an existing task
    async updateTask(taskId, taskData) {
      this.loading.updateTask = true;
      this.error = null;
      
      try {
        // Build update object with required fields
        const updateObj = {
          task_item_id: taskData.taskItemId,
          porter_id: taskData.porterId || null,
          origin_department_id: taskData.originDepartmentId || null,
          destination_department_id: taskData.destinationDepartmentId || null,
          status: taskData.status
        };
        
        // Extract just the time part (HH:MM) from any time values provided
        // This handles both the old-style ISO dates and new-style direct time inputs
        if (taskData.time_received) {
          // Check if we received a full datetime string (old format)
          if (taskData.time_received.includes('T')) {
            const date = new Date(taskData.time_received);
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            updateObj.time_received = `${hours}:${minutes}`;
          } else {
            // Otherwise, use the provided time string directly (likely already in HH:MM format)
            updateObj.time_received = taskData.time_received;
          }
        }
        
        if (taskData.time_allocated) {
          if (taskData.time_allocated.includes('T')) {
            const date = new Date(taskData.time_allocated);
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            updateObj.time_allocated = `${hours}:${minutes}`;
          } else {
            updateObj.time_allocated = taskData.time_allocated;
          }
        }
        
        if (taskData.time_completed) {
          if (taskData.time_completed.includes('T')) {
            const date = new Date(taskData.time_completed);
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            updateObj.time_completed = `${hours}:${minutes}`;
          } else {
            updateObj.time_completed = taskData.time_completed;
          }
        }
        
        const { data, error } = await supabase
          .from('shift_tasks')
          .update(updateObj)
          .eq('id', taskId)
          .select(`
            *,
            task_item:task_item_id(
              id, 
              name, 
              description, 
              task_type_id,
              task_type:task_type_id(id, name)
            ),
            porter:porter_id(id, first_name, last_name),
            origin_department:origin_department_id(id, name, building_id),
            destination_department:destination_department_id(id, name, building_id)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update the task in shiftTasks array
          const index = this.shiftTasks.findIndex(task => task.id === taskId);
          if (index !== -1) {
            this.shiftTasks[index] = data[0];
          }
          return data[0];
        }
        
        return null;
      } catch (error) {
        console.error('Error updating task:', error);
        this.error = 'Failed to update task';
        return null;
      } finally {
        this.loading.updateTask = false;
      }
    },
    
    // Clear current shift and tasks
    clearCurrentShift() {
      this.currentShift = null;
      this.shiftTasks = [];
    },
    
    // Initialize store data
    async initialize() {
      await this.fetchActiveShifts();
    },
    
    // Setup shift area cover from default settings
    async setupShiftAreaCoverFromDefaults(shiftId, shiftType) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        console.log(`Setting up area cover from defaults for shift ${shiftId}, type: ${shiftType}`);
        
        // Import and use the area cover store to get defaults
        const { useAreaCoverStore } = await import('./areaCoverStore');
        const areaCoverStore = useAreaCoverStore();
        
        // Ensure defaults are loaded
        await areaCoverStore.ensureAssignmentsLoaded(shiftType);
        
        // Get the appropriate default assignments based on shift type
        let defaultAssignments = [];
        switch(shiftType) {
          case 'week_day':
            defaultAssignments = areaCoverStore.weekDayAssignments || [];
            break;
          case 'week_night':
            defaultAssignments = areaCoverStore.weekNightAssignments || [];
            break;
          case 'weekend_day':
            defaultAssignments = areaCoverStore.weekendDayAssignments || [];
            break;
          case 'weekend_night':
            defaultAssignments = areaCoverStore.weekendNightAssignments || [];
            break;
        }
        
        console.log(`Found ${defaultAssignments.length} default assignments for ${shiftType}`);
        
        if (defaultAssignments.length === 0) {
          console.log('No default assignments found, skipping setup');
          return;
        }
        
        // Create shift area cover assignments from defaults
        for (const defaultAssignment of defaultAssignments) {
          console.log(`Creating area cover for department: ${defaultAssignment.department?.name}`);
          
          const newAssignment = await this.addShiftAreaCover(
            shiftId,
            defaultAssignment.department_id,
            defaultAssignment.start_time,
            defaultAssignment.end_time,
            defaultAssignment.color || '#4285F4'
          );
          
          if (newAssignment && defaultAssignment.porters && defaultAssignment.porters.length > 0) {
            console.log(`Adding ${defaultAssignment.porters.length} porters to department ${defaultAssignment.department?.name}`);
            
            // Add porter assignments from defaults
            for (const porterAssignment of defaultAssignment.porters) {
              await this.addShiftAreaCoverPorter(
                newAssignment.id,
                porterAssignment.porter_id,
                porterAssignment.start_time,
                porterAssignment.end_time,
                porterAssignment.agreed_absence
              );
            }
          }
        }
        
        console.log('Completed setting up area cover from defaults');
      } catch (error) {
        console.error('Error setting up area cover from defaults:', error);
        this.error = 'Failed to setup area cover from defaults';
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Setup shift support services from default settings
    async setupShiftSupportServicesFromDefaults(shiftId, shiftType) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        console.log(`Setting up support services from defaults for shift ${shiftId}, type: ${shiftType}`);
        
        // Import and use the support services store to get defaults
        const { useSupportServicesStore } = await import('./supportServicesStore');
        const supportServicesStore = useSupportServicesStore();
        
        // Ensure defaults are loaded
        await supportServicesStore.ensureAssignmentsLoaded(shiftType);
        
        // Get the appropriate default assignments based on shift type
        const defaultAssignments = supportServicesStore.getSortedAssignmentsByType(shiftType) || [];
        
        console.log(`Found ${defaultAssignments.length} default service assignments for ${shiftType}`);
        
        if (defaultAssignments.length === 0) {
          console.log('No default service assignments found, skipping setup');
          return;
        }
        
        // Create shift support service assignments from defaults
        for (const defaultAssignment of defaultAssignments) {
          console.log(`Creating service assignment for: ${defaultAssignment.service?.name}`);
          
          const newAssignment = await this.addShiftSupportService(
            shiftId,
            defaultAssignment.service_id,
            defaultAssignment.start_time,
            defaultAssignment.end_time,
            defaultAssignment.color || '#4285F4'
          );
          
          if (newAssignment && defaultAssignment.porters && defaultAssignment.porters.length > 0) {
            console.log(`Adding ${defaultAssignment.porters.length} porters to service ${defaultAssignment.service?.name}`);
            
            // Add porter assignments from defaults
            for (const porterAssignment of defaultAssignment.porters) {
              await this.addShiftSupportServicePorter(
                newAssignment.id,
                porterAssignment.porter_id,
                porterAssignment.start_time,
                porterAssignment.end_time,
                porterAssignment.agreed_absence
              );
            }
          }
        }
        
        console.log('Completed setting up support services from defaults');
      } catch (error) {
        console.error('Error setting up support services from defaults:', error);
        this.error = 'Failed to setup support services from defaults';
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Area Cover Management
    
    // Fetch area cover assignments for a specific shift
    async fetchShiftAreaCover(shiftId) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        console.log(`fetchShiftAreaCover called for shift ID: ${shiftId}`);
        
        // Check if the shift exists first
        const { data: shiftData, error: shiftError } = await supabase
          .from('shifts')
          .select('id, shift_type')
          .eq('id', shiftId)
          .single();
        
        if (shiftError) {
          console.error('Error checking shift:', shiftError);
          throw shiftError;
        }
        
        if (!shiftData) {
          console.error(`No shift found with ID: ${shiftId}`);
          return [];
        }
        
        console.log(`Found shift: ${shiftData.id}, type: ${shiftData.shift_type}`);
        
        // Query shift area cover assignments
        console.log(`Fetching area cover assignments for shift: ${shiftId}`);
          const { data, error } = await supabase
            .from('shift_area_cover_assignments')
            .select(`
              *,
              department:department_id(
                id,
                name,
                building_id,
                color,
                building:building_id(id, name)
              )
            `)
            .eq('shift_id', shiftId);
        
        if (error) {
          console.error('Error fetching shift area cover assignments:', error);
          throw error;
        }
        
        console.log(`Fetched ${data?.length || 0} area cover assignments`);
        
        // Store the assignments
        this.shiftAreaCoverAssignments = data || [];
        
        // Also fetch porter assignments for these area cover assignments
        const assignmentIds = data?.map(a => a.id) || [];
        
        if (assignmentIds.length > 0) {
          console.log(`Fetching porter assignments for ${assignmentIds.length} area cover assignments`);
          
          const { data: porterData, error: porterError } = await supabase
            .from('shift_area_cover_porter_assignments')
            .select(`
              *,
              porter:porter_id(id, first_name, last_name),
              shift_area_cover_assignment:shift_area_cover_assignment_id(
                id,
                color,
                department:department_id(id, name)
              )
            `)
            .in('shift_area_cover_assignment_id', assignmentIds);
          
          if (porterError) {
            console.error('Error fetching area cover porter assignments:', porterError);
            throw porterError;
          }
          
          console.log(`Fetched ${porterData?.length || 0} porter assignments for area cover`);
          
          // Store the porter assignments
          this.shiftAreaCoverPorterAssignments = porterData || [];
        } else {
          // No area cover assignments, so no porter assignments
          this.shiftAreaCoverPorterAssignments = [];
        }
        
        return this.shiftAreaCoverAssignments;
      } catch (error) {
        console.error('Error fetching shift area cover:', error);
        this.error = 'Failed to load area coverage';
        return [];
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Add a new area cover assignment to a shift
    async addShiftAreaCover(shiftId, departmentId, startTime, endTime, color = '#4285F4') {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_area_cover_assignments')
          .insert({
            shift_id: shiftId,
            department_id: departmentId,
            start_time: startTime,
            end_time: endTime,
            color: color
          })
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              color,
              building:building_id(id, name)
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to local state
          this.shiftAreaCoverAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding area cover to shift:', error);
        this.error = 'Failed to add area cover to shift';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Update a shift area cover assignment
    async updateShiftAreaCover(assignmentId, updates) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_area_cover_assignments')
          .update(updates)
          .eq('id', assignmentId)
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              building:building_id(id, name)
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update in local state
          const index = this.shiftAreaCoverAssignments.findIndex(a => a.id === assignmentId);
          if (index !== -1) {
            this.shiftAreaCoverAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating shift area cover:', error);
        this.error = 'Failed to update area cover';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Remove a shift area cover assignment
    async removeShiftAreaCover(assignmentId) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_area_cover_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftAreaCoverAssignments = this.shiftAreaCoverAssignments.filter(a => a.id !== assignmentId);
        
        // Also remove all associated porter assignments
        this.shiftAreaCoverPorterAssignments = this.shiftAreaCoverPorterAssignments.filter(
          pa => pa.shift_area_cover_assignment_id !== assignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing shift area cover:', error);
        this.error = 'Failed to remove area cover';
        return false;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
  // Add a porter to a shift area cover assignment
  async addShiftAreaCoverPorter(areaCoverId, porterId, startTime, endTime, agreedAbsence = null) {
    this.loading.areaCover = true;
    this.error = null;
    
    try {
      const { data, error } = await supabase
        .from('shift_area_cover_porter_assignments')
        .insert({
          shift_area_cover_assignment_id: areaCoverId,
          porter_id: porterId,
          start_time: startTime,
          end_time: endTime,
          agreed_absence: agreedAbsence
        })
          .select(`
            *,
            porter:porter_id(id, first_name, last_name),
            shift_area_cover_assignment:shift_area_cover_assignment_id(
              id,
              color,
              department:department_id(id, name)
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to local state
          this.shiftAreaCoverPorterAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding porter to shift area cover:', error);
        this.error = 'Failed to add porter to area cover';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Update a shift area cover porter assignment
    async updateShiftAreaCoverPorter(porterAssignmentId, updates) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_area_cover_porter_assignments')
          .update(updates)
          .eq('id', porterAssignmentId)
          .select(`
            *,
            porter:porter_id(id, first_name, last_name),
            shift_area_cover_assignment:shift_area_cover_assignment_id(
              id,
              color,
              department:department_id(id, name)
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update in local state
          const index = this.shiftAreaCoverPorterAssignments.findIndex(pa => pa.id === porterAssignmentId);
          if (index !== -1) {
            this.shiftAreaCoverPorterAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating shift area cover porter assignment:', error);
        this.error = 'Failed to update porter assignment';
        return null;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Remove a porter from a shift area cover assignment
    async removeShiftAreaCoverPorter(porterAssignmentId) {
      this.loading.areaCover = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_area_cover_porter_assignments')
          .delete()
          .eq('id', porterAssignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftAreaCoverPorterAssignments = this.shiftAreaCoverPorterAssignments.filter(
          pa => pa.id !== porterAssignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing porter from shift area cover:', error);
        this.error = 'Failed to remove porter assignment';
        return false;
      } finally {
        this.loading.areaCover = false;
      }
    },
    
    // Fetch support service assignments for a specific shift
    async fetchShiftSupportServices(shiftId) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        console.log(`Fetching support service assignments for shift: ${shiftId}`);
        
        // Query shift support service assignments
        const { data, error } = await supabase
          .from('shift_support_service_assignments')
          .select(`
            *,
            service:service_id(
              id,
              name,
              description
            )
          `)
          .eq('shift_id', shiftId);
        
        if (error) {
          console.error('Error fetching shift support service assignments:', error);
          throw error;
        }
        
        console.log(`Fetched ${data?.length || 0} support service assignments`);
        
        // Store the assignments
        this.shiftSupportServiceAssignments = data || [];
        
        // Also fetch porter assignments for these support service assignments
        const assignmentIds = data?.map(a => a.id) || [];
        
        if (assignmentIds.length > 0) {
          console.log(`Fetching porter assignments for ${assignmentIds.length} support service assignments`);
          
          const { data: porterData, error: porterError } = await supabase
            .from('shift_support_service_porter_assignments')
            .select(`
              *,
              porter:porter_id(id, first_name, last_name)
            `)
            .in('shift_support_service_assignment_id', assignmentIds);
          
          if (porterError) {
            console.error('Error fetching support service porter assignments:', porterError);
            throw porterError;
          }
          
          console.log(`Fetched ${porterData?.length || 0} porter assignments for support services`);
          
          // Store the porter assignments
          this.shiftSupportServicePorterAssignments = porterData || [];
        } else {
          // No support service assignments, so no porter assignments
          this.shiftSupportServicePorterAssignments = [];
        }
        
        return this.shiftSupportServiceAssignments;
      } catch (error) {
        console.error('Error fetching shift support services:', error);
        this.error = 'Failed to load support services';
        return [];
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Add a new support service assignment to a shift
    async addShiftSupportService(shiftId, serviceId, startTime, endTime, color = '#4285F4') {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_support_service_assignments')
          .insert({
            shift_id: shiftId,
            service_id: serviceId,
            start_time: startTime,
            end_time: endTime,
            color: color
          })
          .select(`
            *,
            service:service_id(
              id,
              name,
              description
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to local state
          this.shiftSupportServiceAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding support service to shift:', error);
        this.error = 'Failed to add support service to shift';
        return null;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Update a shift support service assignment
    async updateShiftSupportService(assignmentId, updates) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_support_service_assignments')
          .update(updates)
          .eq('id', assignmentId)
          .select(`
            *,
            service:service_id(
              id,
              name,
              description
            )
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update in local state
          const index = this.shiftSupportServiceAssignments.findIndex(a => a.id === assignmentId);
          if (index !== -1) {
            this.shiftSupportServiceAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating shift support service:', error);
        this.error = 'Failed to update support service';
        return null;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Remove a shift support service assignment
    async removeShiftSupportService(assignmentId) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_support_service_assignments')
          .delete()
          .eq('id', assignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftSupportServiceAssignments = this.shiftSupportServiceAssignments.filter(a => a.id !== assignmentId);
        
        // Also remove all associated porter assignments
        this.shiftSupportServicePorterAssignments = this.shiftSupportServicePorterAssignments.filter(
          pa => pa.shift_support_service_assignment_id !== assignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing shift support service:', error);
        this.error = 'Failed to remove support service';
        return false;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
  // Add a porter to a shift support service assignment
  async addShiftSupportServicePorter(serviceId, porterId, startTime, endTime, agreedAbsence = null) {
    this.loading.supportServices = true;
    this.error = null;
    
    try {
      const { data, error } = await supabase
        .from('shift_support_service_porter_assignments')
        .insert({
          shift_support_service_assignment_id: serviceId,
          porter_id: porterId,
          start_time: startTime,
          end_time: endTime,
          agreed_absence: agreedAbsence
        })
          .select(`
            *,
            porter:porter_id(id, first_name, last_name)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Add to local state
          this.shiftSupportServicePorterAssignments.push(data[0]);
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error adding porter to shift support service:', error);
        this.error = 'Failed to add porter to support service';
        return null;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Update a shift support service porter assignment
    async updateShiftSupportServicePorter(porterAssignmentId, updates) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('shift_support_service_porter_assignments')
          .update(updates)
          .eq('id', porterAssignmentId)
          .select(`
            *,
            porter:porter_id(id, first_name, last_name)
          `);
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Update in local state
          const index = this.shiftSupportServicePorterAssignments.findIndex(pa => pa.id === porterAssignmentId);
          if (index !== -1) {
            this.shiftSupportServicePorterAssignments[index] = data[0];
          }
        }
        
        return data?.[0] || null;
      } catch (error) {
        console.error('Error updating shift support service porter assignment:', error);
        this.error = 'Failed to update porter assignment';
        return null;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
    // Remove a porter from a shift support service assignment
    async removeShiftSupportServicePorter(porterAssignmentId) {
      this.loading.supportServices = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_support_service_porter_assignments')
          .delete()
          .eq('id', porterAssignmentId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftSupportServicePorterAssignments = this.shiftSupportServicePorterAssignments.filter(
          pa => pa.id !== porterAssignmentId
        );
        
        return true;
      } catch (error) {
        console.error('Error removing porter from shift support service:', error);
        this.error = 'Failed to remove porter assignment';
        return false;
      } finally {
        this.loading.supportServices = false;
      }
    },
    
  // Fetch porter pool for a specific shift
  async fetchShiftPorterPool(shiftId) {
    this.loading.porterPool = true;
    this.error = null;
    
    try {
      // Query shift porter pool
      const { data, error } = await supabase
        .from('shift_porter_pool')
        .select(`
          *,
          porter:porter_id(id, first_name, last_name)
        `)
        .eq('shift_id', shiftId);
      
      if (error) {
        console.error('Error fetching shift porter pool:', error);
        throw error;
      }
      
      console.log(`Fetched ${data?.length || 0} porters in pool for shift ${shiftId}`);
      
      // Store the porter pool
      this.shiftPorterPool = data || [];
      
      // Also fetch porter absences for this shift
      await this.fetchShiftPorterAbsences(shiftId);
      
      return this.shiftPorterPool;
    } catch (error) {
      console.error('Error fetching shift porter pool:', error);
      this.error = 'Failed to load shift porter pool';
      return [];
    } finally {
      this.loading.porterPool = false;
    }
  },
  
  // Fetch porter absences for a specific shift
  async fetchShiftPorterAbsences(shiftId) {
    this.loading.porterAbsences = true;
    this.error = null;
    
    try {
      // Query shift porter absences
      const { data, error } = await supabase
        .from('shift_porter_absences')
        .select(`
          *,
          porter:porter_id(id, first_name, last_name)
        `)
        .eq('shift_id', shiftId);
      
      if (error) {
        console.error('Error fetching shift porter absences:', error);
        throw error;
      }
      
      console.log(`Fetched ${data?.length || 0} porter absences for shift ${shiftId}`);
      
      // Store the porter absences
      this.shiftPorterAbsences = data || [];
      
      return this.shiftPorterAbsences;
    } catch (error) {
      console.error('Error fetching shift porter absences:', error);
      this.error = 'Failed to load porter absences';
      return [];
    } finally {
      this.loading.porterAbsences = false;
    }
  },

  // Add a porter to a shift's porter pool
  async addPorterToShift(shiftId, porterId) {
    this.loading.porterPool = true;
    this.error = null;
    
    try {
      // Add porter to shift pool
      const { data, error } = await supabase
        .from('shift_porter_pool')
        .insert({
          shift_id: shiftId,
          porter_id: porterId
        })
        .select(`
          *,
          porter:porter_id(id, first_name, last_name)
        `);
      
      if (error) throw error;
      
      if (data && data.length > 0) {
        // Add to local state
        this.shiftPorterPool.push(data[0]);
      }
      
      return data?.[0] || null;
    } catch (error) {
      console.error('Error adding porter to shift:', error);
      this.error = 'Failed to add porter to shift';
      return null;
    } finally {
      this.loading.porterPool = false;
    }
  },
  
  // Add a scheduled absence for a porter in a shift
  async addPorterAbsenceToShift(absenceData) {
    this.loading.porterAbsences = true;
    this.error = null;
    
    try {
      // Add porter absence
      const { data, error } = await supabase
        .from('shift_porter_absences')
        .insert({
          shift_id: absenceData.shift_id,
          porter_id: absenceData.porter_id,
          start_time: absenceData.start_time,
          end_time: absenceData.end_time,
          absence_reason: absenceData.absence_reason || 'Scheduled Absence'
        })
        .select(`
          *,
          porter:porter_id(id, first_name, last_name)
        `);
      
      if (error) throw error;
      
      if (data && data.length > 0) {
        // Add to local state
        this.shiftPorterAbsences.push(data[0]);
      }
      
      return data?.[0] || null;
    } catch (error) {
      console.error('Error adding porter absence:', error);
      this.error = 'Failed to add porter absence';
      return null;
    } finally {
      this.loading.porterAbsences = false;
    }
  },
  
  // Add a scheduled absence for a porter in a shift (legacy method)
  async addPorterAbsence(shiftId, porterId, startTime, endTime, absenceReason) {
    this.loading.porterAbsences = true;
    this.error = null;
    
    try {
      // Add porter absence
      const { data, error } = await supabase
        .from('shift_porter_absences')
        .insert({
          shift_id: shiftId,
          porter_id: porterId,
          start_time: startTime,
          end_time: endTime,
          absence_reason: absenceReason
        })
        .select(`
          *,
          porter:porter_id(id, first_name, last_name)
        `);
      
      if (error) throw error;
      
      if (data && data.length > 0) {
        // Add to local state
        this.shiftPorterAbsences.push(data[0]);
      }
      
      return data?.[0] || null;
    } catch (error) {
      console.error('Error adding porter absence:', error);
      this.error = 'Failed to add porter absence';
      return null;
    } finally {
      this.loading.porterAbsences = false;
    }
  },
  
  // Update a porter absence
  async updatePorterAbsence(absenceId, updates) {
    this.loading.porterAbsences = true;
    this.error = null;
    
    try {
      const { data, error } = await supabase
        .from('shift_porter_absences')
        .update(updates)
        .eq('id', absenceId)
        .select(`
          *,
          porter:porter_id(id, first_name, last_name)
        `);
      
      if (error) throw error;
      
      if (data && data.length > 0) {
        // Update in local state
        const index = this.shiftPorterAbsences.findIndex(a => a.id === absenceId);
        if (index !== -1) {
          this.shiftPorterAbsences[index] = data[0];
        }
      }
      
      return data?.[0] || null;
    } catch (error) {
      console.error('Error updating porter absence:', error);
      this.error = 'Failed to update porter absence';
      return null;
    } finally {
      this.loading.porterAbsences = false;
    }
  },
  
  // Remove a porter absence
  async removePorterAbsence(absenceId) {
    this.loading.porterAbsences = true;
    this.error = null;
    
    try {
      const { error } = await supabase
        .from('shift_porter_absences')
        .delete()
        .eq('id', absenceId);
      
      if (error) throw error;
      
      // Remove from local state
      this.shiftPorterAbsences = this.shiftPorterAbsences.filter(a => a.id !== absenceId);
      
      return true;
    } catch (error) {
      console.error('Error removing porter absence:', error);
      this.error = 'Failed to remove porter absence';
      return false;
    } finally {
      this.loading.porterAbsences = false;
    }
  },
  
  // Assign a porter to a shift area cover assignment
  async assignPorterToShiftAreaCover(assignmentData) {
    this.loading.areaCover = true;
    this.error = null;
    
    try {
      // Add porter to department assignment
      const { data, error } = await supabase
        .from('shift_area_cover_porter_assignments')
        .insert({
          shift_area_cover_assignment_id: assignmentData.shift_area_cover_assignment_id,
          porter_id: assignmentData.porter_id,
          start_time: assignmentData.start_time,
          end_time: assignmentData.end_time
        })
        .select(`
          *,
          porter:porter_id(id, first_name, last_name),
          shift_area_cover_assignment:shift_area_cover_assignment_id(
            id,
            color,
            department:department_id(id, name)
          )
        `);
      
      if (error) throw error;
      
      if (data && data.length > 0) {
        // Add to local state
        this.shiftAreaCoverPorterAssignments.push(data[0]);
        return data[0];
      }
      
      return null;
    } catch (error) {
      console.error('Error assigning porter to department:', error);
      this.error = 'Failed to assign porter to department';
      return null;
    } finally {
      this.loading.areaCover = false;
    }
  },
  
  // Allocate a porter to a department (legacy method)
  async allocatePorterToDepartment({ porterId, shiftId, departmentAssignmentId, startTime, endTime }) {
    this.loading.areaCover = true;
    this.error = null;
    
    try {
      // Add porter to department assignment
      const { data, error } = await supabase
        .from('shift_area_cover_porter_assignments')
        .insert({
          shift_area_cover_assignment_id: departmentAssignmentId,
          porter_id: porterId,
          start_time: startTime,
          end_time: endTime
        })
        .select(`
          *,
          porter:porter_id(id, first_name, last_name),
          shift_area_cover_assignment:shift_area_cover_assignment_id(
            id,
            color,
            department:department_id(id, name)
          )
        `);
      
      if (error) throw error;
      
      if (data && data.length > 0) {
        // Add to local state
        this.shiftAreaCoverPorterAssignments.push(data[0]);
        return data[0];
      }
      
      return null;
    } catch (error) {
      console.error('Error allocating porter to department:', error);
      this.error = 'Failed to allocate porter to department';
      return null;
    } finally {
      this.loading.areaCover = false;
    }
  },
  
  // Assign a porter to a shift support service assignment
  async assignPorterToShiftSupportService(assignmentData) {
    this.loading.supportServices = true;
    this.error = null;
    
    try {
      // Add porter to service assignment
      const { data, error } = await supabase
        .from('shift_support_service_porter_assignments')
        .insert({
          shift_support_service_assignment_id: assignmentData.shift_support_service_assignment_id,
          porter_id: assignmentData.porter_id,
          start_time: assignmentData.start_time,
          end_time: assignmentData.end_time
        })
        .select(`
          *,
          porter:porter_id(id, first_name, last_name)
        `);
      
      if (error) throw error;
      
      if (data && data.length > 0) {
        // Add to local state
        this.shiftSupportServicePorterAssignments.push(data[0]);
        return data[0];
      }
      
      return null;
    } catch (error) {
      console.error('Error assigning porter to service:', error);
      this.error = 'Failed to assign porter to service';
      return null;
    } finally {
      this.loading.supportServices = false;
    }
  },
  
  // Allocate a porter to a service (legacy method)
  async allocatePorterToService({ porterId, shiftId, serviceAssignmentId, startTime, endTime }) {
    this.loading.supportServices = true;
    this.error = null;
    
    try {
      // Add porter to service assignment
      const { data, error } = await supabase
        .from('shift_support_service_porter_assignments')
        .insert({
          shift_support_service_assignment_id: serviceAssignmentId,
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
        // Add to local state
        this.shiftSupportServicePorterAssignments.push(data[0]);
        return data[0];
      }
      
      return null;
    } catch (error) {
      console.error('Error allocating porter to service:', error);
      this.error = 'Failed to allocate porter to service';
      return null;
    } finally {
      this.loading.supportServices = false;
    }
  },
  
  // Clean up expired porter absences
  async cleanupExpiredAbsences() {
    try {
      // Get current time in HH:MM:SS format
      const now = new Date();
      const hours = String(now.getHours()).padStart(2, '0');
      const minutes = String(now.getMinutes()).padStart(2, '0');
      const seconds = String(now.getSeconds()).padStart(2, '0');
      const currentTime = `${hours}:${minutes}:${seconds}`;
      
      // Find absences with end times in the past
      const expiredAbsences = this.shiftPorterAbsences.filter(
        absence => absence.end_time < currentTime
      );
      
      if (expiredAbsences.length === 0) {
        return 0; // No expired absences to clean up
      }
      
      console.log(`Found ${expiredAbsences.length} expired absences to clean up`);
      
      // Remove each expired absence
      for (const absence of expiredAbsences) {
        await this.removePorterAbsence(absence.id);
      }
      
      console.log(`Cleaned up ${expiredAbsences.length} expired absences`);
      return expiredAbsences.length;
    } catch (error) {
      console.error('Error cleaning up expired absences:', error);
      return 0;
    }
  },
  
  // Clean up expired department assignments
  async cleanupExpiredDepartmentAssignments() {
    try {
      // Get current time in HH:MM:SS format
      const now = new Date();
      const hours = String(now.getHours()).padStart(2, '0');
      const minutes = String(now.getMinutes()).padStart(2, '0');
      const seconds = String(now.getSeconds()).padStart(2, '0');
      const currentTime = `${hours}:${minutes}:${seconds}`;
      
      // Find department assignments with end times in the past
      const expiredAssignments = this.shiftAreaCoverPorterAssignments.filter(
        assignment => assignment.end_time < currentTime
      );
      
      if (expiredAssignments.length === 0) {
        return 0; // No expired assignments to clean up
      }
      
      console.log(`Found ${expiredAssignments.length} expired department assignments to clean up`);
      
      // Remove each expired department assignment
      for (const assignment of expiredAssignments) {
        await this.removeShiftAreaCoverPorter(assignment.id);
      }
      
      console.log(`Cleaned up ${expiredAssignments.length} expired department assignments`);
      return expiredAssignments.length;
    } catch (error) {
      console.error('Error cleaning up expired department assignments:', error);
      return 0;
    }
  },
  
  // Clean up expired service assignments
  async cleanupExpiredServiceAssignments() {
    try {
      // Get current time in HH:MM:SS format
      const now = new Date();
      const hours = String(now.getHours()).padStart(2, '0');
      const minutes = String(now.getMinutes()).padStart(2, '0');
      const seconds = String(now.getSeconds()).padStart(2, '0');
      const currentTime = `${hours}:${minutes}:${seconds}`;
      
      // Find service assignments with end times in the past
      const expiredAssignments = this.shiftSupportServicePorterAssignments.filter(
        assignment => assignment.end_time < currentTime
      );
      
      if (expiredAssignments.length === 0) {
        return 0; // No expired assignments to clean up
      }
      
      console.log(`Found ${expiredAssignments.length} expired service assignments to clean up`);
      
      // Remove each expired service assignment
      for (const assignment of expiredAssignments) {
        await this.removeShiftSupportServicePorter(assignment.id);
      }
      
      console.log(`Cleaned up ${expiredAssignments.length} expired service assignments`);
      return expiredAssignments.length;
    } catch (error) {
      console.error('Error cleaning up expired service assignments:', error);
      return 0;
    }
  },
  
  // Clean up all expired assignments (absences, departments, and services)
  async cleanupAllExpiredAssignments() {
    const cleanedAbsences = await this.cleanupExpiredAbsences();
    const cleanedDepartments = await this.cleanupExpiredDepartmentAssignments();
    const cleanedServices = await this.cleanupExpiredServiceAssignments();
    
    return {
      absences: cleanedAbsences,
      departments: cleanedDepartments,
      services: cleanedServices,
      total: cleanedAbsences + cleanedDepartments + cleanedServices
    };
  },
    
    // Remove a porter from a shift's porter pool
    async removePorterFromShift(porterPoolId) {
      this.loading.porterPool = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('shift_porter_pool')
          .delete()
          .eq('id', porterPoolId);
        
        if (error) throw error;
        
        // Remove from local state
        this.shiftPorterPool = this.shiftPorterPool.filter(p => p.id !== porterPoolId);
        
        return true;
      } catch (error) {
        console.error('Error removing porter from shift:', error);
        this.error = 'Failed to remove porter from shift';
        return false;
      } finally {
        this.loading.porterPool = false;
      }
    },
    
    // Fetch task counts for archived shifts
    async fetchArchivedShiftTaskCounts() {
      this.error = null;
      
      try {
        console.log('Fetching task counts for archived shifts...');
        
        // Get the shift IDs for which we need to fetch task counts
        const shiftIds = this.archivedShifts.map(shift => shift.id);
        
        if (shiftIds.length === 0) {
          console.log('No archived shifts to fetch task counts for');
          return {};
        }

        // We'll try a different approach - fetch all tasks for the archived shifts
        // and then count them manually
        const { data, error } = await supabase
          .from('shift_tasks')
          .select('shift_id')
          .in('shift_id', shiftIds);
        
        if (error) {
          console.error('Error fetching shift tasks:', error);
          throw error;
        }
        
        console.log(`Fetched ${data?.length || 0} tasks for archived shifts`);
        
        // Create a mapping of shift ID to task count by counting tasks manually
        const taskCounts = {};
        
        // Initialize counts for all shifts to 0
        shiftIds.forEach(id => {
          taskCounts[id] = 0;
        });
        
        // Count tasks for each shift
        if (data && data.length > 0) {
          data.forEach(task => {
            if (task.shift_id) {
              taskCounts[task.shift_id] = (taskCounts[task.shift_id] || 0) + 1;
            }
          });
        }
        
        console.log('Task counts:', taskCounts);
        
        // Store the task counts
        this.archivedShiftTaskCounts = taskCounts;
        
        return taskCounts;
      } catch (error) {
        console.error('Error in fetchArchivedShiftTaskCounts:', error);
        this.error = 'Failed to load task counts';
        return {};
      }
    },
    
    // Delete a shift
    async deleteShift(shiftId) {
      this.loading.deleteShift = true;
      this.error = null;
      
      try {
        // Delete the shift
        const { error } = await supabase
          .from('shifts')
          .delete()
          .eq('id', shiftId);
        
        if (error) throw error;
        
        // Remove from local state
        this.archivedShifts = this.archivedShifts.filter(shift => shift.id !== shiftId);
        
        return true;
      } catch (error) {
        console.error('Error deleting shift:', error);
        this.error = 'Failed to delete shift';
        return false;
      } finally {
        this.loading.deleteShift = false;
      }
    },
    
    // Update shift supervisor
    async updateShiftSupervisor(shiftId, supervisorId) {
      this.loading.currentShift = true;
      this.error = null;
      
      try {
        // Update the shift with new supervisor
        const { data, error } = await supabase
          .from('shifts')
          .update({ supervisor_id: supervisorId })
          .eq('id', shiftId)
          .select(`
            *,
            supervisor:supervisor_id(id, first_name, last_name, role)
          `)
          .single();
        
        if (error) throw error;
        
        // Update local state
        if (this.currentShift && this.currentShift.id === shiftId) {
          this.currentShift = data;
        }
        
        // Also update in activeShifts if present
        const activeShiftIndex = this.activeShifts.findIndex(s => s.id === shiftId);
        if (activeShiftIndex !== -1) {
          this.activeShifts[activeShiftIndex] = data;
        }
        
        return data;
      } catch (error) {
        console.error('Error updating shift supervisor:', error);
        this.error = 'Failed to update supervisor';
        return null;
      } finally {
        this.loading.currentShift = false;
      }
    },
    
    // Duplicate a shift (copy all setup but not tasks)
    async duplicateShift(shiftId, newDate) {
      this.loading.createShift = true;
      this.error = null;
      
      try {
        console.log(`Duplicating shift ${shiftId} to date ${newDate}`);
        
        // 1. Get the original shift details
        const { data: origShift, error: shiftError } = await supabase
          .from('shifts')
          .select(`
            *,
            supervisor:supervisor_id(id, first_name, last_name, role)
          `)
          .eq('id', shiftId)
          .single();
        
        if (shiftError) throw shiftError;
        
        if (!origShift) {
          throw new Error('Original shift not found');
        }
        
        // 2. Create a new shift with the same type but new date
        const newDateObj = new Date(newDate);
        
        // Format the date part, keeping the time part from the original shift
        const origDateTime = new Date(origShift.start_time);
        newDateObj.setHours(origDateTime.getHours());
        newDateObj.setMinutes(origDateTime.getMinutes());
        newDateObj.setSeconds(origDateTime.getSeconds());
        
        const newShiftStartTime = newDateObj.toISOString();
        
        const { data: newShiftData, error: createError } = await supabase
          .from('shifts')
          .insert({
            supervisor_id: origShift.supervisor_id,
            shift_type: origShift.shift_type,
            start_time: newShiftStartTime,
            is_active: true
          })
          .select();
        
        if (createError) throw createError;
        
        if (!newShiftData || newShiftData.length === 0) {
          throw new Error('Failed to create new shift');
        }
        
        const newShift = newShiftData[0];
        console.log(`Created new shift with ID: ${newShift.id}`);
        
        // 3. Duplicate porter pool
        console.log('Duplicating porter pool...');
        const { data: porterPool, error: porterPoolError } = await supabase
          .from('shift_porter_pool')
          .select('*')
          .eq('shift_id', shiftId);
          
        if (porterPoolError) throw porterPoolError;
        
        if (porterPool && porterPool.length > 0) {
          // Create porter pool entries for new shift
          const newPorterPoolEntries = porterPool.map(porter => ({
            shift_id: newShift.id,
            porter_id: porter.porter_id
          }));
          
          const { error: insertPorterError } = await supabase
            .from('shift_porter_pool')
            .insert(newPorterPoolEntries);
            
          if (insertPorterError) throw insertPorterError;
          
          console.log(`Duplicated ${porterPool.length} porter pool entries`);
        }
        
        // 4. Duplicate area cover assignments
        console.log('Duplicating area cover assignments...');
        const { data: areaCover, error: areaCoverError } = await supabase
          .from('shift_area_cover_assignments')
          .select('*')
          .eq('shift_id', shiftId);
          
        if (areaCoverError) throw areaCoverError;
        
        // Map to store old area cover assignment ID to new ID
        const areaCoverIdMap = new Map();
        
        if (areaCover && areaCover.length > 0) {
          // Create area cover entries for new shift
          const newAreaCoverEntries = areaCover.map(area => ({
            shift_id: newShift.id,
            department_id: area.department_id,
            start_time: area.start_time,
            end_time: area.end_time,
            color: area.color,
            minimum_porters: area.minimum_porters
          }));
          
          const { data: newAreaCover, error: insertAreaError } = await supabase
            .from('shift_area_cover_assignments')
            .insert(newAreaCoverEntries)
            .select();
            
          if (insertAreaError) throw insertAreaError;
          
          console.log(`Duplicated ${areaCover.length} area cover assignments`);
          
          // Create mapping from old to new area cover assignment IDs
          if (newAreaCover) {
            for (let i = 0; i < areaCover.length; i++) {
              areaCoverIdMap.set(areaCover[i].id, newAreaCover[i].id);
            }
          }
          
          // 5. Duplicate area cover porter assignments
          console.log('Duplicating area cover porter assignments...');
          
          for (const oldAreaId of areaCoverIdMap.keys()) {
            const { data: areaPorters, error: areaPortersError } = await supabase
              .from('shift_area_cover_porter_assignments')
              .select('*')
              .eq('shift_area_cover_assignment_id', oldAreaId);
              
            if (areaPortersError) throw areaPortersError;
            
            if (areaPorters && areaPorters.length > 0) {
              const newAreaId = areaCoverIdMap.get(oldAreaId);
              
              // Create porter assignments for new area cover
              const newAreaPorterEntries = areaPorters.map(porter => ({
                shift_area_cover_assignment_id: newAreaId,
                porter_id: porter.porter_id,
                start_time: porter.start_time,
                end_time: porter.end_time
              }));
              
              const { error: insertAreaPorterError } = await supabase
                .from('shift_area_cover_porter_assignments')
                .insert(newAreaPorterEntries);
                
              if (insertAreaPorterError) throw insertAreaPorterError;
              
              console.log(`Duplicated ${areaPorters.length} porter assignments for area ${oldAreaId}`);
            }
          }
        }
        
        // 6. Duplicate support service assignments
        console.log('Duplicating support service assignments...');
        const { data: services, error: servicesError } = await supabase
          .from('shift_support_service_assignments')
          .select('*')
          .eq('shift_id', shiftId);
          
        if (servicesError) throw servicesError;
        
        // Map to store old service assignment ID to new ID
        const serviceIdMap = new Map();
        
        if (services && services.length > 0) {
          // Create service entries for new shift
          const newServiceEntries = services.map(service => ({
            shift_id: newShift.id,
            service_id: service.service_id,
            start_time: service.start_time,
            end_time: service.end_time,
            color: service.color,
            minimum_porters: service.minimum_porters,
            minimum_porters_mon: service.minimum_porters_mon,
            minimum_porters_tue: service.minimum_porters_tue,
            minimum_porters_wed: service.minimum_porters_wed,
            minimum_porters_thu: service.minimum_porters_thu,
            minimum_porters_fri: service.minimum_porters_fri,
            minimum_porters_sat: service.minimum_porters_sat,
            minimum_porters_sun: service.minimum_porters_sun
          }));
          
          const { data: newServices, error: insertServiceError } = await supabase
            .from('shift_support_service_assignments')
            .insert(newServiceEntries)
            .select();
            
          if (insertServiceError) throw insertServiceError;
          
          console.log(`Duplicated ${services.length} support service assignments`);
          
          // Create mapping from old to new service assignment IDs
          if (newServices) {
            for (let i = 0; i < services.length; i++) {
              serviceIdMap.set(services[i].id, newServices[i].id);
            }
          }
          
          // 7. Duplicate support service porter assignments
          console.log('Duplicating support service porter assignments...');
          
          for (const oldServiceId of serviceIdMap.keys()) {
            const { data: servicePorters, error: servicePortersError } = await supabase
              .from('shift_support_service_porter_assignments')
              .select('*')
              .eq('shift_support_service_assignment_id', oldServiceId);
              
            if (servicePortersError) throw servicePortersError;
            
            if (servicePorters && servicePorters.length > 0) {
              const newServiceId = serviceIdMap.get(oldServiceId);
              
              // Create porter assignments for new service
              const newServicePorterEntries = servicePorters.map(porter => ({
                shift_support_service_assignment_id: newServiceId,
                porter_id: porter.porter_id,
                start_time: porter.start_time,
                end_time: porter.end_time
              }));
              
              const { error: insertServicePorterError } = await supabase
                .from('shift_support_service_porter_assignments')
                .insert(newServicePorterEntries);
                
              if (insertServicePorterError) throw insertServicePorterError;
              
              console.log(`Duplicated ${servicePorters.length} porter assignments for service ${oldServiceId}`);
            }
          }
        }
        
        // Add the new shift to activeShifts array
        if (newShift) {
          // Get the complete shift with supervisor info
          const { data: completeShift, error: fetchError } = await supabase
            .from('shifts')
            .select(`
              *,
              supervisor:supervisor_id(id, first_name, last_name, role)
            `)
            .eq('id', newShift.id)
            .single();
            
          if (!fetchError && completeShift) {
            this.activeShifts.unshift(completeShift);
          }
        }
        
        return newShift;
      } catch (error) {
        console.error('Error duplicating shift:', error);
        this.error = 'Failed to duplicate shift';
        return null;
      } finally {
        this.loading.createShift = false;
      }
    }
  }
});
