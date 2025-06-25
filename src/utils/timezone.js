/**
 * Timezone-aware utility functions
 * This module provides centralized timezone handling for the entire application
 */

import { useSettingsStore } from '../stores/settingsStore';

/**
 * Get the current date/time in the user's selected timezone
 * @returns {Date} Date object adjusted for the user's timezone
 */
export function getCurrentDateTime() {
  const settingsStore = useSettingsStore();
  const timezone = settingsStore.appSettings.timezone;
  
  // Get current UTC time
  const now = new Date();
  
  // If timezone is UTC, return as-is
  if (timezone === 'UTC') {
    return now;
  }
  
  // For other timezones, create a date in that timezone
  try {
    // Use Intl.DateTimeFormat to get the time in the target timezone
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    });
    
    const parts = formatter.formatToParts(now);
    const partsObj = {};
    parts.forEach(part => {
      partsObj[part.type] = part.value;
    });
    
    // Create a new date with the timezone-adjusted values
    const adjustedDate = new Date(
      parseInt(partsObj.year),
      parseInt(partsObj.month) - 1, // Month is 0-indexed
      parseInt(partsObj.day),
      parseInt(partsObj.hour),
      parseInt(partsObj.minute),
      parseInt(partsObj.second)
    );
    
    return adjustedDate;
  } catch (error) {
    console.warn(`Invalid timezone: ${timezone}, falling back to UTC`, error);
    return now;
  }
}

/**
 * Get the current time in minutes since midnight in the user's timezone
 * @returns {number} Minutes since midnight (0-1439)
 */
export function getCurrentTimeInMinutes() {
  const now = getCurrentDateTime();
  return (now.getHours() * 60) + now.getMinutes();
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
    // Use Intl.DateTimeFormat to get the time in the target timezone
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    });
    
    const parts = formatter.formatToParts(inputDate);
    const partsObj = {};
    parts.forEach(part => {
      partsObj[part.type] = part.value;
    });
    
    // Create a new date with the timezone-adjusted values
    const adjustedDate = new Date(
      parseInt(partsObj.year),
      parseInt(partsObj.month) - 1, // Month is 0-indexed
      parseInt(partsObj.day),
      parseInt(partsObj.hour),
      parseInt(partsObj.minute),
      parseInt(partsObj.second)
    );
    
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
  const now = getCurrentDateTime();
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes}`;
}

/**
 * Get current time as HH:MM:SS string in user's timezone
 * @returns {string} Current time in HH:MM:SS format
 */
export function getCurrentTimeStringWithSeconds() {
  const now = getCurrentDateTime();
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const seconds = String(now.getSeconds()).padStart(2, '0');
  return `${hours}:${minutes}:${seconds}`;
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
