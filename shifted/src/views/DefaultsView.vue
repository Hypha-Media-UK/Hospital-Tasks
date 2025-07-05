<template>
  <div class="app-layout">
    <AppHeader />
    <main class="main-content">
      <div class="card">
        <div class="card-header">
          <h1 class="text-xl font-semibold">Hospital Defaults</h1>
          <p class="text-gray-600">Configure staff, locations, tasks, and system defaults</p>
        </div>
        <div class="card-body">
          <BaseTabs
            :tabs="managementTabs"
            default-tab="staff"
            query-param="section"
            show-mobile-dropdown
            @tab-change="handleTabChange"
          >
            <template #default="{ activeTab }">
              <div class="management-content">
                <!-- Staff Management -->
                <div v-if="activeTab === 'staff'" class="management-section">
                  <StaffManagement />
                </div>

                <!-- Locations Management -->
                <div v-if="activeTab === 'locations'" class="management-section">
                  <LocationsManagement />
                </div>

                <!-- Task Types Management -->
                <div v-if="activeTab === 'taskTypes'" class="management-section">
                  <TaskTypesManagement />
                </div>

                <!-- Area Support Management -->
                <div v-if="activeTab === 'areaSupport'" class="management-section">
                  <AreaSupportManagement />
                </div>

                <!-- Settings -->
                <div v-if="activeTab === 'settings'" class="management-section">
                  <SettingsTabs />
                </div>
              </div>
            </template>
          </BaseTabs>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, h } from 'vue'
import AppHeader from '../components/AppHeader.vue'
import BaseTabs from '../components/ui/BaseTabs.vue'
import SettingsTabs from '../components/settings/SettingsTabs.vue'
import AreaSupportManagement from '../components/support-services/AreaSupportManagement.vue'
import StaffManagement from '../components/staff/StaffManagement.vue'
import LocationsManagement from '../components/locations/LocationsManagement.vue'

// Import icons
import StarIcon from '../components/icons/StarIcon.vue'
import MapPinIcon from '../components/icons/MapPinIcon.vue'
import TaskIcon from '../components/icons/TaskIcon.vue'
import SettingsIcon from '../components/icons/SettingsIcon.vue'

// Placeholder components - will be created next

const TaskTypesManagement = {
  render() {
    return h('div', { class: 'placeholder-section' }, [
      h('h3', '📋 Task Types Management'),
      h('p', 'Define task categories and specific task items.'),
      h('div', { class: 'placeholder-cards' }, [
        h('div', { class: 'placeholder-card' }, 'Task Categories'),
        h('div', { class: 'placeholder-card' }, 'Task Items'),
        h('div', { class: 'placeholder-card' }, 'Department Assignments')
      ])
    ])
  }
}


const managementTabs = computed(() => [
  { id: 'staff', label: 'Staff', icon: StarIcon },
  { id: 'locations', label: 'Locations', icon: MapPinIcon },
  { id: 'taskTypes', label: 'Task Types', icon: TaskIcon },
  { id: 'areaSupport', label: 'Area Support', icon: StarIcon },
  { id: 'settings', label: 'System', icon: SettingsIcon }
])

const handleTabChange = (tabId: string) => {
  // Handle any tab-specific logic here if needed
}
</script>

<style scoped>
.app-layout {
  container-type: inline-size;
}

.management-content {
  min-height: 500px;
}

.management-section {
  display: block;
}

/* Placeholder styling - will be replaced with proper components */
.placeholder-section {
  padding: 2rem 0;
}

.placeholder-section h3 {
  font-size: 1.5rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
  color: #333;
}

.placeholder-section p {
  color: #666;
  margin-bottom: 2rem;
}

.placeholder-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
}

.placeholder-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 2rem;
  text-align: center;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  font-weight: 500;
  color: #4285f4;
  cursor: pointer;
  transition: all 0.2s ease;
}

.placeholder-card:hover {
  border-color: #4285f4;
  box-shadow: 0 4px 8px rgba(66, 133, 244, 0.1);
}
</style>
