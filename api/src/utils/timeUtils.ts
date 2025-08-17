/**
 * Time parsing and validation utilities
 * Provides consistent time handling across the application
 */

export interface ParsedTimeResult {
  dateTime: Date | null;
  isValid: boolean;
  error?: string;
}

export interface ParsedTimePair {
  startDateTime: Date | null;
  endDateTime: Date | null;
  isValid: boolean;
  error?: string;
}

/**
 * Parse a time string (HH:MM or HH:MM:SS) into a Date object
 * Uses 1970-01-01 as the base date for time-only values
 * 
 * @param timeString - Time in HH:MM or HH:MM:SS format
 * @returns ParsedTimeResult with the parsed Date or error information
 */
export function parseTimeString(timeString: string | null | undefined): ParsedTimeResult {
  if (!timeString) {
    return {
      dateTime: null,
      isValid: false,
      error: 'Time string is required'
    };
  }

  let dateTime: Date | null = null;

  // Handle both HH:MM and HH:MM:SS formats
  if (timeString.match(/^\d{2}:\d{2}$/)) {
    // HH:MM format - add seconds
    dateTime = new Date(`1970-01-01T${timeString}:00.000Z`);
  } else if (timeString.match(/^\d{2}:\d{2}:\d{2}$/)) {
    // HH:MM:SS format
    dateTime = new Date(`1970-01-01T${timeString}.000Z`);
  } else {
    return {
      dateTime: null,
      isValid: false,
      error: 'Invalid time format. Expected HH:MM or HH:MM:SS'
    };
  }

  // Validate that the date was parsed successfully
  if (!dateTime || isNaN(dateTime.getTime())) {
    return {
      dateTime: null,
      isValid: false,
      error: 'Invalid time value. Could not parse time string'
    };
  }

  return {
    dateTime,
    isValid: true
  };
}

/**
 * Parse start and end time strings into Date objects
 * Validates both times and ensures they are properly formatted
 * 
 * @param startTime - Start time in HH:MM or HH:MM:SS format
 * @param endTime - End time in HH:MM or HH:MM:SS format
 * @returns ParsedTimePair with both parsed dates or error information
 */
export function parseTimePair(startTime: string, endTime: string): ParsedTimePair {
  const startResult = parseTimeString(startTime);
  const endResult = parseTimeString(endTime);

  if (!startResult.isValid) {
    return {
      startDateTime: null,
      endDateTime: null,
      isValid: false,
      error: `Invalid start_time: ${startResult.error}`
    };
  }

  if (!endResult.isValid) {
    return {
      startDateTime: null,
      endDateTime: null,
      isValid: false,
      error: `Invalid end_time: ${endResult.error}`
    };
  }

  return {
    startDateTime: startResult.dateTime,
    endDateTime: endResult.dateTime,
    isValid: true
  };
}

/**
 * Format a Date object back to HH:MM:SS string format
 * Useful for API responses
 * 
 * @param date - Date object to format
 * @returns Time string in HH:MM:SS format
 */
export function formatTimeFromDate(date: Date): string {
  return date.toISOString().substring(11, 19); // Extract HH:MM:SS from ISO string
}

/**
 * Validate time range (start time should be before end time)
 * 
 * @param startDateTime - Start date/time
 * @param endDateTime - End date/time
 * @returns true if valid range, false otherwise
 */
export function isValidTimeRange(startDateTime: Date, endDateTime: Date): boolean {
  return startDateTime.getTime() < endDateTime.getTime();
}
