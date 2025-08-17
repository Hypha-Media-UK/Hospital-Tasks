<template>
  <div class="app-settings">
    <h4>Display Settings</h4>
    <p class="section-description">
      Times are automatically displayed in your browser's timezone using 24-hour format.
    </p>
    
    <div class="settings-info">
      <div class="info-item">
        <strong>Timezone:</strong> Automatically detected from your browser
      </div>
      <div class="info-item">
        <strong>Time Format:</strong> 24-hour format (14:30)
      </div>
      <div class="info-item">
        <strong>Current Time:</strong> {{ currentTime }}
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue';

const currentTime = ref('');

// Update current time display
function updateCurrentTime() {
  currentTime.value = new Date().toLocaleTimeString('en-GB', {
    hour12: false,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
}

let timeInterval;

onMounted(() => {
  updateCurrentTime();
  // Update time every second
  timeInterval = setInterval(updateCurrentTime, 1000);
});

onUnmounted(() => {
  if (timeInterval) {
    clearInterval(timeInterval);
  }
});
</script>

<style lang="scss" scoped>
@use "sass:color";
.app-settings {
  margin-bottom: 32px;
  
  .section-description {
    color: rgba(0, 0, 0, 0.6);
    margin-bottom: 16px;
  }
  
  .settings-info {
    max-width: 500px;
    
    .info-item {
      margin-bottom: 12px;
      padding: 12px;
      background-color: rgba(66, 133, 244, 0.05);
      border: 1px solid rgba(66, 133, 244, 0.2);
      border-radius: 4px;
      
      strong {
        color: #4285F4;
      }
    }
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
