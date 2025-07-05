import { defineStore } from 'pinia'
import { supabase } from '../services/supabase'
import { useStaffStore } from './staffStore'
import type {
  AreaCoverAssignment,
  AreaCoverPorterAssignment,
  CoverageGap,
  StaffingShortage,
  CoverageAnalysis,
  StaffingAnalysis,
  CoverageIssuesAnalysis,
  ShiftType
} from '../types/areaCover'

// Helper function to convert time string (HH:MM:SS) to minutes
function timeToMinutes(timeStr: string): number {
  if (!timeStr) return 0

  const [hours, minutes] = timeStr.split(':').map(Number)
  return (hours * 60) + minutes
}

// Helper function to convert minutes back to time string (HH:MM:SS)
function minutesToTime(minutes: number): string {
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}:00`
}

interface AreaCoverState {
  departments: any[]
  areaAssignments: AreaCoverAssignment[]
  porterAssignments: AreaCoverPorterAssignment[]
  loading: {
    departments: boolean
    save: boolean
    [key: string]: boolean
  }
  error: string | null
}

export const useAreaCoverStore = defineStore('areaCover', {
  state: (): AreaCoverState => ({
    departments: [],
    areaAssignments: [],
    porterAssignments: [],
    loading: {
      departments: false,
      save: false
    },
    error: null
  }),

  getters: {
    // Get area assignments by department ID
    getAssignmentsByDepartmentId: (state) => (departmentId: string): AreaCoverAssignment[] => {
      return state.areaAssignments.filter(a => a.department_id === departmentId)
    },

    // Get area assignment by ID
    getAssignmentById: (state) => (id: string): AreaCoverAssignment | undefined => {
      return state.areaAssignments.find(a => a.id === id)
    },

    // Get area assignments by shift type
    getAssignmentsByShiftType: (state) => (shiftType: ShiftType): AreaCoverAssignment[] => {
      return state.areaAssignments.filter(a => a.shift_type === shiftType)
    },

    // Get porter assignments for a specific area assignment
    getPorterAssignmentsByAreaId: (state) => (areaAssignmentId: string): AreaCoverPorterAssignment[] => {
      return state.porterAssignments.filter(
        pa => pa.default_area_cover_assignment_id === areaAssignmentId
      )
    },

    // Get sorted assignments by shift type (migrated from defaultAreaCoverStore)
    getSortedAssignmentsByType: (state) => (shiftType: ShiftType): AreaCoverAssignment[] => {
      const assignments = state.areaAssignments.filter(a => a.shift_type === shiftType)
      return [...assignments].sort((a, b) => {
        const aName = a.department?.name || ''
        const bName = b.department?.name || ''
        return aName.localeCompare(bName)
      })
    },

    // Check for staffing shortages based on minimum porter count
    getStaffingShortages: (state) => (areaCoverId: string): StaffingAnalysis => {
      try {
        const staffStore = useStaffStore()
        const today = new Date()

        const assignment = state.areaAssignments.find(a => a.id === areaCoverId)
        if (!assignment) return { hasShortage: false, shortages: [] }

        // If minimum_porters is not set or is 0, there's no staffing requirement
        if (!assignment.minimum_porters) return { hasShortage: false, shortages: [] }

        // Get all porter assignments for this area
        const allPorterAssignments = state.porterAssignments.filter(
          pa => pa.default_area_cover_assignment_id === areaCoverId
        )

        // Filter out porters who are absent
        const porterAssignments = allPorterAssignments.filter(
          pa => !staffStore.isPorterAbsent(pa.porter_id, today)
        )

        if (porterAssignments.length === 0) {
          // No porters assigned - the entire period is a shortage
          return {
            hasShortage: true,
            shortages: [
              {
                startTime: assignment.start_time,
                endTime: assignment.end_time,
                type: 'shortage',
                porterCount: 0,
                requiredCount: assignment.minimum_porters
              }
            ]
          }
        }

        // Convert department times to minutes for easier comparison
        const departmentStart = timeToMinutes(assignment.start_time)
        const departmentEnd = timeToMinutes(assignment.end_time)

        // Create a timeline of porter counts
        // First, collect all the time points where porter count changes
        let timePoints = new Set<number>()
        timePoints.add(departmentStart)
        timePoints.add(departmentEnd)

        porterAssignments.forEach(pa => {
          const porterStart = timeToMinutes(pa.start_time)
          const porterEnd = timeToMinutes(pa.end_time)

          // Only add time points that are within the department's time range
          if (porterStart >= departmentStart && porterStart <= departmentEnd) {
            timePoints.add(porterStart)
          }
          if (porterEnd >= departmentStart && porterEnd <= departmentEnd) {
            timePoints.add(porterEnd)
          }
        })

        // Convert to array and sort
        const sortedTimePoints = Array.from(timePoints).sort((a, b) => a - b)

        // Check each time segment between time points
        const shortages: StaffingShortage[] = []

        for (let i = 0; i < sortedTimePoints.length - 1; i++) {
          const segmentStart = sortedTimePoints[i]
          const segmentEnd = sortedTimePoints[i + 1]

          // Skip segments with zero duration
          if (segmentStart === segmentEnd) continue

          // Count porters active during this segment
          const activePorters = porterAssignments.filter(pa => {
            const porterStart = timeToMinutes(pa.start_time)
            const porterEnd = timeToMinutes(pa.end_time)
            return porterStart <= segmentStart && porterEnd >= segmentEnd
          }).length

          // Check if active porter count is below minimum
          if (activePorters < assignment.minimum_porters) {
            shortages.push({
              startTime: minutesToTime(segmentStart),
              endTime: minutesToTime(segmentEnd),
              type: 'shortage',
              porterCount: activePorters,
              requiredCount: assignment.minimum_porters
            })
          }
        }

        return {
          hasShortage: shortages.length > 0,
          shortages
        }
      } catch (error) {
        console.error('Error in getStaffingShortages:', error)
        return { hasShortage: false, shortages: [] }
      }
    },

    // Legacy method for compatibility
    hasStaffingShortage: (state) => (areaCoverId: string): boolean => {
      return (state as any).getStaffingShortages(areaCoverId).hasShortage
    },

    // Get coverage gaps with detailed information
    getCoverageGaps: (state) => (areaCoverId: string): CoverageAnalysis => {
      try {
        const staffStore = useStaffStore()
        const today = new Date()

        const assignment = state.areaAssignments.find(a => a.id === areaCoverId)
        if (!assignment) return { hasGap: false, gaps: [] }

        // Get all porter assignments for this area
        const allPorterAssignments = state.porterAssignments.filter(
          pa => pa.default_area_cover_assignment_id === areaCoverId
        )

        // Filter out porters who are absent
        const porterAssignments = allPorterAssignments.filter(
          pa => !staffStore.isPorterAbsent(pa.porter_id, today)
        )

        if (porterAssignments.length === 0) {
          // No porters assigned - the entire period is a gap
          return {
            hasGap: true,
            gaps: [
              {
                startTime: assignment.start_time,
                endTime: assignment.end_time,
                type: 'gap'
              }
            ]
          }
        }

        // Convert department times to minutes for easier comparison
        const departmentStart = timeToMinutes(assignment.start_time)
        const departmentEnd = timeToMinutes(assignment.end_time)

        // First check if any single porter covers the entire time period
        const fullCoverageExists = porterAssignments.some(porterAssignment => {
          const porterStart = timeToMinutes(porterAssignment.start_time)
          const porterEnd = timeToMinutes(porterAssignment.end_time)
          return porterStart <= departmentStart && porterEnd >= departmentEnd
        })

        // If at least one porter provides full coverage, there's no gap
        if (fullCoverageExists) {
          return { hasGap: false, gaps: [] }
        }

        // Sort porter assignments by start time
        const sortedAssignments = [...porterAssignments].sort((a, b) => {
          return timeToMinutes(a.start_time) - timeToMinutes(b.start_time)
        })

        const gaps: CoverageGap[] = []

        // Check for gap at the beginning
        if (timeToMinutes(sortedAssignments[0].start_time) > departmentStart) {
          gaps.push({
            startTime: assignment.start_time,
            endTime: sortedAssignments[0].start_time,
            type: 'gap'
          })
        }

        // Check for gaps between porter assignments
        for (let i = 0; i < sortedAssignments.length - 1; i++) {
          const currentEnd = timeToMinutes(sortedAssignments[i].end_time)
          const nextStart = timeToMinutes(sortedAssignments[i + 1].start_time)

          if (nextStart > currentEnd) {
            gaps.push({
              startTime: sortedAssignments[i].end_time,
              endTime: sortedAssignments[i + 1].start_time,
              type: 'gap'
            })
          }
        }

        // Check for gap at the end
        const lastEnd = timeToMinutes(sortedAssignments[sortedAssignments.length - 1].end_time)
        if (lastEnd < departmentEnd) {
          gaps.push({
            startTime: sortedAssignments[sortedAssignments.length - 1].end_time,
            endTime: assignment.end_time,
            type: 'gap'
          })
        }

        return {
          hasGap: gaps.length > 0,
          gaps
        }
      } catch (error) {
        console.error('Error in getCoverageGaps:', error)
        return { hasGap: false, gaps: [] }
      }
    },

    // Legacy method for compatibility
    hasCoverageGap: (state) => (areaCoverId: string): boolean => {
      return (state as any).getCoverageGaps(areaCoverId).hasGap
    },

    // Get all coverage issues (both gaps and staffing shortages)
    getCoverageIssues: (state) => (areaCoverId: string): CoverageIssuesAnalysis => {
      const gaps = (state as any).getCoverageGaps(areaCoverId).gaps
      const shortages = (state as any).getStaffingShortages(areaCoverId).shortages

      const allIssues = [...gaps, ...shortages].sort((a, b) => {
        return timeToMinutes(a.startTime) - timeToMinutes(b.startTime)
      })

      return {
        hasIssues: allIssues.length > 0,
        issues: allIssues
      }
    }
  },

  actions: {
    // Make sure assignments are loaded for a specific shift type
    async ensureAssignmentsLoaded(shiftType: ShiftType): Promise<AreaCoverAssignment[]> {
      if (!this.areaAssignments || this.areaAssignments.length === 0) {
        await this.fetchAreaAssignments()
      }
      return this.getAssignmentsByShiftType(shiftType)
    },

    // Fetch assignments by shift type (for compatibility with components)
    async fetchAssignments(shiftType: ShiftType): Promise<AreaCoverAssignment[]> {
      await this.fetchAreaAssignments()
      return this.getAssignmentsByShiftType(shiftType)
    },

    // For compatibility with DefaultAreaCoverSection component
    async addDepartment(departmentId: string, shiftType: ShiftType, startTime: string, endTime: string, color = '#4285F4'): Promise<AreaCoverAssignment | null> {
      return this.addAreaAssignment(departmentId, shiftType, startTime, endTime, color)
    },

    // For compatibility with DefaultAreaCoverSection component
    async updateDepartment(assignmentId: string, updates: Partial<AreaCoverAssignment>): Promise<AreaCoverAssignment | null> {
      return this.updateAreaAssignment(assignmentId, updates)
    },

    // For compatibility with DefaultAreaCoverSection component
    async removeDepartment(assignmentId: string): Promise<boolean> {
      return this.deleteAreaAssignment(assignmentId)
    },

    // Fetch all area assignments (for settings/defaults)
    async fetchAreaAssignments(): Promise<AreaCoverAssignment[]> {
      this.loading.departments = true
      this.error = null

      try {
        // Fetch area cover assignments from default_area_cover_assignments
        const { data, error } = await supabase
          .from('default_area_cover_assignments')
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              color,
              building:building_id(id, name)
            )
          `)
          .order('department_id')

        if (error) throw error

        this.areaAssignments = (data || []) as AreaCoverAssignment[]

        // Also fetch porter assignments for these area assignments
        if (data && data.length > 0) {
          const assignmentIds = data.map(a => a.id)

          const { data: porterData, error: porterError } = await supabase
            .from('default_area_cover_porter_assignments')
            .select(`
              *,
              porter:porter_id(id, first_name, last_name, role)
            `)
            .in('default_area_cover_assignment_id', assignmentIds)

          if (porterError) throw porterError

          this.porterAssignments = (porterData || []) as AreaCoverPorterAssignment[]
        } else {
          this.porterAssignments = []
        }

        return this.areaAssignments
      } catch (error) {
        console.error('Error fetching area assignments:', error)
        this.error = 'Failed to load area assignments'
        return []
      } finally {
        this.loading.departments = false
      }
    },

    // Add a new area assignment (for settings/defaults)
    async addAreaAssignment(departmentId: string, shiftType: ShiftType, startTime: string, endTime: string, color = '#4285F4'): Promise<AreaCoverAssignment | null> {
      this.loading.save = true
      this.error = null

      try {
        const { data, error } = await supabase
          .from('default_area_cover_assignments')
          .insert({
            department_id: departmentId,
            shift_type: shiftType,
            start_time: startTime,
            end_time: endTime,
            color: color
          })
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              color,
              building:building_id(id, name)
            )
          `)

        if (error) throw error

        if (data && data.length > 0) {
          const newAssignment = data[0] as AreaCoverAssignment
          this.areaAssignments.push(newAssignment)
          return newAssignment
        }

        return null
      } catch (error) {
        console.error('Error adding area assignment:', error)
        this.error = 'Failed to add area assignment'
        return null
      } finally {
        this.loading.save = false
      }
    },

    // Update an area assignment
    async updateAreaAssignment(assignmentId: string, updates: Partial<AreaCoverAssignment>): Promise<AreaCoverAssignment | null> {
      this.loading.save = true
      this.error = null

      try {
        const { data, error } = await supabase
          .from('default_area_cover_assignments')
          .update(updates)
          .eq('id', assignmentId)
          .select(`
            *,
            department:department_id(
              id,
              name,
              building_id,
              color,
              building:building_id(id, name)
            )
          `)

        if (error) throw error

        if (data && data.length > 0) {
          const updatedAssignment = data[0] as AreaCoverAssignment
          // Update in local state
          const index = this.areaAssignments.findIndex(a => a.id === assignmentId)
          if (index !== -1) {
            this.areaAssignments[index] = updatedAssignment
          }
          return updatedAssignment
        }

        return null
      } catch (error) {
        console.error('Error updating area assignment:', error)
        this.error = 'Failed to update area assignment'
        return null
      } finally {
        this.loading.save = false
      }
    },

    // Delete an area assignment
    async deleteAreaAssignment(assignmentId: string): Promise<boolean> {
      this.loading.save = true
      this.error = null

      try {
        const { error } = await supabase
          .from('default_area_cover_assignments')
          .delete()
          .eq('id', assignmentId)

        if (error) throw error

        // Remove from local state
        this.areaAssignments = this.areaAssignments.filter(a => a.id !== assignmentId)

        // Also remove all associated porter assignments
        this.porterAssignments = this.porterAssignments.filter(
          pa => pa.default_area_cover_assignment_id !== assignmentId
        )

        return true
      } catch (error) {
        console.error('Error deleting area assignment:', error)
        this.error = 'Failed to delete area assignment'
        return false
      } finally {
        this.loading.save = false
      }
    },

    // Add a porter assignment to a default area cover
    async addPorterAssignment(areaCoverId: string, porterId: string, startTime: string, endTime: string): Promise<AreaCoverPorterAssignment | null> {
      this.loading.save = true
      this.error = null

      try {
        const { data, error } = await supabase
          .from('default_area_cover_porter_assignments')
          .insert({
            default_area_cover_assignment_id: areaCoverId,
            porter_id: porterId,
            start_time: startTime,
            end_time: endTime
          })
          .select(`
            *,
            porter:porter_id(id, first_name, last_name, role)
          `)

        if (error) throw error

        if (data && data.length > 0) {
          const newPorterAssignment = data[0] as AreaCoverPorterAssignment
          this.porterAssignments.push(newPorterAssignment)
          return newPorterAssignment
        }

        return null
      } catch (error) {
        console.error('Error adding porter assignment:', error)
        this.error = 'Failed to add porter assignment'
        return null
      } finally {
        this.loading.save = false
      }
    },

    // Update a porter assignment
    async updatePorterAssignment(porterAssignmentId: string, updates: Partial<AreaCoverPorterAssignment>): Promise<AreaCoverPorterAssignment | null> {
      this.loading.save = true
      this.error = null

      try {
        const { data, error } = await supabase
          .from('default_area_cover_porter_assignments')
          .update(updates)
          .eq('id', porterAssignmentId)
          .select(`
            *,
            porter:porter_id(id, first_name, last_name, role)
          `)

        if (error) throw error

        if (data && data.length > 0) {
          const updatedPorterAssignment = data[0] as AreaCoverPorterAssignment
          // Update in local state
          const index = this.porterAssignments.findIndex(pa => pa.id === porterAssignmentId)
          if (index !== -1) {
            this.porterAssignments[index] = updatedPorterAssignment
          }
          return updatedPorterAssignment
        }

        return null
      } catch (error) {
        console.error('Error updating porter assignment:', error)
        this.error = 'Failed to update porter assignment'
        return null
      } finally {
        this.loading.save = false
      }
    },

    // Remove porter assignment
    async removePorterAssignment(porterAssignmentId: string): Promise<boolean> {
      this.loading.save = true
      this.error = null

      try {
        const { error } = await supabase
          .from('default_area_cover_porter_assignments')
          .delete()
          .eq('id', porterAssignmentId)

        if (error) throw error

        // Remove from local state
        this.porterAssignments = this.porterAssignments.filter(pa => pa.id !== porterAssignmentId)

        return true
      } catch (error) {
        console.error('Error removing porter assignment:', error)
        this.error = 'Failed to remove porter assignment'
        return false
      } finally {
        this.loading.save = false
      }
    },

    // Initialize store
    async initialize(): Promise<void> {
      await this.fetchAreaAssignments()
    }
  }
})
