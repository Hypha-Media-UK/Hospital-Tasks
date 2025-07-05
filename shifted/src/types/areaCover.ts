export interface AreaCoverAssignment {
  id: string
  department_id: string
  shift_type: 'week_day' | 'week_night' | 'weekend_day' | 'weekend_night'
  start_time: string
  end_time: string
  color?: string
  minimum_porters?: number
  created_at?: string
  updated_at?: string
  department?: {
    id: string
    name: string
    building_id: string
    color?: string
    building?: {
      id: string
      name: string
    }
  }
}

export interface AreaCoverPorterAssignment {
  id: string
  default_area_cover_assignment_id: string
  porter_id: string
  start_time: string
  end_time: string
  created_at?: string
  updated_at?: string
  porter?: {
    id: string
    first_name: string
    last_name: string
    role: string
  }
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

export interface CoverageAnalysis {
  hasGap: boolean
  gaps: CoverageGap[]
}

export interface StaffingAnalysis {
  hasShortage: boolean
  shortages: StaffingShortage[]
}

export interface CoverageIssuesAnalysis {
  hasIssues: boolean
  issues: CoverageIssue[]
}

export type ShiftType = 'week_day' | 'week_night' | 'weekend_day' | 'weekend_night'

export interface DepartmentAssignmentData {
  department_id: string
  is_origin: boolean
  is_destination: boolean
}
