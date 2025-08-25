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

<!-- Styles are now handled by the global CSS layers -->