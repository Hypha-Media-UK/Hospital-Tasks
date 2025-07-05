<template>
  <div class="app-layout">
    <AppHeader />
    <main class="main-content">
      <div class="card">
        <div class="card-header">
          <h1 class="text-xl font-semibold">Shift Management Dashboard</h1>
        </div>
        <div class="card-body">
          <BaseTabs :tabs="tabs" default-tab="active-shifts" query-param="tab">
            <template #default="{ activeTab }">
              <div v-if="activeTab === 'active-shifts'">
                <ActiveShiftsTab />
              </div>
              <div v-if="activeTab === 'create-shift'">
                <CreateShiftTab />
              </div>
            </template>
          </BaseTabs>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import AppHeader from '../components/AppHeader.vue'
import BaseTabs from '../components/ui/BaseTabs.vue'
import ActiveShiftsTab from '../components/tabs/ActiveShiftsTab.vue'
import CreateShiftTab from '../components/tabs/CreateShiftTab.vue'

const tabs = [
  { id: 'active-shifts', label: 'Active Shifts' },
  { id: 'create-shift', label: 'Create New Shift' }
]
</script>

<style scoped>
.app-layout {
  container-type: inline-size;
}
</style>
