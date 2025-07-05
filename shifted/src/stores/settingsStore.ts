import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../services/supabase'
import type { ShiftDefaults, AppSettings, ShiftTimeConfig } from '../types'

export const useSettingsStore = defineStore('settings', () => {
  // State
  const shiftDefaults = ref<ShiftDefaults>({
    week_day: {
      startTime: '08:00',
      endTime: '20:00',
      color: '#4285F4'
    },
    week_night: {
      startTime: '20:00',
      endTime: '08:00',
      color: '#673AB7'
    },
    weekend_day: {
      startTime: '08:00',
      endTime: '20:00',
      color: '#34A853'
    },
    weekend_night: {
      startTime: '20:00',
      endTime: '08:00',
      color: '#EA4335'
    }
  })

  const appSettings = ref<AppSettings>({
    timezone: 'UTC',
    timeFormat: '24h'
  })

  const loading = ref(false)
  const error = ref<string | null>(null)

  // Actions
  const loadSettings = async (): Promise<boolean> => {
    loading.value = true
    error.value = null

    try {
      await Promise.all([
        loadShiftDefaults(),
        loadAppSettings()
      ])
      return true
    } catch (err) {
      console.error('Error loading settings:', err)
      return false
    } finally {
      loading.value = false
    }
  }

  const loadShiftDefaults = async (): Promise<any> => {
    try {
      const { data, error: fetchError } = await supabase
        .from('shift_defaults')
        .select('*')

      if (fetchError && !fetchError.message.includes('relation "shift_defaults" does not exist')) {
        throw fetchError
      }

      if (data && data.length > 0) {
        data.forEach((shift: any) => {
          if (shiftDefaults.value[shift.shift_type as keyof ShiftDefaults]) {
            shiftDefaults.value[shift.shift_type as keyof ShiftDefaults] = {
              startTime: shift.start_time.slice(0, 5),
              endTime: shift.end_time.slice(0, 5),
              color: shift.color
            }
          }
        })
      } else if (import.meta.env.DEV) {
        // Fallback to localStorage in development
        const savedDefaults = localStorage.getItem('shift_defaults')
        if (savedDefaults) {
          try {
            const parsedDefaults = JSON.parse(savedDefaults)
            if (parsedDefaults.day) {
              shiftDefaults.value.week_day = {
                ...shiftDefaults.value.week_day,
                ...parsedDefaults.day
              }
            }
            if (parsedDefaults.night) {
              shiftDefaults.value.week_night = {
                ...shiftDefaults.value.week_night,
                ...parsedDefaults.night
              }
            }
          } catch (e) {
            console.warn('Error parsing localStorage shift defaults', e)
          }
        }
      }

      return data
    } catch (err) {
      console.error('Error loading shift defaults:', err)
      return null
    }
  }

  const saveShiftDefaults = async (): Promise<any> => {
    loading.value = true
    error.value = null

    try {
      if (import.meta.env.DEV) {
        try {
          const results = await Promise.all([
            supabase
              .from('shift_defaults')
              .upsert({
                shift_type: 'week_day',
                start_time: shiftDefaults.value.week_day.startTime + ':00',
                end_time: shiftDefaults.value.week_day.endTime + ':00',
                color: shiftDefaults.value.week_day.color,
                updated_at: new Date().toISOString()
              }, { onConflict: 'shift_type' })
              .select(),

            supabase
              .from('shift_defaults')
              .upsert({
                shift_type: 'week_night',
                start_time: shiftDefaults.value.week_night.startTime + ':00',
                end_time: shiftDefaults.value.week_night.endTime + ':00',
                color: shiftDefaults.value.week_night.color,
                updated_at: new Date().toISOString()
              }, { onConflict: 'shift_type' })
              .select(),

            supabase
              .from('shift_defaults')
              .upsert({
                shift_type: 'weekend_day',
                start_time: shiftDefaults.value.weekend_day.startTime + ':00',
                end_time: shiftDefaults.value.weekend_day.endTime + ':00',
                color: shiftDefaults.value.weekend_day.color,
                updated_at: new Date().toISOString()
              }, { onConflict: 'shift_type' })
              .select(),

            supabase
              .from('shift_defaults')
              .upsert({
                shift_type: 'weekend_night',
                start_time: shiftDefaults.value.weekend_night.startTime + ':00',
                end_time: shiftDefaults.value.weekend_night.endTime + ':00',
                color: shiftDefaults.value.weekend_night.color,
                updated_at: new Date().toISOString()
              }, { onConflict: 'shift_type' })
              .select()
          ])

          const anyError = results.find(result => result.error)
          if (anyError) {
            if (anyError.error.message.includes('relation "shift_defaults" does not exist')) {
              localStorage.setItem('shift_defaults', JSON.stringify(shiftDefaults.value))
              return [{ id: 'local-storage' }]
            }
            throw anyError.error
          }

          return results.reduce((acc, result) => [...acc, ...(result.data || [])], [])
        } catch (err) {
          console.warn('Falling back to localStorage for settings:', err)
          localStorage.setItem('shift_defaults', JSON.stringify(shiftDefaults.value))
          return [{ id: 'local-storage' }]
        }
      } else {
        // Production mode - only use Supabase
        const results = await Promise.all([
          supabase
            .from('shift_defaults')
            .upsert({
              shift_type: 'week_day',
              start_time: shiftDefaults.value.week_day.startTime + ':00',
              end_time: shiftDefaults.value.week_day.endTime + ':00',
              color: shiftDefaults.value.week_day.color,
              updated_at: new Date().toISOString()
            }, { onConflict: 'shift_type' })
            .select(),

          supabase
            .from('shift_defaults')
            .upsert({
              shift_type: 'week_night',
              start_time: shiftDefaults.value.week_night.startTime + ':00',
              end_time: shiftDefaults.value.week_night.endTime + ':00',
              color: shiftDefaults.value.week_night.color,
              updated_at: new Date().toISOString()
            }, { onConflict: 'shift_type' })
            .select(),

          supabase
            .from('shift_defaults')
            .upsert({
              shift_type: 'weekend_day',
              start_time: shiftDefaults.value.weekend_day.startTime + ':00',
              end_time: shiftDefaults.value.weekend_day.endTime + ':00',
              color: shiftDefaults.value.weekend_day.color,
              updated_at: new Date().toISOString()
            }, { onConflict: 'shift_type' })
            .select(),

          supabase
            .from('shift_defaults')
            .upsert({
              shift_type: 'weekend_night',
              start_time: shiftDefaults.value.weekend_night.startTime + ':00',
              end_time: shiftDefaults.value.weekend_night.endTime + ':00',
              color: shiftDefaults.value.weekend_night.color,
              updated_at: new Date().toISOString()
            }, { onConflict: 'shift_type' })
            .select()
        ])

        for (const result of results) {
          if (result.error) throw result.error
        }

        return results.reduce((acc, result) => [...acc, ...(result.data || [])], [])
      }
    } catch (err) {
      console.error('Error saving shift defaults:', err)
      error.value = 'Failed to save shift defaults'
      return null
    } finally {
      loading.value = false
    }
  }

  const loadAppSettings = async (): Promise<any> => {
    try {
      const { data, error: fetchError } = await supabase
        .from('app_settings')
        .select('*')
        .order('updated_at', { ascending: false })
        .limit(1)
        .single()

      if (fetchError) {
        if (fetchError.message.includes('relation "app_settings" does not exist') ||
            fetchError.code === 'PGRST116') {
          return null
        }
        throw fetchError
      }

      if (data) {
        appSettings.value = {
          timezone: data.timezone || 'UTC',
          timeFormat: data.time_format || '24h'
        }
      } else if (import.meta.env.DEV) {
        const savedSettings = localStorage.getItem('app_settings')
        if (savedSettings) {
          try {
            const parsedSettings = JSON.parse(savedSettings)
            appSettings.value = {
              ...appSettings.value,
              ...parsedSettings
            }
          } catch (e) {
            console.warn('Error parsing localStorage app settings', e)
          }
        }
      }

      return data
    } catch (err) {
      console.error('Error loading app settings:', err)
      return null
    }
  }

  const saveAppSettings = async (): Promise<any> => {
    loading.value = true
    error.value = null

    try {
      if (import.meta.env.DEV) {
        try {
          const { data, error: saveError } = await supabase
            .from('app_settings')
            .upsert({
              timezone: appSettings.value.timezone,
              time_format: appSettings.value.timeFormat,
              updated_at: new Date().toISOString()
            })
            .select()

          if (saveError) {
            if (saveError.message.includes('relation "app_settings" does not exist')) {
              localStorage.setItem('app_settings', JSON.stringify(appSettings.value))
              return [{ id: 'local-storage' }]
            }
            throw saveError
          }

          return data
        } catch (err) {
          console.warn('Falling back to localStorage for app settings:', err)
          localStorage.setItem('app_settings', JSON.stringify(appSettings.value))
          return [{ id: 'local-storage' }]
        }
      } else {
        const { data, error: saveError } = await supabase
          .from('app_settings')
          .upsert({
            timezone: appSettings.value.timezone,
            time_format: appSettings.value.timeFormat,
            updated_at: new Date().toISOString()
          })
          .select()

        if (saveError) throw saveError
        return data
      }
    } catch (err) {
      console.error('Error saving app settings:', err)
      error.value = 'Failed to save app settings'
      return null
    } finally {
      loading.value = false
    }
  }

  const updateDayShiftDefaults = (dayDefaults: Partial<ShiftTimeConfig>): void => {
    shiftDefaults.value.week_day = {
      ...shiftDefaults.value.week_day,
      ...dayDefaults
    }
    shiftDefaults.value.weekend_day = {
      ...shiftDefaults.value.weekend_day,
      startTime: dayDefaults.startTime || shiftDefaults.value.weekend_day.startTime,
      endTime: dayDefaults.endTime || shiftDefaults.value.weekend_day.endTime,
      color: dayDefaults.color || shiftDefaults.value.weekend_day.color
    }
  }

  const updateNightShiftDefaults = (nightDefaults: Partial<ShiftTimeConfig>): void => {
    shiftDefaults.value.week_night = {
      ...shiftDefaults.value.week_night,
      ...nightDefaults
    }
    shiftDefaults.value.weekend_night = {
      ...shiftDefaults.value.weekend_night,
      startTime: nightDefaults.startTime || shiftDefaults.value.weekend_night.startTime,
      endTime: nightDefaults.endTime || shiftDefaults.value.weekend_night.endTime,
      color: nightDefaults.color || shiftDefaults.value.weekend_night.color
    }
  }

  const updateAppSettings = (settings: Partial<AppSettings>): void => {
    appSettings.value = {
      ...appSettings.value,
      ...settings
    }
  }

  const formatDateTime = (dateString: string): string => {
    if (!dateString) return ''

    const date = new Date(dateString)

    if (appSettings.value.timeFormat === '12h') {
      return date.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
      })
    } else {
      return date.toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      })
    }
  }

  const clearError = (): void => {
    error.value = null
  }

  return {
    // State
    shiftDefaults,
    appSettings,
    loading,
    error,

    // Actions
    loadSettings,
    loadShiftDefaults,
    saveShiftDefaults,
    loadAppSettings,
    saveAppSettings,
    updateDayShiftDefaults,
    updateNightShiftDefaults,
    updateAppSettings,
    formatDateTime,
    clearError
  }
})
