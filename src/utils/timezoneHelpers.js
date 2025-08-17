/**
 * @deprecated Use timeUtils.js instead
 * Simple browser-based timezone helpers
 * All functions use browser timezone with 24-hour format
 */

// Re-export from the new unified timeUtils
export {
  formatDateTimeForUser,
  formatTimeForDisplay as formatTimeForUser,
  getCurrentDateTimeForUser,
  formatDateForUser
} from './timeUtils';
