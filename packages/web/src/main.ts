import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import router from './router';

// Import global styles
import './styles/main.css';

// Create app
const app = createApp(App);

// Install plugins
app.use(createPinia());
app.use(router);

// Mount app
app.mount('#app');

console.log('🚀 Hospital Tasks V2 - Modern, DRY, and performant!');
