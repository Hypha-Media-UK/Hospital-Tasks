export interface SupportService {
  id: string
  name: string
  description?: string
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface ServiceAssignment {
  id: string
  service_id: string
  shift_type: 'week_day' | 'week_night' | 'weekend_day' | 'weekend_night'
  start_time: string
  end_time: string
  color: string
  minimum_porters?: number
  minimum_porters_mon?: number
  minimum_porters_tue?: number
  minimum_porters_wed?: number
  minimum_porters_thu?: number
  minimum_porters_fri?: number
  minimum_porters_sat?: number
  minimum_porters_sun?: number
  service?: SupportService
  created_at: string
  updated_at: string
}

export interface PorterAssignment {
  id: string
  default_service_cover_assignment_id: string
  support_service_assignment_id?: string
  porter_id: string
  start_time: string
  end_time: string
  porter?: {
    id: string
    first_name: string
    last_name: string
    role: string
  }
  created_at: string
  updated_at: string
}

export interface CoverageGap {
  startTime: string
  endTime: string
  type: 'gap'
}

export interface StaffingShortage {
  startTime: string
  endTime: string
  type: 'shortage'
  porterCount: number
  requiredCount: number
}

export type CoverageIssue = CoverageGap | StaffingShortage

export type ShiftType = 'week_day' | 'week_night' | 'weekend_day' | 'weekend_night'
