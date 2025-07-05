// Database types
export interface Staff {
  id: string
  first_name: string
  last_name: string
  role: 'supervisor' | 'porter' | 'admin'
  active?: boolean
  created_at?: string
  updated_at?: string
}

export interface Shift {
  id: string
  supervisor_id: string
  shift_type: 'week_day' | 'week_night' | 'weekend_day' | 'weekend_night'
  start_time: string
  end_time?: string
  created_at: string
  updated_at?: string
  supervisor?: Staff
}

// Store loading states
export interface LoadingState {
  [key: string]: boolean
}

// API response types
export interface ApiResponse<T> {
  data: T | null
  error: string | null
}

// Component prop types
export interface TabDefinition {
  id: string
  label: string
}

export interface ShiftCardProps {
  shift: Shift
  selected?: boolean
}

// Form types
export interface CreateShiftData {
  supervisor_id: string
  shift_type: string
  start_time: string
}

// Settings types
export interface ShiftDefaults {
  week_day: ShiftTimeConfig
  week_night: ShiftTimeConfig
  weekend_day: ShiftTimeConfig
  weekend_night: ShiftTimeConfig
}

export interface ShiftTimeConfig {
  startTime: string
  endTime: string
  color: string
}

export interface AppSettings {
  timezone: string
  timeFormat: '12h' | '24h'
}

export interface SettingsState {
  shiftDefaults: ShiftDefaults
  appSettings: AppSettings
  loading: boolean
  error: string | null
}

// Utility types
export type ShiftType = 'week_day' | 'week_night' | 'weekend_day' | 'weekend_night'
export type StaffRole = 'supervisor' | 'porter' | 'admin'
