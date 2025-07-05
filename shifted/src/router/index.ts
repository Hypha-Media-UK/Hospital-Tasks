import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView
    },
    {
      path: '/shift-management',
      name: 'shift-management',
      component: () => import('../views/ShiftManagementView.vue')
    },
    {
      path: '/shift-management/:id',
      name: 'shift-detail',
      component: () => import('../views/ShiftDetailView.vue')
    },
    {
      path: '/archive',
      name: 'archive',
      component: () => import('../views/ArchiveView.vue')
    },
    {
      path: '/activity-sheet',
      name: 'activity-sheet',
      component: () => import('../views/ActivitySheetView.vue')
    },
    {
      path: '/sitrep',
      name: 'sitrep',
      component: () => import('../views/SitRepView.vue')
    },
    {
      path: '/defaults',
      name: 'defaults',
      component: () => import('../views/DefaultsView.vue')
    }
  ]
})

export default router
