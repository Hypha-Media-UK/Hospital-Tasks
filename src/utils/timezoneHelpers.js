/**
 * Simple browser-based timezone helpers
 * All functions use browser timezone with 24-hour format
 */

/**
 * Format date/time for display in browser timezone (24h format)
 * @param {Date|string} dateTime - Date to format
 * @param {Object} options - Formatting options
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
  
  const formatOptions = { hour12: false };
  
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
 * Format time for display (24h format)
 * @param {Date|string} timeValue - Time to format
 * @returns {string} Time in HH:MM format
 */
export function formatTimeForUser(timeValue) {
  if (!timeValue) return '';
  
  if (timeValue instanceof Date) {
    return timeValue.toLocaleTimeString('en-GB', { 
      hour12: false, 
      hour: '2-digit', 
      minute: '2-digit' 
    });
  }
  
  // Handle time strings
  if (typeof timeValue === 'string') {
    return timeValue.substring(0, 5); // Extract HH:MM part
  }
  
  return '';
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
 * Format date for display (date only)
 * @param {Date|string} date - Date to format
 * @returns {string} Formatted date string
 */
export function formatDateForUser(date) {
  return formatDateTimeForUser(date, { includeDate: true, includeTime: false });
}
