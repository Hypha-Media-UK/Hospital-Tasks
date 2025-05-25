<template>
  <div class="app-settings">
    <h4>Display Settings</h4>
    <p class="section-description">
      Configure how dates and times are displayed throughout the application.
    </p>
    
    <div class="settings-form">
      <!-- Timezone Selection -->
      <div class="form-group">
        <label for="timezone">Timezone</label>
        <select 
          id="timezone" 
          v-model="timezone" 
          class="form-control"
          @change="updateSettings"
        >
          <option value="UTC">UTC (Coordinated Universal Time)</option>
          <option value="GMT">GMT (Greenwich Mean Time)</option>
          <option value="Europe/London">Europe/London (BST/GMT)</option>
          <option value="Europe/Paris">Europe/Paris (CET/CEST)</option>
          <option value="America/New_York">America/New_York (EST/EDT)</option>
          <option value="America/Chicago">America/Chicago (CST/CDT)</option>
          <option value="America/Denver">America/Denver (MST/MDT)</option>
          <option value="America/Los_Angeles">America/Los_Angeles (PST/PDT)</option>
          <option value="Asia/Tokyo">Asia/Tokyo (JST)</option>
          <option value="Asia/Shanghai">Asia/Shanghai (CST)</option>
          <option value="Australia/Sydney">Australia/Sydney (AEST/AEDT)</option>
        </select>
      </div>
      
      <!-- Time Format Selection -->
      <div class="form-group">
        <label>Time Format</label>
        <div class="time-format-options">
          <div class="format-option">
            <input 
              type="radio" 
              id="format24h" 
              value="24h" 
              v-model="timeFormat"
              @change="updateSettings"
            />
            <label for="format24h">24-hour (14:30)</label>
          </div>
          <div class="format-option">
            <input 
              type="radio" 
              id="format12h" 
              value="12h" 
              v-model="timeFormat"
              @change="updateSettings"
            />
            <label for="format12h">12-hour (2:30 PM)</label>
          </div>
        </div>
      </div>
      
      <!-- Save Button -->
      <div class="form-actions">
        <button 
          @click="saveSettings" 
          class="btn btn-primary" 
          :disabled="isSaving"
        >
          {{ isSaving ? 'Saving...' : 'Save Settings' }}
        </button>
      </div>
      
      <div v-if="saveError" class="error-message">
        {{ saveError }}
      </div>
      <div v-if="saveSuccess" class="success-message">
        Settings saved successfully!
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { useSettingsStore } from '../../stores/settingsStore';

const settingsStore = useSettingsStore();

// Local state
const timezone = ref('UTC');
const timeFormat = ref('24h');
const isSaving = ref(false);
const saveError = ref('');
const saveSuccess = ref(false);

// Load settings when component mounts
onMounted(async () => {
  // Load from store
  timezone.value = settingsStore.appSettings.timezone;
  timeFormat.value = settingsStore.appSettings.timeFormat;
});

// Update store when settings change
function updateSettings() {
  settingsStore.updateAppSettings({
    timezone: timezone.value,
    timeFormat: timeFormat.value
  });
  
  // Clear any previous messages
  saveError.value = '';
  saveSuccess.value = false;
}

// Save settings to backend
async function saveSettings() {
  if (isSaving.value) return;
  
  isSaving.value = true;
  saveError.value = '';
  saveSuccess.value = false;
  
  try {
    // Update and save
    settingsStore.updateAppSettings({
      timezone: timezone.value,
      timeFormat: timeFormat.value
    });
    
    const result = await settingsStore.saveAppSettings();
    
    if (result) {
      saveSuccess.value = true;
      
      // Hide success message after 3 seconds
      setTimeout(() => {
        saveSuccess.value = false;
      }, 3000);
    } else {
      saveError.value = settingsStore.error || 'Failed to save settings';
    }
  } catch (error) {
    console.error('Error saving app settings:', error);
    saveError.value = 'An unexpected error occurred';
  } finally {
    isSaving.value = false;
  }
}
</script>

<style lang="scss" scoped>
@use "sass:color";
.app-settings {
  margin-bottom: 32px;
  
  .section-description {
    color: rgba(0, 0, 0, 0.6);
    margin-bottom: 16px;
  }
  
  .settings-form {
    max-width: 500px;
    
    .form-group {
      margin-bottom: 16px;
      
      label {
        display: block;
        font-weight: 500;
        margin-bottom: 6px;
      }
      
      .form-control {
        width: 100%;
        padding: 8px 12px;
        border: 1px solid #ccc;
        border-radius: 4px;
        font-size: 14px;
      }
    }
    
    .time-format-options {
      display: flex;
      gap: 16px;
      
      .format-option {
        display: flex;
        align-items: center;
        gap: 6px;
        
        input[type="radio"] {
          margin: 0;
        }
      }
    }
    
    .form-actions {
      margin-top: 24px;
    }
    
    .error-message {
      margin-top: 12px;
      padding: 8px 12px;
      background-color: rgba(220, 53, 69, 0.1);
      border: 1px solid rgba(220, 53, 69, 0.3);
      border-radius: 4px;
      color: #dc3545;
      font-size: 14px;
    }
    
    .success-message {
      margin-top: 12px;
      padding: 8px 12px;
      background-color: rgba(52, 168, 83, 0.1);
      border: 1px solid rgba(52, 168, 83, 0.3);
      border-radius: 4px;
      color: #34A853;
      font-size: 14px;
    }
  }
}

.btn {
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.2s, background-color 0.2s;
  
  &:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
  
  &-primary {
    background-color: #4285F4;
    color: white;
    
    &:hover:not(:disabled) {
      background-color: color.scale(#4285F4, $lightness: -10%);
    }
  }
}
</style>
