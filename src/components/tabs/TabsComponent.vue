<template>
  <div class="tabs">
    <div class="tabs__header">
      <!-- Desktop tabs -->
      <TabHeader 
        v-for="tab in tabs" 
        :key="tab.id"
        :label="tab.label"
        :isActive="activeTab === tab.id"
        @click="setActiveTab(tab.id)"
        class="desktop-tab"
      />
      
      <!-- Mobile menu button -->
      <button 
        class="mobile-menu-button"
        @click="toggleMobileMenu"
        aria-label="Toggle menu"
      >
        <IconComponent name="menu" />
        <span class="active-tab-label">{{ activeTabLabel }}</span>
      </button>
      
      <!-- Mobile dropdown menu -->
      <div 
        class="mobile-menu" 
        :class="{ 'mobile-menu--open': isMobileMenuOpen }"
      >
        <button 
          v-for="tab in tabs" 
          :key="tab.id"
          class="mobile-menu__item"
          :class="{ 'mobile-menu__item--active': activeTab === tab.id }"
          @click="setActiveTabMobile(tab.id)"
        >
          {{ tab.label }}
        </button>
      </div>
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
import { ref, onMounted, computed } from 'vue';
import { useRoute } from 'vue-router';
import TabHeader from './TabHeader.vue';
import TabContent from './TabContent.vue';
import IconComponent from '../IconComponent.vue';
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
const isMobileMenuOpen = ref(false);

// Computed property to get the label of the active tab
const activeTabLabel = computed(() => {
  const tab = tabs.find(t => t.id === activeTab.value);
  return tab ? tab.label : '';
});

// Set active tab based on current route
onMounted(() => {
  if (route.path === '/settings') {
    // Check if the user was redirected from /default-support
    const redirectedFrom = route.redirectedFrom?.path;
    if (redirectedFrom === '/default-support') {
      activeTab.value = 'supportServices';
    } else {
      activeTab.value = 'staff'; // Default to first tab for settings page
    }
  } else if (route.path === '/') {
    activeTab.value = 'staff'; // Default for home route
  }
  
  // Listen for custom tab selection events (from ShiftDefaultsSettings)
  document.addEventListener('select-tab', (event) => {
    if (event.detail && event.detail.tabId) {
      activeTab.value = event.detail.tabId;
    }
  });
});

function setActiveTab(tabId) {
  activeTab.value = tabId;
}

function setActiveTabMobile(tabId) {
  activeTab.value = tabId;
  isMobileMenuOpen.value = false; // Close menu after selection
}

function toggleMobileMenu() {
  isMobileMenuOpen.value = !isMobileMenuOpen.value;
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
    position: relative;
    
    @media (max-width: 800px) {
      grid-template-columns: 1fr; // Single column for mobile menu button
    }
  }
}

// Desktop tabs
.desktop-tab {
  @media (max-width: 800px) {
    display: none;
  }
}

// Mobile menu button
.mobile-menu-button {
  display: none;
  align-items: center;
  padding: 12px 16px;
  background: transparent;
  border: none;
  font-weight: 500;
  cursor: pointer;
  color: mix.color('text');
  width: 100%;
  grid-column: 1 / -1;
  justify-content: flex-start;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  
  @media (max-width: 800px) {
    display: flex;
  }
  
  .icon {
    width: 24px;
    height: 24px;
    margin-right: 12px;
  }
  
  .active-tab-label {
    font-weight: 600;
    color: mix.color('primary');
  }
}

// Mobile dropdown menu
.mobile-menu {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background-color: white;
  border-radius: 0 0 4px 4px;
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
  z-index: 10;
  max-height: 0;
  overflow: hidden;
  transition: max-height 0.3s ease, opacity 0.2s ease;
  opacity: 0;
  
  &--open {
    max-height: 300px;
    opacity: 1;
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-top: none;
  }
  
  &__item {
    display: block;
    width: 100%;
    padding: 12px 16px;
    text-align: left;
    background: transparent;
    border: none;
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
    font-weight: 500;
    cursor: pointer;
    
    &:last-child {
      border-bottom: none;
    }
    
    &:hover {
      background-color: rgba(0, 0, 0, 0.03);
    }
    
    &--active {
      color: mix.color('primary');
      background-color: rgba(mix.color('primary'), 0.05);
      
      &:hover {
        background-color: rgba(mix.color('primary'), 0.08);
      }
    }
  }
}
</style>
