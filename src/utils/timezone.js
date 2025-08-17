/**
 * Simplified timezone utilities - uses browser timezone automatically
 * Replaces complex timezone handling with browser-based functions
 */

/**
 * Get the current date/time - returns current Date object
 * @returns {Date} Date object representing current time
 */
export function getCurrentDateTime() {
  return new Date();
}

/**
 * Get the current time in minutes since midnight in the user's browser timezone
 * @returns {number} Minutes since midnight (0-1439)
 */
export function getCurrentTimeInMinutes() {
  const now = new Date();
  return (now.getHours() * 60) + now.getMinutes();
}

/**
 * Get the current date (date only, no time)
 * @returns {Date} Date object with time set to midnight
 */
export function getCurrentDate() {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

/**
 * Convert a date to the user's browser timezone (no-op since dates are already in browser timezone)
 * @param {Date|string} date - Date to convert
 * @returns {Date} Date in browser timezone
 */
export function convertToUserTimezone(date) {
  if (!date) return null;
  return typeof date === 'string' ? new Date(date) : date;
}

/**
 * Check if two dates are on the same day in the user's browser timezone
 * @param {Date|string} date1 
 * @param {Date|string} date2 
 * @returns {boolean}
 */
export function isSameDay(date1, date2) {
  const d1 = new Date(date1);
  const d2 = new Date(date2);
  
  return d1.getFullYear() === d2.getFullYear() &&
         d1.getMonth() === d2.getMonth() &&
         d1.getDate() === d2.getDate();
}

/**
 * Format a time string for display (always 24-hour format)
 * @param {string} timeString - Time in HH:MM or HH:MM:SS format
 * @returns {string} Formatted time string in 24h format
 */
export function formatTimeForDisplay(timeString) {
  if (!timeString) return '';
  
  // Extract hours and minutes from time string
  const [hours, minutes] = timeString.split(':').map(Number);
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

/**
 * Get current time as HH:MM string in browser timezone
 * @returns {string} Current time in HH:MM format (24h)
 */
export function getCurrentTimeString() {
  return new Date().toLocaleTimeString('en-GB', {
    hour12: false,
    hour: '2-digit',
    minute: '2-digit'
  });
}

/**
 * Get current time as HH:MM:SS string in browser timezone
 * @returns {string} Current time in HH:MM:SS format (24h)
 */
export function getCurrentTimeStringWithSeconds() {
  return new Date().toLocaleTimeString('en-GB', {
    hour12: false,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
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
 * Assumes stored times are in BST and converts to user's browser timezone
 * @param {Date|string} shiftDate - The date of the shift
 * @param {string} shiftType - The shift type (week_day, week_night, etc.)
 * @returns {Date} The actual start datetime for the shift
 */
export function createShiftStartDateTime(shiftDate, shiftType) {
  // This function now needs to work without settings store
  // For now, return null - will be updated when we handle shift defaults
  return null;
}

/**
 * Create a shift end datetime based on shift date and configured shift times
 * Assumes stored times are in BST and converts to user's browser timezone
 * @param {Date|string} shiftDate - The date of the shift
 * @param {string} shiftType - The shift type (week_day, week_night, etc.)
 * @returns {Date} The actual end datetime for the shift
 */
export function createShiftEndDateTime(shiftDate, shiftType) {
  // This function now needs to work without settings store
  // For now, return null - will be updated when we handle shift defaults
  return null;
}

/**
 * Check if current time is within the shift access window (1 hour before start to end)
 * @param {Date|string} shiftDate - The date of the shift
 * @param {string} shiftType - The shift type (week_day, week_night, etc.)
 * @returns {boolean} True if tasks can be added to this shift
 */
export function isShiftAccessible(shiftDate, shiftType) {
  // Simplified - for now always return true, will be updated with shift handling
  return true;
}

/**
 * Check if current time is within the shift access window for an existing shift object
 * @param {Object} shift - The shift object with shift_date and shift_type
 * @returns {boolean} True if tasks can be added to this shift
 */
export function isShiftObjectAccessible(shift) {
  if (!shift) return false;
  
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
  // Simplified - will be updated with proper shift handling
  return false;
}

/**
 * Convert BST time to user's browser timezone
 * @param {string|Date} bstTime - Time in BST
 * @returns {Date} Time converted to browser timezone
 */
export function convertFromBST(bstTime) {
  if (!bstTime) return null;
  
  // Create date assuming BST (UTC+1)
  const date = new Date(bstTime);
  
  // If it's a time-only string, create a date for today
  if (typeof bstTime === 'string' && bstTime.match(/^\d{2}:\d{2}(:\d{2})?$/)) {
    const today = new Date();
    const [hours, minutes, seconds = 0] = bstTime.split(':').map(Number);
    
    // Create BST time (UTC+1)
    const bstDate = new Date(Date.UTC(
      today.getFullYear(),
      today.getMonth(),
      today.getDate(),
      hours - 1, // Subtract 1 hour to convert from BST to UTC
      minutes,
      seconds
    ));
    
    return bstDate;
  }
  
  return date;
}
