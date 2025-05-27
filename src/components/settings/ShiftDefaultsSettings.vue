<template>
  <div class="shift-defaults-settings">
    <h4>Shift Defaults</h4>
    <p class="section-description">
      Configure default times and colors for day and night shifts. These settings will be used as defaults when creating new shifts.
    </p>
    
    <div class="default-support-link">
      <router-link to="/settings" class="support-link" @click="selectAreaSupportTab">
        <IconComponent name="defaults" size="small" />
        Configure Default Department & Service Coverage
      </router-link>
      <p class="support-description">
        Manage porter assignments and time ranges for departments and services in the Area Support tab.
        Changes made there will only affect new shifts, not existing ones.
      </p>
    </div>
    
    <div class="shifts-container">
      <!-- Day Shift Card -->
      <div class="shift-card">
        <div class="shift-card__header">
          <h5>Day Shift</h5>
          <input 
            type="color" 
            v-model="dayShiftColor" 
            class="shift-color-picker"
            aria-label="Day shift color"
          />
        </div>
        
        <div class="shift-card__times">
          <div class="time-group">
            <label for="dayStartTime">Start Time</label>
            <input 
              type="time" 
              id="dayStartTime" 
              v-model="dayStartTime" 
            />
          </div>
          
          <div class="time-group">
            <label for="dayEndTime">End Time</label>
            <input 
              type="time" 
              id="dayEndTime" 
              v-model="dayEndTime" 
            />
          </div>
        </div>
      </div>
      
      <!-- Night Shift Card -->
      <div class="shift-card">
        <div class="shift-card__header">
          <h5>Night Shift</h5>
          <input 
            type="color" 
            v-model="nightShiftColor" 
            class="shift-color-picker"
            aria-label="Night shift color"
          />
        </div>
        
        <div class="shift-card__times">
          <div class="time-group">
            <label for="nightStartTime">Start Time</label>
            <input 
              type="time" 
              id="nightStartTime" 
              v-model="nightStartTime" 
            />
          </div>
          
          <div class="time-group">
            <label for="nightEndTime">End Time</label>
            <input 
              type="time" 
              id="nightEndTime" 
              v-model="nightEndTime" 
            />
          </div>
        </div>
      </div>
    </div>
    
    <div class="actions">
      <button 
        class="btn btn--primary" 
        @click="saveDefaults"
        :disabled="loading"
      >
        {{ loading ? 'Saving...' : 'Save Defaults' }}
      </button>
      
      <div v-if="error" class="error-message">
        {{ error }}
      </div>
      
      <div v-if="saveSuccess" class="success-message">
        Defaults saved successfully!
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useSettingsStore } from '../../stores/settingsStore';
import IconComponent from '../IconComponent.vue';

const settingsStore = useSettingsStore();

// Local state for form values
const dayStartTime = ref('');
const dayEndTime = ref('');
const dayShiftColor = ref('');
const nightStartTime = ref('');
const nightEndTime = ref('');
const nightShiftColor = ref('');

// UI state
const loading = computed(() => settingsStore.loading);
const error = computed(() => settingsStore.error);
const saveSuccess = ref(false);

// Initialize form values from store
const initializeForm = () => {
  const { day, night } = settingsStore.shiftDefaults;
  
  // Make sure to set default values in case they're missing from store
  dayStartTime.value = day.startTime || '08:00';
  dayEndTime.value = day.endTime || '16:00';
  dayShiftColor.value = day.color || '#4285F4';
  
  nightStartTime.value = night.startTime || '20:00';
  nightEndTime.value = night.endTime || '08:00';
  nightShiftColor.value = night.color || '#673AB7';
};

// Initialize with defaults immediately (don't wait for store)
dayStartTime.value = '08:00';
dayEndTime.value = '16:00';
dayShiftColor.value = '#4285F4';
nightStartTime.value = '20:00';
nightEndTime.value = '08:00';
nightShiftColor.value = '#673AB7';

