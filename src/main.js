import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import router from './router';
import './assets/css/main.css';

// Import stores that need initialization
import { useShiftsStore } from './stores/shiftsStore';
import { useSettingsStore } from './stores/settingsStore';

const app = createApp(App);

// Initialize Pinia store
app.use(createPinia());

// Initialize router
app.use(router);

// Initialize the app
app.mount('#app');

// Initialize store data
const settingsStore = useSettingsStore();
const shiftsStore = useShiftsStore();

// Load settings first, then initialize other stores
settingsStore.loadSettings().then(() => {
  shiftsStore.initialize();
});
