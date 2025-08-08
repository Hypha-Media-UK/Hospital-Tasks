/**
 * Timezone-aware utility functions
 * This module provides centralized timezone handling for the entire application
 */

import { useSettingsStore } from '../stores/settingsStore';

/**
 * Get the current date/time - always returns UTC Date object
 * @returns {Date} Date object representing current time in UTC
 */
export function getCurrentDateTime() {
  // Always return current UTC time - Date objects are inherently UTC
  return new Date();
}

/**
 * Get the current time in minutes since midnight in the user's timezone
 * @returns {number} Minutes since midnight (0-1439)
 */
export function getCurrentTimeInMinutes() {
  const settingsStore = useSettingsStore();
  const timezone = settingsStore.appSettings.timezone;
  const now = new Date();
  
  // Get current time in the user's timezone
  const timeInTimezone = now.toLocaleString('en-CA', {
    timeZone: timezone === 'GMT' ? 'UTC' : timezone,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });
  
  const [hours, minutes] = timeInTimezone.split(':').map(Number);
  return (hours * 60) + minutes;
}

/**
 * Get the current date in the user's timezone
 * @returns {Date} Date object with time set to midnight in user's timezone
 */
export function getCurrentDate() {
  const now = getCurrentDateTime();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

/**
 * Convert a date to the user's timezone
 * @param {Date|string} date - Date to convert
 * @returns {Date} Date adjusted for user's timezone
 */
export function convertToUserTimezone(date) {
  const settingsStore = useSettingsStore();
  const timezone = settingsStore.appSettings.timezone;
  
  if (!date) return null;
  
  const inputDate = typeof date === 'string' ? new Date(date) : date;
  
  if (timezone === 'UTC') {
    return inputDate;
  }
  
  try {
    // Get the time in the target timezone as a string
    const timeInTimezone = inputDate.toLocaleString('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    });
    
    // Parse the timezone-adjusted time back into a Date object
    // Format will be: "2025-06-26, 03:08:12"
    const cleanedTime = timeInTimezone.replace(', ', 'T');
    const adjustedDate = new Date(cleanedTime);
    
    // Verify the date is valid
    if (isNaN(adjustedDate.getTime())) {
      console.warn(`Failed to parse timezone-adjusted date: ${timeInTimezone}, falling back to original date`);
      return inputDate;
    }
    
    return adjustedDate;
  } catch (error) {
    console.warn(`Invalid timezone: ${timezone}, falling back to original date`, error);
    return inputDate;
  }
}

/**
 * Check if two dates are on the same day in the user's timezone
 * @param {Date|string} date1 
 * @param {Date|string} date2 
 * @returns {boolean}
 */
export function isSameDay(date1, date2) {
  const d1 = convertToUserTimezone(date1);
  const d2 = convertToUserTimezone(date2);
  
  return d1.getFullYear() === d2.getFullYear() &&
         d1.getMonth() === d2.getMonth() &&
         d1.getDate() === d2.getDate();
}

/**
 * Format a time string for display based on user preferences
 * @param {string} timeString - Time in HH:MM or HH:MM:SS format
 * @returns {string} Formatted time string
 */
export function formatTimeForDisplay(timeString) {
  if (!timeString) return '';
  
  const settingsStore = useSettingsStore();
  const timeFormat = settingsStore.appSettings.timeFormat;
  
  // Extract hours and minutes from time string
  const [hours, minutes] = timeString.split(':').map(Number);
  
  if (timeFormat === '12h') {
    const period = hours >= 12 ? 'PM' : 'AM';
    const displayHours = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
    return `${displayHours}:${String(minutes).padStart(2, '0')} ${period}`;
  } else {
    return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
  }
}

/**
 * Get current time as HH:MM string in user's timezone
 * @returns {string} Current time in HH:MM format
 */
export function getCurrentTimeString() {
  const settingsStore = useSettingsStore();
  const timezone = settingsStore.appSettings.timezone;
  const now = new Date();
  
  // Get current time in the user's timezone
  const timeInTimezone = now.toLocaleString('en-CA', {
    timeZone: timezone === 'GMT' ? 'UTC' : timezone,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });
  
  return timeInTimezone;
}

/**
 * Get current time as HH:MM:SS string in user's timezone
 * @returns {string} Current time in HH:MM:SS format
 */
export function getCurrentTimeStringWithSeconds() {
  const settingsStore = useSettingsStore();
  const timezone = settingsStore.appSettings.timezone;
  const now = new Date();
  
  // Get current time in the user's timezone
  const timeInTimezone = now.toLocaleString('en-CA', {
    timeZone: timezone === 'GMT' ? 'UTC' : timezone,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
  
  return timeInTimezone;
}

/**
 * Convert time string to minutes since midnight
 * @param {string} timeStr - Time in HH:MM or HH:MM:SS format
 * @returns {number} Minutes since midnight
 */
export function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  const [hours, minutes] = timeStr.split(':').map(Number);
  return (hours * 60) + minutes;
}

/**
 * Convert minutes since midnight to time string
 * @param {number} minutes - Minutes since midnight
 * @returns {string} Time in HH:MM:SS format
 */
export function minutesToTime(minutes) {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}:00`;
}

/**
 * Create a shift start datetime based on shift date and configured shift times
 * @param {Date|string} shiftDate - The date of the shift
 * @param {string} shiftType - The shift type (week_day, week_night, etc.)
 * @returns {Date} The actual start datetime for the shift in UTC
 */
export function createShiftStartDateTime(shiftDate, shiftType) {
  const settingsStore = useSettingsStore();
  const shiftDefaults = settingsStore.shiftDefaultsByType[shiftType];
  
  if (!shiftDefaults || !shiftDefaults.start_time) {
    console.warn(`No shift defaults found for type: ${shiftType}`);
    return null;
  }
  
  // Get the base date (either from shift_date or start_time)
  const baseDate = new Date(shiftDate);
  if (isNaN(baseDate.getTime())) {
    console.warn('Invalid shift date:', shiftDate);
    return null;
  }
  
  // Parse the start time from database format (Date object)
  const startTime = new Date(shiftDefaults.start_time);
  const hours = startTime.getUTCHours();
  const minutes = startTime.getUTCMinutes();
  
  // Create the shift start datetime - use the date from the shift but set the time from settings
  const shiftStart = new Date(baseDate);
  shiftStart.setUTCHours(hours, minutes, 0, 0);
  
  return shiftStart;
}

/**
 * Create a shift end datetime based on shift date and configured shift times
 * @param {Date|string} shiftDate - The date of the shift
 * @param {string} shiftType - The shift type (week_day, week_night, etc.)
 * @returns {Date} The actual end datetime for the shift in UTC
 */
export function createShiftEndDateTime(shiftDate, shiftType) {
  const settingsStore = useSettingsStore();
  const shiftDefaults = settingsStore.shiftDefaultsByType[shiftType];
  
  if (!shiftDefaults || !shiftDefaults.end_time) {
    console.warn(`No shift defaults found for type: ${shiftType}`);
    return null;
  }
  
  // Get the base date (either from shift_date or start_time)
  const baseDate = new Date(shiftDate);
  if (isNaN(baseDate.getTime())) {
    console.warn('Invalid shift date:', shiftDate);
    return null;
  }
  
  // Parse the end time from database format (Date object)
  const endTime = new Date(shiftDefaults.end_time);
  const hours = endTime.getUTCHours();
  const minutes = endTime.getUTCMinutes();
  
  // Create the shift end datetime - use the date from the shift but set the time from settings
  const shiftEnd = new Date(baseDate);
  shiftEnd.setUTCHours(hours, minutes, 0, 0);
  
  // Handle night shifts that end the next day
  const startTime = new Date(shiftDefaults.start_time);
  const startHours = startTime.getUTCHours();
  
  if (hours < startHours) {
    // End time is next day (e.g., night shift ending at 08:00)
    shiftEnd.setUTCDate(shiftEnd.getUTCDate() + 1);
  }
  
  return shiftEnd;
}

/**
 * Check if current time is within the shift access window (1 hour before start to end)
 * @param {Date|string} shiftDate - The date of the shift
 * @param {string} shiftType - The shift type (week_day, week_night, etc.)
 * @returns {boolean} True if tasks can be added to this shift
 */
export function isShiftAccessible(shiftDate, shiftType) {
  const now = getCurrentDateTime();
  
  const shiftStart = createShiftStartDateTime(shiftDate, shiftType);
  const shiftEnd = createShiftEndDateTime(shiftDate, shiftType);
  
  if (!shiftStart || !shiftEnd) {
    console.warn('Could not determine shift times for accessibility check');
    return false;
  }
  
  // Calculate 1 hour before shift start
  const accessStart = new Date(shiftStart.getTime() - (60 * 60 * 1000)); // 1 hour before
  
  // Check if current time is within the access window
  const isAccessible = now >= accessStart && now <= shiftEnd;
  
  console.log(`Shift accessibility check:`, {
    now: now.toISOString(),
    shiftStart: shiftStart.toISOString(),
    shiftEnd: shiftEnd.toISOString(),
    accessStart: accessStart.toISOString(),
    isAccessible
  });
  
  return isAccessible;
}

/**
 * Check if current time is within the shift access window for an existing shift object
 * @param {Object} shift - The shift object with shift_date and shift_type
 * @returns {boolean} True if tasks can be added to this shift
 */
export function isShiftObjectAccessible(shift) {
  if (!shift) return false;
  
  // Use shift_date if available, otherwise fall back to start_time
  const shiftDate = shift.shift_date || shift.start_time;
  const shiftType = shift.shift_type;
  
  return isShiftAccessible(shiftDate, shiftType);
}

/**
 * Check if a shift is currently in setup mode (before actual shift start time)
 * @param {Date|string} shiftDate - The date of the shift
 * @param {string} shiftType - The shift type (week_day, week_night, etc.)
 * @returns {boolean} True if shift is in setup mode
 */
export function isShiftInSetupMode(shiftDate, shiftType) {
  const now = getCurrentDateTime();
  const shiftStart = createShiftStartDateTime(shiftDate, shiftType);
  
  if (!shiftStart) {
    console.warn('Could not determine shift start time for setup mode check');
    return false;
  }
  
  return now < shiftStart;
}
