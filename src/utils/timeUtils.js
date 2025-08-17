/**
 * Unified Time Utilities
 * Consolidates all time-related functions from across the application
 */

/**
 * Convert time string to minutes since midnight
 * @param {string|Date} timeStr - Time in HH:MM:SS, HH:MM format, or Date object
 * @param {Object} options - Configuration options
 * @param {boolean} options.handleNightShift - For night shifts, add 24 hours to times after midnight
 * @returns {number} Minutes since midnight (0-1439, or higher for night shifts)
 */
export function timeToMinutes(timeStr, options = {}) {
  if (!timeStr) return 0;

  // Handle Date objects (from MySQL/Prisma)
  if (timeStr instanceof Date) {
    const timeString = timeStr.toTimeString().substring(0, 8); // Extract HH:MM:SS from time string
    const [hours, minutes] = timeString.split(':').map(Number);
    let totalMinutes = (hours * 60) + minutes;

    // For night shifts, adjust times after midnight to ensure consistent calculation
    if (options.handleNightShift && hours < 12) {
      totalMinutes += 24 * 60; // Add 24 hours worth of minutes
    }

    return totalMinutes;
  }

  // Handle ISO datetime strings (e.g., "1970-01-01T08:00:00.000Z")
  if (typeof timeStr === 'string' && timeStr.includes('T')) {
    const date = new Date(timeStr);
    const timeString = date.toTimeString().substring(0, 8); // Extract HH:MM:SS from time string
    const [hours, minutes] = timeString.split(':').map(Number);
    let totalMinutes = (hours * 60) + minutes;

    // For night shifts, adjust times after midnight to ensure consistent calculation
    if (options.handleNightShift && hours < 12) {
      totalMinutes += 24 * 60; // Add 24 hours worth of minutes
    }

    return totalMinutes;
  }

  // Handle simple time strings (e.g., "08:00:00" or "08:00")
  if (typeof timeStr === 'string') {
    const [hours, minutes] = timeStr.split(':').map(Number);
    let totalMinutes = (hours * 60) + minutes;

    // For night shifts, adjust times after midnight to ensure consistent calculation
    if (options.handleNightShift && hours < 12) {
      totalMinutes += 24 * 60; // Add 24 hours worth of minutes
    }

    return totalMinutes;
  }

  return 0;
}

/**
 * Convert minutes back to time string
 * @param {number} minutes - Minutes since midnight
 * @param {Object} options - Formatting options
 * @param {boolean} options.includeSeconds - Include seconds in output (default: true)
 * @param {boolean} options.format24h - Use 24-hour format (default: true)
 * @returns {string} Time in HH:MM:SS or HH:MM format
 */
export function minutesToTime(minutes, options = {}) {
  const { includeSeconds = true, format24h = true } = options;
  
  // Handle values over 24 hours (for night shifts)
  const normalizedMinutes = minutes % (24 * 60);
  
  const hours = Math.floor(normalizedMinutes / 60);
  const mins = normalizedMinutes % 60;
  
  const formattedHours = String(hours).padStart(2, '0');
  const formattedMins = String(mins).padStart(2, '0');
  
  if (includeSeconds) {
    return `${formattedHours}:${formattedMins}:00`;
  }
  
  return `${formattedHours}:${formattedMins}`;
}

/**
 * Format time for display (unified function replacing multiple implementations)
 * @param {Date|string} timeValue - Time to format
 * @param {Object} options - Formatting options
 * @param {boolean} options.includeSeconds - Include seconds in output
 * @param {boolean} options.format24h - Use 24-hour format
 * @returns {string} Formatted time string
 */
export function formatTimeForDisplay(timeValue, options = {}) {
  const { includeSeconds = false, format24h = true } = options;
  
  if (!timeValue) return '';
  
  if (timeValue instanceof Date) {
    const formatOptions = { 
      hour12: !format24h, 
      hour: '2-digit', 
      minute: '2-digit' 
    };
    
    if (includeSeconds) {
      formatOptions.second = '2-digit';
    }
    
    return timeValue.toLocaleTimeString('en-GB', formatOptions);
  }
  
  // Handle time strings (HH:MM or HH:MM:SS)
  if (typeof timeValue === 'string') {
    if (includeSeconds && timeValue.length === 5) {
      return `${timeValue}:00`; // Add seconds if not present
    }
    return includeSeconds ? timeValue : timeValue.substring(0, 5); // Extract HH:MM part
  }
  
  return '';
}

/**
 * Get current time in minutes since midnight
 * @returns {number} Minutes since midnight (0-1439)
 */
export function getCurrentTimeInMinutes() {
  const now = new Date();
  return (now.getHours() * 60) + now.getMinutes();
}

/**
 * Check if two dates are on the same day
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
 * Format date/time for display in browser timezone
 * @param {Date|string} dateTime - Date to format
 * @param {Object} options - Formatting options
 * @param {boolean} options.includeDate - Include date in output (default: true)
 * @param {boolean} options.includeTime - Include time in output (default: true)
 * @param {boolean} options.includeSeconds - Include seconds in output (default: false)
 * @param {boolean} options.format24h - Use 24-hour format (default: true)
 * @returns {string} Formatted date/time string
 */
export function formatDateTimeForUser(dateTime, options = {}) {
  const {
    includeDate = true,
    includeTime = true,
    includeSeconds = false,
    format24h = true
  } = options;
  
  if (!dateTime) return '';
  
  const date = typeof dateTime === 'string' ? new Date(dateTime) : dateTime;
  if (isNaN(date.getTime())) return '';
  
  const formatOptions = { hour12: !format24h };
  
  if (includeDate) {
    formatOptions.year = 'numeric';
    formatOptions.month = '2-digit';
    formatOptions.day = '2-digit';
  }
  
  if (includeTime) {
    formatOptions.hour = '2-digit';
    formatOptions.minute = '2-digit';
    if (includeSeconds) {
      formatOptions.second = '2-digit';
    }
  }
  
  return date.toLocaleString('en-GB', formatOptions);
}

/**
 * Format date for display (date only)
 * @param {Date|string} date - Date to format
 * @returns {string} Formatted date string
 */
export function formatDateForUser(date) {
  return formatDateTimeForUser(date, { includeDate: true, includeTime: false });
}

/**
 * Get current date/time formatted for user
 * @param {Object} options - Formatting options
 * @returns {string} Current date/time formatted
 */
export function getCurrentDateTimeForUser(options = {}) {
  return formatDateTimeForUser(new Date(), options);
}

/**
 * Get the current date/time
 * @returns {Date} Current date/time in browser timezone
 */
export function getCurrentDateTime() {
  return new Date();
}
