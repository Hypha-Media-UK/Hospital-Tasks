import { createRouter, createWebHistory } from 'vue-router';
import HomeView from '../views/HomeView.vue';
import ArchiveView from '../views/ArchiveView.vue';
import SettingsView from '../views/SettingsView.vue';
import ShiftManagementView from '../views/ShiftManagementView.vue';

const routes = [
  {
    path: '/',
    name: 'home',
    component: HomeView
  },
  {
    path: '/archive',
    name: 'archive',
    component: ArchiveView
  },
  {
    path: '/settings',
    name: 'settings',
    component: SettingsView
  },
  {
    path: '/shift/:id',
    name: 'shift',
    component: ShiftManagementView
  },
  {
    path: '/default-support',
    name: 'default-support-redirect',
    redirect: '/settings'
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

export default router;
