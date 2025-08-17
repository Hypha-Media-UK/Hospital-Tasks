/**
 * @deprecated Use timeUtils.js instead
 * Simple browser-based timezone utilities
 * All times use the user's browser timezone automatically
 */

// Re-export from the new unified timeUtils
export {
  getCurrentDateTime,
  getCurrentTimeInMinutes,
  formatTimeForDisplay,
  isSameDay
} from './timeUtils';
