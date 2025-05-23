import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import router from './router';
import './assets/scss/main.scss';

// Import stores that need initialization
import { useShiftsStore } from './stores/shiftsStore';

const app = createApp(App);

// Initialize Pinia store
app.use(createPinia());

// Initialize router
app.use(router);

// Initialize the app
app.mount('#app');

// Initialize store data
const shiftsStore = useShiftsStore();
shiftsStore.initialize();
