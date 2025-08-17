/**
 * Additional timezone helper functions for component use
 * These functions help components properly display dates and times according to user preferences
 */

import { useSettingsStore } from '../stores/settingsStore';

/**
 * Format a Date object or time string for display in the user's timezone and format preference
 * @param {Date|string} dateTime - Date object or ISO string to format
 * @param {Object} options - Formatting options
 * @param {boolean} options.includeDate - Whether to include the date part
 * @param {boolean} options.includeTime - Whether to include the time part
 * @param {boolean} options.includeSeconds - Whether to include seconds in time
 * @returns {string} Formatted date/time string
 */
export function formatDateTimeForUser(dateTime, options = {}) {
  if (!dateTime) return '';
  
  const settingsStore = useSettingsStore();
  const timezone = settingsStore.appSettings.timezone || 'UTC';
  const timeFormat = settingsStore.appSettings.time_format || '24h';
  
  const {
    includeDate = true,
    includeTime = true,
    includeSeconds = false
  } = options;
  
  const date = typeof dateTime === 'string' ? new Date(dateTime) : dateTime;
  if (isNaN(date.getTime())) return '';
  
  const formatOptions = {
    timeZone: timezone === 'GMT' ? 'Europe/London' : timezone,
    hour12: timeFormat === '12h'
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
  
  return date.toLocaleString('en-CA', formatOptions);
}

/**
 * Format a time-only value (like TIME fields from database) for display
 * @param {Date|string} timeValue - Time value to format
 * @param {boolean} isUTC - Whether the time value is in UTC and needs conversion
 * @returns {string} Formatted time string (HH:MM or HH:MM AM/PM)
 */
export function formatTimeForUser(timeValue, isUTC = false) {
  if (!timeValue) return '';
  
  // Handle corrupted 'NaN:NaN' values
  if (timeValue === 'NaN:NaN' || timeValue.includes('NaN')) {
    return '';
  }
  
  const settingsStore = useSettingsStore();
  const timeFormat = settingsStore.appSettings.time_format || '24h';
  const timezone = settingsStore.appSettings.timezone || 'UTC';
  
  let hours, minutes;
  
  // Handle Date objects (from MySQL TIME fields)
  if (timeValue instanceof Date) {
    if (isUTC) {
      hours = timeValue.getUTCHours();
      minutes = timeValue.getUTCMinutes();
    } else {
      hours = timeValue.getHours();
      minutes = timeValue.getMinutes();
    }
  }
  // Handle ISO datetime strings (like "2025-06-25T04:33:00")
  else if (typeof timeValue === 'string' && timeValue.includes('T')) {
    // These are stored as UTC times in the database, so we need to convert to user's timezone
    if (isUTC) {
      // Parse as UTC and convert to user's timezone
      const utcDate = new Date(timeValue + (timeValue.endsWith('Z') ? '' : 'Z')); // Ensure UTC parsing
      if (isNaN(utcDate.getTime())) return '';
      
      // Convert to user's timezone
      const actualTimezone = timezone === 'GMT' ? 'Europe/London' : timezone;
      const userTime = utcDate.toLocaleString('en-GB', {
        timeZone: actualTimezone,
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      });
      
      const timeParts = userTime.split(':');
      if (timeParts.length < 2) return '';
      
      hours = parseInt(timeParts[0], 10);
      minutes = parseInt(timeParts[1], 10);
    } else {
      // Treat as local time
      const date = new Date(timeValue);
      if (isNaN(date.getTime())) return '';
      
      hours = date.getHours();
      minutes = date.getMinutes();
    }
  }
  // Handle simple time strings (HH:MM or HH:MM:SS)
  else if (typeof timeValue === 'string') {
    // For simple time strings like "14:30", these are typically already in local time
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
  
  if (timeFormat === '12h') {
    const period = hours >= 12 ? 'PM' : 'AM';
    const displayHours = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
    return `${displayHours}:${String(minutes).padStart(2, '0')} ${period}`;
  } else {
    return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
  }
}

/**
 * Format a time value for HTML time input (always HH:MM format)
 * @param {Date|string} timeValue - Time value to format
 * @returns {string} Time in HH:MM format for input fields
 */
export function formatTimeForInput(timeValue) {
  if (!timeValue) return '';
  
  let hours, minutes;
  
  // Handle Date objects (from MySQL TIME fields)
  if (timeValue instanceof Date) {
    hours = timeValue.getUTCHours();
    minutes = timeValue.getUTCMinutes();
  }
  // Handle ISO datetime strings
  else if (typeof timeValue === 'string' && timeValue.includes('T')) {
    const date = new Date(timeValue);
    hours = date.getUTCHours();
    minutes = date.getUTCMinutes();
  }
  // Handle simple time strings (HH:MM or HH:MM:SS)
  else if (typeof timeValue === 'string') {
    [hours, minutes] = timeValue.split(':').map(Number);
  }
  else {
    return '';
  }
  
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

/**
 * Get current date/time formatted for the user's timezone
 * @param {Object} options - Formatting options (same as formatDateTimeForUser)
 * @returns {string} Current date/time formatted for user
 */
export function getCurrentDateTimeForUser(options = {}) {
  return formatDateTimeForUser(new Date(), options);
}

/**
 * Format a date for display in user's timezone (date only, no time)
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
  
  const settingsStore = useSettingsStore();
  const timezone = settingsStore.appSettings.timezone || 'UTC';
  
  // Get the date in the user's timezone
  const dateInTimezone = dateObj.toLocaleDateString('en-CA', {
    timeZone: timezone === 'GMT' ? 'Europe/London' : timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  
  return dateInTimezone;
}

/**
 * Get current time as HH:MM string in user's timezone
 * @returns {string} Current time in HH:MM format
 */
export function getCurrentTimeString() {
  const settingsStore = useSettingsStore();
  const timezone = settingsStore.appSettings.timezone || 'UTC';
  const now = new Date();
  
  // Get current time in the user's timezone
  const timeInTimezone = now.toLocaleString('en-CA', {
    timeZone: timezone === 'GMT' ? 'Europe/London' : timezone,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });
  
  return timeInTimezone;
}

/**
 * Convert a time string from user's timezone to UTC for database storage
 * @param {string} timeString - Time in HH:MM format in user's timezone
 * @returns {string} Time in HH:MM format in UTC
 */
export function convertTimeToUTC(timeString) {
  if (!timeString) return '';
  
  const settingsStore = useSettingsStore();
  const timezone = settingsStore.appSettings.timezone || 'UTC';
  
  // If already UTC, return as-is
  if (timezone === 'UTC') {
    return timeString;
  }
  
  // Parse the time string
  const [hours, minutes] = timeString.split(':').map(Number);
  
  // Create a date object for today with the given time
  const today = new Date();
  const dateString = today.toISOString().split('T')[0]; // Get YYYY-MM-DD
  
  // Map GMT to Europe/London for proper BST/GMT handling
  const actualTimezone = timezone === 'GMT' ? 'Europe/London' : timezone;
  
  // Create a date assuming the time is in the user's timezone
  // We'll use a temporary date to calculate the offset
  const tempDate = new Date(`${dateString}T${timeString}:00`);
  
  // Get what this time would be in UTC vs user timezone
  const utcTime = new Date(tempDate.toLocaleString('en-US', { timeZone: 'UTC' }));
  const userTime = new Date(tempDate.toLocaleString('en-US', { timeZone: actualTimezone }));
  
  // Calculate the offset and apply it
  const offsetMs = userTime.getTime() - utcTime.getTime();
  const utcDate = new Date(tempDate.getTime() - offsetMs);
  
  // Format as HH:MM
  const utcHours = utcDate.getUTCHours();
  const utcMinutes = utcDate.getUTCMinutes();
  
  return `${String(utcHours).padStart(2, '0')}:${String(utcMinutes).padStart(2, '0')}`;
}

/**
 * Convert a UTC time string to user's timezone for display
 * @param {string} utcTimeString - Time in HH:MM format in UTC
 * @returns {string} Time in HH:MM format in user's timezone
 */
export function convertTimeFromUTC(utcTimeString) {
  if (!utcTimeString) return '';
  
  const settingsStore = useSettingsStore();
  const timezone = settingsStore.appSettings.timezone || 'UTC';
  
  // If timezone is UTC, return as-is
  if (timezone === 'UTC') {
    return utcTimeString;
  }
  
  // Parse the UTC time string
  const [hours, minutes] = utcTimeString.split(':').map(Number);
  
  // Create a date object for today with the given UTC time
  const today = new Date();
  const dateString = today.toISOString().split('T')[0]; // Get YYYY-MM-DD
  
  // Create a UTC date with explicit Z timezone indicator
  const utcDate = new Date(`${dateString}T${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:00.000Z`);
  
  // Convert to user's timezone using toLocaleString
  // Map GMT to Europe/London for proper BST/GMT handling
  const actualTimezone = timezone === 'GMT' ? 'Europe/London' : timezone;
  
  const options = {
    timeZone: actualTimezone,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  };
  
  const userTime = utcDate.toLocaleString('en-GB', options);
  
  // Extract just the time part (in case there's any date formatting)
  const timePart = userTime.match(/\d{2}:\d{2}/);
  return timePart ? timePart[0] : userTime;
}
