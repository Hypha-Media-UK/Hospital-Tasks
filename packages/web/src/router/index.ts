import { createRouter, createWebHistory } from 'vue-router';

// Lazy load components for better performance
const Dashboard = () => import('../views/Dashboard.vue');
const StaffView = () => import('../views/StaffView.vue');
const BuildingsView = () => import('../views/BuildingsView.vue');
const DepartmentsView = () => import('../views/DepartmentsView.vue');
const TaskTypesView = () => import('../views/TaskTypesView.vue');
const ShiftsView = () => import('../views/ShiftsView.vue');

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      name: 'Dashboard',
      component: Dashboard,
    },
    {
      path: '/staff',
      name: 'Staff',
      component: StaffView,
    },
    {
      path: '/buildings',
      name: 'Buildings',
      component: BuildingsView,
    },
    {
      path: '/departments',
      name: 'Departments',
      component: DepartmentsView,
    },
    {
      path: '/task-types',
      name: 'TaskTypes',
      component: TaskTypesView,
    },
    {
      path: '/shifts',
      name: 'Shifts',
      component: ShiftsView,
    },
  ],
});

export default router;
