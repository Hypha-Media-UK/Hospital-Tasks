<template>
  <header class="header">
    <nav class="header__nav">
      <div class="header__nav-left">
        <router-link to="/" aria-label="Home">
          <HomeIcon />
        </router-link>
      </div>
      
      <!-- DEBUG CLOCK - TEMPORARY -->
      <div class="debug-clock">
        <div class="clock-title">DEBUG CLOCK</div>
        <div class="clock-time">
          <div class="time-row">
            <span class="time-label">Browser:</span>
            <span class="time-value">{{ browserTime }}</span>
          </div>
          <div class="time-row">
            <span class="time-label">Browser TZ:</span>
            <span class="time-value">{{ browserTimezone }}</span>
          </div>
          <div class="time-row">
            <span class="time-label">App ({{ appTimezone }}):</span>
            <span class="time-value">{{ appTime }}</span>
          </div>
          <div class="time-row">
            <span class="time-label">GMT (UTC):</span>
            <span class="time-value">{{ gmtTime }}</span>
          </div>
          <div class="time-row">
            <span class="time-label">ISO UTC:</span>
            <span class="time-value">{{ isoTime }}</span>
          </div>
          <div class="time-row">
            <span class="time-label">Raw Date:</span>
            <span class="time-value">{{ rawTime }}</span>
          </div>
        </div>
      </div>
      
      <div class="header__nav-right">
        <router-link to="/archive" aria-label="Archive">
          <ArchiveIcon />
        </router-link>
        <router-link to="/settings" aria-label="Settings">
          <SettingsIcon />
        </router-link>
      </div>
    </nav>
  </header>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useSettingsStore } from '../stores/settingsStore';
import HomeIcon from './icons/HomeIcon.vue';
import ArchiveIcon from './icons/ArchiveIcon.vue';
import SettingsIcon from './icons/SettingsIcon.vue';

const settingsStore = useSettingsStore();

// Reactive time values
const currentTime = ref(new Date());
let timeInterval = null;

// Update time every second
const updateTime = () => {
  currentTime.value = new Date();
};

// Computed time displays
const browserTime = computed(() => {
  return currentTime.value.toLocaleString('en-GB', {
    timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
});

const appTimezone = computed(() => {
  return settingsStore.appSettings?.timezone || 'GMT';
});

const appTime = computed(() => {
  const timezone = appTimezone.value === 'GMT' ? 'UTC' : appTimezone.value;
  return currentTime.value.toLocaleString('en-GB', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
});

const gmtTime = computed(() => {
  return currentTime.value.toLocaleString('en-GB', {
    timeZone: 'UTC',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
});

const browserTimezone = computed(() => {
  return Intl.DateTimeFormat().resolvedOptions().timeZone;
});

const isoTime = computed(() => {
  return currentTime.value.toISOString();
});

const rawTime = computed(() => {
  return currentTime.value.toString();
});

onMounted(() => {
  // Load settings to get timezone
  settingsStore.loadSettings();
  
  // Start the clock
  timeInterval = setInterval(updateTime, 1000);
  updateTime(); // Initial update
});

onUnmounted(() => {
  if (timeInterval) {
    clearInterval(timeInterval);
  }
});
</script>

<style lang="scss" scoped>
.debug-clock {
  background-color: #ff6b6b;
  color: white;
  padding: 0.5rem 1rem;
  border-radius: 8px;
  font-family: 'Courier New', monospace;
  font-size: 0.75rem;
  border: 2px solid #ff5252;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  
  .clock-title {
    font-weight: bold;
    text-align: center;
    margin-bottom: 0.25rem;
    font-size: 0.7rem;
    letter-spacing: 1px;
  }
  
  .clock-time {
    display: flex;
    flex-direction: column;
    gap: 0.1rem;
  }
  
  .time-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    min-width: 280px;
  }
  
  .time-label {
    font-weight: 600;
    margin-right: 0.5rem;
    min-width: 80px;
  }
  
  .time-value {
    font-weight: 400;
    font-family: 'Courier New', monospace;
  }
}

// Make header nav a flexbox to accommodate the clock
.header__nav {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 1rem;
}

.header__nav-left,
.header__nav-right {
  display: flex;
  align-items: center;
  gap: 1rem;
}
</style>
