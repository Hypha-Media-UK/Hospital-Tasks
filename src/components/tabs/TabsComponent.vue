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
      <template #settings>
        <SettingsTabContent />
      </template>
    </TabContent>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import TabHeader from './TabHeader.vue';
import TabContent from './TabContent.vue';
import StaffTabContent from './tab-contents/StaffTabContent.vue';
import LocationsTabContent from './tab-contents/LocationsTabContent.vue';
import TaskTypesTabContent from './tab-contents/TaskTypesTabContent.vue';
import SettingsTabContent from './tab-contents/SettingsTabContent.vue';

const tabs = [
  { id: 'staff', label: 'Staff' },
  { id: 'locations', label: 'Locations' },
  { id: 'taskTypes', label: 'Task Types' },
  { id: 'settings', label: 'Settings' }
];

const activeTab = ref('staff');

function setActiveTab(tabId) {
  activeTab.value = tabId;
}
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;

.tabs {
  &__header {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    border-bottom: 1px solid rgba(0, 0, 0, 0.1);
    margin-bottom: 16px;
    
    @media (max-width: 600px) {
      grid-template-columns: repeat(2, 1fr);
      grid-template-rows: repeat(2, auto);
    }
  }
}
</style>
