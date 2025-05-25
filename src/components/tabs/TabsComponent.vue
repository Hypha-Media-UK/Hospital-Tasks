<template>
  <div class="tabs">
    <div class="tabs__header">
      <TabHeader 
        v-for="tab in tabs" 
        :key="tab.id"
        :label="tab.label"
        :isActive="activeTab === tab.id"
        @click="setActiveTab(tab.id)"
      />
    </div>
    
    <TabContent :activeTab="activeTab">
      <template #staff>
        <StaffTabContent />
      </template>
      <template #locations>
        <LocationsTabContent />
      </template>
      <template #taskTypes>
        <TaskTypesTabContent />
      </template>
      <template #supportServices>
        <SupportServicesTabContent />
      </template>
      <template #settings>
        <SettingsTabContent />
      </template>
    </TabContent>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import TabHeader from './TabHeader.vue';
import TabContent from './TabContent.vue';
import StaffTabContent from './tab-contents/StaffTabContent.vue';
import LocationsTabContent from './tab-contents/LocationsTabContent.vue';
import TaskTypesTabContent from './tab-contents/TaskTypesTabContent.vue';
import SupportServicesTabContent from './tab-contents/SupportServicesTabContent.vue';
import SettingsTabContent from './tab-contents/SettingsTabContent.vue';

const route = useRoute();

const tabs = [
  { id: 'staff', label: 'Staff' },
  { id: 'locations', label: 'Locations' },
  { id: 'taskTypes', label: 'Task Types' },
  { id: 'supportServices', label: 'Area Support' },
  { id: 'settings', label: 'Settings' }
];

// Initialize active tab based on route
const activeTab = ref('staff');

// Set active tab based on current route
onMounted(() => {
  if (route.path === '/settings') {
    activeTab.value = 'settings';
  } else if (route.path === '/') {
    activeTab.value = 'staff'; // Default for home route
  }
});

function setActiveTab(tabId) {
  activeTab.value = tabId;
}
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;

.tabs {
  &__header {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
    margin-bottom: 16px;
    
    @media (max-width: 600px) {
      grid-template-columns: repeat(3, 1fr);
      grid-template-rows: repeat(2, auto);
    }
  }
}
</style>
