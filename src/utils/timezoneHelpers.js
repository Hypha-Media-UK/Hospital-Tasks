/**
 * Simplified timezone helper functions - uses browser timezone automatically
 * All functions now use browser timezone with 24-hour format
 */

/**
 * Format a Date object or time string for display in browser timezone (24h format)
 * @param {Date|string} dateTime - Date object or ISO string to format
 * @param {Object} options - Formatting options
 * @param {boolean} options.includeDate - Whether to include the date part
 * @param {boolean} options.includeTime - Whether to include the time part
 * @param {boolean} options.includeSeconds - Whether to include seconds in time
 * @returns {string} Formatted date/time string
 */
export function formatDateTimeForUser(dateTime, options = {}) {
  if (!dateTime) return '';
  
  const {
    includeDate = true,
    includeTime = true,
    includeSeconds = false
  } = options;
  
  const date = typeof dateTime === 'string' ? new Date(dateTime) : dateTime;
  if (isNaN(date.getTime())) return '';
  
  const formatOptions = {
    hour12: false // Always use 24-hour format
  };
  
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
 * Format a time-only value for display (24h format)
 * @param {Date|string} timeValue - Time value to format
 * @param {boolean} isUTC - Whether the time value is in UTC and needs conversion (legacy parameter, ignored)
 * @returns {string} Formatted time string (HH:MM)
 */
export function formatTimeForUser(timeValue, isUTC = false) {
  if (!timeValue) return '';
  
  // Handle corrupted 'NaN:NaN' values
  if (timeValue === 'NaN:NaN' || timeValue.includes('NaN')) {
    return '';
  }
  
  let hours, minutes;
  
  // Handle Date objects
  if (timeValue instanceof Date) {
    hours = timeValue.getHours();
    minutes = timeValue.getMinutes();
  }
  // Handle ISO datetime strings
  else if (typeof timeValue === 'string' && timeValue.includes('T')) {
    const date = new Date(timeValue);
    if (isNaN(date.getTime())) return '';
    
    hours = date.getHours();
    minutes = date.getMinutes();
  }
  // Handle simple time strings (HH:MM or HH:MM:SS)
  else if (typeof timeValue === 'string') {
    const timeParts = timeValue.split(':');
    if (timeParts.length < 2) return '';
    
    hours = parseInt(timeParts[0], 10);
    minutes = parseInt(timeParts[1], 10);
    
    // Check for invalid numbers
    if (isNaN(hours) || isNaN(minutes)) return '';
  }
  else {
    return '';
  }
  
  // Validate hours and minutes are within valid ranges
  if (isNaN(hours) || isNaN(minutes) || hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
    return '';
  }
  
  // Always return 24-hour format
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

/**
 * Format a time value for HTML time input (always HH:MM format)
 * @param {Date|string} timeValue - Time value to format
 * @returns {string} Time in HH:MM format for input fields
 */
export function formatTimeForInput(timeValue) {
  if (!timeValue) return '';
  
  let hours, minutes;
  
  // Handle Date objects
  if (timeValue instanceof Date) {
    hours = timeValue.getHours();
    minutes = timeValue.getMinutes();
  }
  // Handle ISO datetime strings
  else if (typeof timeValue === 'string' && timeValue.includes('T')) {
    const date = new Date(timeValue);
    if (isNaN(date.getTime())) return '';
    hours = date.getHours();
    minutes = date.getMinutes();
  }
  // Handle simple time strings (HH:MM or HH:MM:SS)
  else if (typeof timeValue === 'string') {
    [hours, minutes] = timeValue.split(':').map(Number);
  }
  else {
    return '';
  }
  
  if (isNaN(hours) || isNaN(minutes)) return '';
  
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

/**
 * Get current date/time formatted for the user's browser timezone
 * @param {Object} options - Formatting options (same as formatDateTimeForUser)
 * @returns {string} Current date/time formatted for user
 */
export function getCurrentDateTimeForUser(options = {}) {
  return formatDateTimeForUser(new Date(), options);
}

/**
 * Format a date for display in browser timezone (date only, no time)
 * @param {Date|string} date - Date to format
 * @returns {string} Formatted date string
 */
export function formatDateForUser(date) {
  return formatDateTimeForUser(date, { includeDate: true, includeTime: false });
}

/**
 * Format a date for HTML date input (YYYY-MM-DD format)
 * @param {Date|string} date - Date to format
 * @returns {string} Date in YYYY-MM-DD format
 */
export function formatDateForInput(date) {
  if (!date) return '';
  
  const dateObj = typeof date === 'string' ? new Date(date) : date;
  if (isNaN(dateObj.getTime())) return '';
  
  // Get the date in browser timezone
  const year = dateObj.getFullYear();
  const month = String(dateObj.getMonth() + 1).padStart(2, '0');
  const day = String(dateObj.getDate()).padStart(2, '0');
  
  return `${year}-${month}-${day}`;
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
 * Convert a time string to UTC for database storage (legacy function, now simplified)
 * @param {string} timeString - Time in HH:MM format
 * @returns {string} Time in HH:MM format (no conversion needed for browser-based approach)
 */
export function convertTimeToUTC(timeString) {
  // In the simplified approach, we don't need timezone conversion
  // Times are handled in browser timezone
  return timeString || '';
}

/**
 * Convert a UTC time string to user's timezone for display (legacy function, now simplified)
 * @param {string} utcTimeString - Time in HH:MM format
 * @returns {string} Time in HH:MM format (no conversion needed for browser-based approach)
 */
export function convertTimeFromUTC(utcTimeString) {
  // In the simplified approach, we don't need timezone conversion
  // Times are handled in browser timezone
  return utcTimeString || '';
}
