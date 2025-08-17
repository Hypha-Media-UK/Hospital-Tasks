/**
 * Shared utilities for porter assignment operations in frontend
 * Provides DRY functionality for both area cover and support service assignments
 */

import { computed } from 'vue';

/**
 * Configuration for different assignment types
 */
export const ASSIGNMENT_CONFIGS = {
  areaCover: {
    type: 'area cover',
    assignmentIdField: 'shift_area_cover_assignment_id',
    entityName: 'department',
    entityField: 'department',
    entityNameField: 'name'
  },
  supportService: {
    type: 'support service',
    assignmentIdField: 'shift_support_service_assignment_id',
    entityName: 'service',
    entityField: 'service',
    entityNameField: 'name'
  }
};

/**
 * Shared porter assignment logic for components
 */
export function usePorterAssignments(assignment, config, shiftsStore, staffStore) {
  // Get porter assignments for this assignment
  const porterAssignments = computed(() => {
    if (config.type === 'area cover') {
      return shiftsStore.getPorterAssignmentsByAreaCoverId(assignment.value.id) || [];
    } else {
      return shiftsStore.getPorterAssignmentsByServiceId(assignment.value.id) || [];
    }
  });

  // Sort porter assignments by start time
  const sortedPorterAssignments = computed(() => {
    return [...porterAssignments.value].sort((a, b) => {
      const aStart = timeToMinutes(a.start_time);
      const bStart = timeToMinutes(b.start_time);
      return aStart - bStart;
    });
  });

  // Get available (non-absent) porters
  const availablePorters = computed(() => {
    const shift = shiftsStore.currentShift;
    const isSetupMode = shiftsStore.isShiftInSetupMode ? shiftsStore.isShiftInSetupMode(shift) : false;
    
    return porterAssignments.value.filter(assignment => {
      if (isSetupMode) {
        return true; // Show all porters in setup mode
      }
      
      const absence = staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date());
      return !absence; // Only show non-absent porters in active mode
    });
  });

  // Get absent porters
  const absentPorters = computed(() => {
    return porterAssignments.value.filter(assignment => {
      const absence = staffStore.getPorterAbsenceDetails(assignment.porter_id, new Date());
      return absence; // Only show absent porters
    });
  });

  // Check for coverage gaps
  const hasCoverageGap = computed(() => {
    try {
      if (config.type === 'area cover') {
        return shiftsStore.hasAreaCoverageGap(assignment.value.id);
      } else {
        return shiftsStore.hasServiceCoverageGap(assignment.value.id);
      }
    } catch (error) {
      return false;
    }
  });

  // Get coverage gaps with details
  const coverageGaps = computed(() => {
    try {
      if (config.type === 'area cover') {
        return shiftsStore.getAreaCoverageGaps(assignment.value.id);
      } else {
        return shiftsStore.getServiceCoverageGaps(assignment.value.id);
      }
    } catch (error) {
      return { hasGap: false, gaps: [] };
    }
  });

  // Check if there's a gap at the start
  const hasStartGap = computed(() => {
    if (sortedPorterAssignments.value.length === 0) return true;
    
    const serviceStart = timeToMinutes(assignment.value.start_time);
    const firstPorterStart = timeToMinutes(sortedPorterAssignments.value[0].start_time);
    
    return firstPorterStart > serviceStart;
  });

  // Check if there's a gap at the end
  const hasEndGap = computed(() => {
    if (sortedPorterAssignments.value.length === 0) return true;
    
    const serviceEnd = timeToMinutes(assignment.value.end_time);
    const lastPorterEnd = timeToMinutes(sortedPorterAssignments.value[sortedPorterAssignments.value.length - 1].end_time);
    
    return lastPorterEnd < serviceEnd;
  });

  // Helper functions
  const getPorterAbsence = (porterId) => {
    return staffStore.getPorterAbsenceDetails(porterId, new Date());
  };

  const hasGapBetween = (assignment1, assignment2) => {
    const end1 = timeToMinutes(assignment1.end_time);
    const start2 = timeToMinutes(assignment2.start_time);
    return start2 > end1;
  };

  const getGapsBetweenAssignments = (assignment1, assignment2) => {
    const end1 = timeToMinutes(assignment1.end_time);
    const start2 = timeToMinutes(assignment2.start_time);
    
    if (start2 > end1) {
      return [{
        startTime: minutesToTime(end1),
        endTime: minutesToTime(start2)
      }];
    }
    
    return [];
  };

  return {
    porterAssignments,
    sortedPorterAssignments,
    availablePorters,
    absentPorters,
    hasCoverageGap,
    coverageGaps,
    hasStartGap,
    hasEndGap,
    getPorterAbsence,
    hasGapBetween,
    getGapsBetweenAssignments
  };
}

/**
 * Shared porter assignment actions
 */
export function usePorterAssignmentActions(config, shiftsStore) {
  const addPorterAssignment = async (assignmentId, porterData) => {
    if (config.type === 'area cover') {
      return await shiftsStore.addShiftAreaCoverPorter(assignmentId, porterData.porter_id, porterData.start_time, porterData.end_time);
    } else {
      return await shiftsStore.addShiftSupportServicePorter(assignmentId, porterData.porter_id, porterData.start_time, porterData.end_time);
    }
  };

  const updatePorterAssignment = async (assignmentId, updates) => {
    if (config.type === 'area cover') {
      return await shiftsStore.updateShiftAreaCoverPorter(assignmentId, updates);
    } else {
      return await shiftsStore.updateShiftSupportServicePorter(assignmentId, updates);
    }
  };

  const removePorterAssignment = async (assignmentId) => {
    if (config.type === 'area cover') {
      return await shiftsStore.removeShiftAreaCoverPorter(assignmentId);
    } else {
      return await shiftsStore.removeShiftSupportServicePorter(assignmentId);
    }
  };

  return {
    addPorterAssignment,
    updatePorterAssignment,
    removePorterAssignment
  };
}

/**
 * Shared time utility functions
 */
export function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(':').map(Number);
  return hours * 60 + minutes;
}

export function minutesToTime(minutes) {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`;
}

export function formatTime(timeStr) {
  if (!timeStr) return '';
  return timeStr.substring(0, 5); // Extract HH:MM from HH:MM:SS
}

export function formatTimeRange(startTime, endTime) {
  if (!startTime || !endTime) return '';
  return `${formatTime(startTime)} - ${formatTime(endTime)}`;
}

/**
 * Shared validation functions
 */
export function validatePorterAssignmentForm(form) {
  const errors = [];
  
  if (!form.porterId) {
    errors.push('Porter is required');
  }
  
  if (!form.startTime) {
    errors.push('Start time is required');
  }
  
  if (!form.endTime) {
    errors.push('End time is required');
  }
  
  if (form.startTime && form.endTime) {
    const startMinutes = timeToMinutes(form.startTime);
    const endMinutes = timeToMinutes(form.endTime);
    
    if (startMinutes >= endMinutes) {
      errors.push('End time must be after start time');
    }
  }
  
  return {
    isValid: errors.length === 0,
    errors
  };
}

/**
 * Shared modal state management
 */
export function useModalState() {
  const showModal = ref(false);
  const editingAssignment = ref(null);
  
  const openModal = (assignment = null) => {
    editingAssignment.value = assignment;
    showModal.value = true;
  };
  
  const closeModal = () => {
    showModal.value = false;
    editingAssignment.value = null;
  };
  
  return {
    showModal,
    editingAssignment,
    openModal,
    closeModal
  };
}
