export interface Staff {
  id: string
  first_name: string
  last_name: string
  role: 'supervisor' | 'porter'
  email?: string
  phone?: string
  department_id?: string
  porter_type?: 'shift' | 'relief'
  availability_pattern?: string
  contracted_hours_start?: string
  contracted_hours_end?: string
  active: boolean
  created_at: string
  updated_at: string
  department?: {
    id: string
    name: string
    building_id: string
  }
}

export interface PorterAbsence {
  id: string
  porter_id: string
  absence_type: 'illness' | 'annual_leave'
  start_date: string
  end_date: string
  reason?: string
  notes?: string
  created_at: string
  updated_at: string
  porter?: {
    id: string
    first_name: string
    last_name: string
  }
}

export interface StaffFilters {
  sortBy: 'firstName' | 'lastName'
  porterTypeFilter: 'all' | 'shift' | 'relief'
  shiftTimeFilter: 'all' | 'day' | 'night'
  sortDirection: 'asc' | 'desc'
  searchQuery: string
}

export interface StaffLoadingState {
  supervisors: boolean
  porters: boolean
  staff: boolean
  absences: boolean
}

export type AvailabilityPattern =
  | 'Weekdays - Days'
  | 'Weekdays - Nights'
  | 'Weekdays - Days and Nights'
  | 'Weekends - Days'
  | 'Weekends - Nights'
  | 'Weekends - Days and Nights'
  | '4 on 4 off - Days'
  | '4 on 4 off - Nights'
  | '4 on 4 off - Days and Nights'

export interface ShiftDefaults {
  week_day: {
    startTime: string
    endTime: string
  }
  week_night: {
    startTime: string
    endTime: string
  }
  weekend_day: {
    startTime: string
    endTime: string
  }
  weekend_night: {
    startTime: string
    endTime: string
  }
}

export type ShiftType = 'day' | 'night' | 'unknown'