// Save defaults to the store and database
const saveDefaults = async () => {
  // Reset status
  saveSuccess.value = false;
  
  // Update store values
  settingsStore.updateDayShiftDefaults({
    startTime: dayStartTime.value,
    endTime: dayEndTime.value,
    color: dayShiftColor.value
  });
  
  settingsStore.updateNightShiftDefaults({
    startTime: nightStartTime.value,
    endTime: nightEndTime.value,
    color: nightShiftColor.value
  });
  
  // Save to Supabase
  const result = await settingsStore.saveShiftDefaults();
  
  if (result) {
    saveSuccess.value = true;
    
    // Auto-hide success message after 3 seconds
    setTimeout(() => {
      saveSuccess.value = false;
    }, 3000);
  }
};

// Function to select the Area Support tab
const selectAreaSupportTab = () => {
  // Using custom event to notify parent component to switch tabs
  const event = new CustomEvent('select-tab', { 
    detail: { tabId: 'supportServices' },
    bubbles: true
  });
  document.dispatchEvent(event);
};

// Load settings on component mount
onMounted(async () => {
  await settingsStore.loadSettings();
  initializeForm();
});
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;
@use 'sass:color';

.shift-defaults-settings {
  h4 {
    font-size: mix.font-size('lg');
    margin-bottom: 8px;
  }
  
  .section-description {
    color: rgba(0, 0, 0, 0.6);
    margin-bottom: 16px;
  }
  
  .default-support-link {
    background-color: #f5f7fa;
    border-left: 4px solid #4285F4;
    border-radius: mix.radius('sm');
    padding: 16px;
    margin-bottom: 24px;
    
    .support-link {
      display: flex;
      align-items: center;
      text-decoration: none;
      color: #4285F4;
      font-weight: 500;
      font-size: mix.font-size('md');
      
      .icon {
        margin-right: 8px;
      }
      
      &:hover {
        text-decoration: underline;
      }
    }
    
    .support-description {
      margin-top: 8px;
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.6);
    }
  }
  
  .shifts-container {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 16px;
    margin-bottom: 24px;
  }
  
  .shift-card {
    background-color: white;
    border-radius: mix.radius('md');
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    padding: 16px;
    
    &__header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
      
      h5 {
        margin: 0;
        font-size: mix.font-size('md');
        font-weight: 600;
      }
      
      .shift-color-picker {
        width: 32px;
        height: 32px;
        border: 1px solid rgba(0, 0, 0, 0.2);
        border-radius: mix.radius('sm');
        cursor: pointer;
        
        &:focus {
          outline: none;
          border-color: mix.color('primary');
          box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
        }
      }
    }
    
    &__times {
      display: flex;
      gap: 16px;
      
      .time-group {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 4px;
        
        label {
          font-size: mix.font-size('sm');
          font-weight: 500;
          color: rgba(0, 0, 0, 0.7);
        }
        
        input[type="time"] {
          padding: 6px 8px;
          border: 1px solid rgba(0, 0, 0, 0.2);
          border-radius: mix.radius('sm');
          font-size: mix.font-size('md');
          
          &:focus {
            outline: none;
            border-color: mix.color('primary');
            box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
          }
        }
      }
    }
  }
  
  .actions {
    display: flex;
    align-items: center;
    gap: 16px;
    
    .btn {
      padding: 8px 16px;
      border-radius: mix.radius('md');
      font-weight: 500;
      cursor: pointer;
      border: none;
      transition: all 0.2s ease;
      
      &--primary {
        background-color: mix.color('primary');
        color: white;
        
        &:hover:not(:disabled) {
          background-color: color.adjust(mix.color('primary'), $lightness: -5%);
        }
        
        &:disabled {
          opacity: 0.6;
          cursor: not-allowed;
        }
      }
    }
    
    .error-message {
      color: #D32F2F;
      font-size: mix.font-size('sm');
    }
    
    .success-message {
      color: #388E3C;
      font-size: mix.font-size('sm');
    }
  }
}
</style>
