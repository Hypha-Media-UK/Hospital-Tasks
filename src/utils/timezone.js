/**
 * Simple browser-based timezone utilities
 * All times use the user's browser timezone automatically
 */

/**
 * Get the current date/time
 * @returns {Date} Current date/time in browser timezone
 */
export function getCurrentDateTime() {
  return new Date();
}

/**
 * Get the current time in minutes since midnight
 * @returns {number} Minutes since midnight (0-1439)
 */
export function getCurrentTimeInMinutes() {
  const now = new Date();
  return (now.getHours() * 60) + now.getMinutes();
}

/**
 * Format time for display (24-hour format)
 * @param {string|Date} timeValue - Time to format
 * @returns {string} Time in HH:MM format
 */
export function formatTimeForDisplay(timeValue) {
  if (!timeValue) return '';
  
  if (timeValue instanceof Date) {
    return timeValue.toLocaleTimeString('en-GB', { 
      hour12: false, 
      hour: '2-digit', 
      minute: '2-digit' 
    });
  }
  
  // Handle time strings (HH:MM or HH:MM:SS)
  if (typeof timeValue === 'string') {
    return timeValue.substring(0, 5); // Extract HH:MM part
  }
  
  return '';
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
