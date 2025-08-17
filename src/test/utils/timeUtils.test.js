import { describe, it, expect, beforeEach, vi } from 'vitest'
import {
  timeToMinutes,
  minutesToTime,
  formatTimeForDisplay,
  getCurrentTimeInMinutes,
  isSameDay,
  formatDateTimeForUser,
  formatDateForUser,
  getCurrentDateTime
} from '../../utils/timeUtils'

describe('timeUtils', () => {
  beforeEach(() => {
    // Reset any mocks before each test
    vi.clearAllMocks()
  })

  describe('timeToMinutes', () => {
    it('should convert time string to minutes', () => {
      expect(timeToMinutes('08:30:00')).toBe(510) // 8*60 + 30 = 510
      expect(timeToMinutes('00:00:00')).toBe(0)
      expect(timeToMinutes('23:59:00')).toBe(1439) // 23*60 + 59 = 1439
    })

    it('should handle HH:MM format', () => {
      expect(timeToMinutes('08:30')).toBe(510)
      expect(timeToMinutes('12:00')).toBe(720)
    })

    it('should handle Date objects', () => {
      const date = new Date('2024-01-01T08:30:00')
      expect(timeToMinutes(date)).toBe(510)
    })

    it('should handle ISO datetime strings', () => {
      // Note: This test may vary based on timezone, so we'll test the conversion logic
      const result = timeToMinutes('1970-01-01T08:30:00.000Z')
      expect(typeof result).toBe('number')
      expect(result).toBeGreaterThanOrEqual(0)
      expect(result).toBeLessThan(1440) // Less than 24 hours in minutes
    })

    it('should handle night shift option', () => {
      // For night shifts, times after midnight should be treated as next day
      expect(timeToMinutes('02:00:00', { handleNightShift: true })).toBe(1560) // 2*60 + 24*60 = 1560
      expect(timeToMinutes('14:00:00', { handleNightShift: true })).toBe(840) // 14*60 = 840 (no adjustment)
    })

    it('should return 0 for invalid input', () => {
      expect(timeToMinutes(null)).toBe(0)
      expect(timeToMinutes(undefined)).toBe(0)
      expect(timeToMinutes('')).toBe(0)
    })
  })

  describe('minutesToTime', () => {
    it('should convert minutes to time string', () => {
      expect(minutesToTime(510)).toBe('08:30:00')
      expect(minutesToTime(0)).toBe('00:00:00')
      expect(minutesToTime(1439)).toBe('23:59:00')
    })

    it('should handle values over 24 hours', () => {
      expect(minutesToTime(1560)).toBe('02:00:00') // 26 hours = 2 hours next day
    })

    it('should support different format options', () => {
      expect(minutesToTime(510, { includeSeconds: false })).toBe('08:30')
      expect(minutesToTime(510, { includeSeconds: true })).toBe('08:30:00')
    })
  })

  describe('formatTimeForDisplay', () => {
    it('should format Date objects', () => {
      const date = new Date('2024-01-01T08:30:00')
      const result = formatTimeForDisplay(date)
      expect(result).toMatch(/08:30/)
    })

    it('should format time strings', () => {
      expect(formatTimeForDisplay('08:30:00')).toBe('08:30')
      expect(formatTimeForDisplay('08:30')).toBe('08:30')
    })

    it('should handle options', () => {
      expect(formatTimeForDisplay('08:30:45', { includeSeconds: true })).toBe('08:30:45')
      expect(formatTimeForDisplay('08:30:45', { includeSeconds: false })).toBe('08:30')
    })

    it('should return empty string for invalid input', () => {
      expect(formatTimeForDisplay(null)).toBe('')
      expect(formatTimeForDisplay(undefined)).toBe('')
      expect(formatTimeForDisplay('')).toBe('')
    })
  })

  describe('getCurrentTimeInMinutes', () => {
    it('should return current time in minutes', () => {
      // Mock the current time
      const mockDate = new Date('2024-01-01T08:30:00')
      vi.spyOn(global, 'Date').mockImplementation(() => mockDate)
      
      const result = getCurrentTimeInMinutes()
      expect(result).toBe(510) // 8*60 + 30
      
      vi.restoreAllMocks()
    })
  })

  describe('isSameDay', () => {
    it('should return true for same day', () => {
      const date1 = new Date('2024-01-01T08:00:00')
      const date2 = new Date('2024-01-01T20:00:00')
      expect(isSameDay(date1, date2)).toBe(true)
    })

    it('should return false for different days', () => {
      const date1 = new Date('2024-01-01T08:00:00')
      const date2 = new Date('2024-01-02T08:00:00')
      expect(isSameDay(date1, date2)).toBe(false)
    })

    it('should handle string dates', () => {
      expect(isSameDay('2024-01-01', '2024-01-01')).toBe(true)
      expect(isSameDay('2024-01-01', '2024-01-02')).toBe(false)
    })
  })

  describe('formatDateTimeForUser', () => {
    it('should format date and time', () => {
      const date = new Date('2024-01-01T08:30:00')
      const result = formatDateTimeForUser(date)
      expect(result).toMatch(/01\/01\/2024.*08:30/)
    })

    it('should handle options', () => {
      const date = new Date('2024-01-01T08:30:45')
      
      const dateOnly = formatDateTimeForUser(date, { includeDate: true, includeTime: false })
      expect(dateOnly).toMatch(/01\/01\/2024/)
      expect(dateOnly).not.toMatch(/08:30/)
      
      const timeOnly = formatDateTimeForUser(date, { includeDate: false, includeTime: true })
      expect(timeOnly).toMatch(/08:30/)
      expect(timeOnly).not.toMatch(/2024/)
      
      const withSeconds = formatDateTimeForUser(date, { includeSeconds: true })
      expect(withSeconds).toMatch(/08:30:45/)
    })

    it('should return empty string for invalid input', () => {
      expect(formatDateTimeForUser(null)).toBe('')
      expect(formatDateTimeForUser('invalid')).toBe('')
    })
  })

  describe('formatDateForUser', () => {
    it('should format date only', () => {
      const date = new Date('2024-01-01T08:30:00')
      const result = formatDateForUser(date)
      expect(result).toMatch(/01\/01\/2024/)
      expect(result).not.toMatch(/08:30/)
    })
  })

  describe('getCurrentDateTime', () => {
    it('should return current date', () => {
      const result = getCurrentDateTime()
      expect(result).toBeInstanceOf(Date)
    })
  })
})
