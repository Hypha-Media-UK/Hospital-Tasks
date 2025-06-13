<template>
  <div class="tabs">
    <div class="tabs__header" ref="tabsHeaderRef">
      <!-- Desktop tabs -->
      <TabHeader 
        v-for="tab in tabs" 
        :key="tab.id"
        :label="tab.label"
        :isActive="activeTab === tab.id"
        @click="setActiveTab(tab.id)"
        class="desktop-tab"
        ref="tabRefs"
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
      
      <!-- Sliding active indicator for desktop -->
      <motion.div 
        class="active-indicator"
        :animate="{ 
          x: indicatorPosition, 
          width: indicatorWidth,
          opacity: 1
        }"
        :initial="{ opacity: 0 }"
        :transition="{ 
          type: 'spring', 
          stiffness: 500, 
          damping: 30 
        }"
      ></motion.div>
    </div>
    
    <TabContent 
      :activeTab="activeTab"
      :direction="tabChangeDirection"
    >
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
import { ref, onMounted, computed, nextTick, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { motion } from 'motion-v';
import TabHeader from './TabHeader.vue';
import TabContent from './TabContent.vue';
import IconComponent from '../IconComponent.vue';
import StaffTabContent from './tab-contents/StaffTabContent.vue';
import LocationsTabContent from './tab-contents/LocationsTabContent.vue';
import TaskTypesTabContent from './tab-contents/TaskTypesTabContent.vue';
import SupportServicesTabContent from './tab-contents/SupportServicesTabContent.vue';
import SettingsTabContent from './tab-contents/SettingsTabContent.vue';

const route = useRoute();
const router = useRouter();

const tabs = [
  { id: 'staff', label: 'Staff' },
  { id: 'locations', label: 'Locations' },
  { id: 'taskTypes', label: 'Task Types' },
  { id: 'supportServices', label: 'Area Support' },
  { id: 'settings', label: 'Settings' }
];

// Initialize active tab - will be updated in onMounted
const activeTab = ref('staff');
const isMobileMenuOpen = ref(false);
const tabRefs = ref([]);
const tabsHeaderRef = ref(null);
const indicatorPosition = ref(0);
const indicatorWidth = ref(0);
const tabChangeDirection = ref(0);

// Computed property to get the label of the active tab
const activeTabLabel = computed(() => {
  const tab = tabs.find(t => t.id === activeTab.value);
  return tab ? tab.label : '';
});

// Calculate the indicator position based on the active tab
function updateIndicatorPosition() {
  nextTick(() => {
    if (!tabRefs.value || tabRefs.value.length === 0) return;
    
    const activeIndex = tabs.findIndex(tab => tab.id === activeTab.value);
    if (activeIndex === -1) return;
    
    // The ref might be an object with a tabRef property, or it might be a direct DOM ref
    // Handle both cases safely
    const activeTabRef = tabRefs.value[activeIndex];
    if (!activeTabRef) return;
    
    // Get the actual DOM element, whether from tabRef property or direct ref
    const activeTabElement = activeTabRef.tabRef || activeTabRef.$el || activeTabRef;
    if (!activeTabElement || typeof activeTabElement.getBoundingClientRect !== 'function') return;
    
    // Make sure tabsHeaderRef exists and is a DOM element
    if (!tabsHeaderRef.value || typeof tabsHeaderRef.value.getBoundingClientRect !== 'function') return;
    
    const tabHeaderRect = tabsHeaderRef.value.getBoundingClientRect();
    const activeTabRect = activeTabElement.getBoundingClientRect();
    
    // Calculate position relative to the tab header
    indicatorPosition.value = activeTabRect.left - tabHeaderRect.left;
    indicatorWidth.value = activeTabRect.width;
  });
}

// Watch for changes to the active tab to update the indicator
watch(activeTab, () => {
  updateIndicatorPosition();
});

// Set active tab based on current route or query parameter
onMounted(() => {
  // First check if there's a tab query parameter
  if (route.query.tab && tabs.some(tab => tab.id === route.query.tab)) {
    // If there's a valid tab query parameter, use it
    activeTab.value = route.query.tab;
  } else if (route.path === '/settings') {
    // Check if the user was redirected from /default-support
    const redirectedFrom = route.redirectedFrom?.path;
    if (redirectedFrom === '/default-support') {
      activeTab.value = 'supportServices';
      // Update URL to include tab param
      updateQueryParam(activeTab.value);
    } else {
      activeTab.value = 'staff'; // Default to first tab for settings page
      // Update URL to include tab param
      updateQueryParam(activeTab.value);
    }
  } else if (route.path === '/') {
    activeTab.value = 'staff'; // Default for home route
    // Update URL to include tab param
    updateQueryParam(activeTab.value);
  }
  
  // Listen for custom tab selection events (from ShiftDefaultsSettings)
  document.addEventListener('select-tab', (event) => {
    if (event.detail && event.detail.tabId) {
      setActiveTab(event.detail.tabId);
    }
  });
  
  // Initialize the indicator position
  updateIndicatorPosition();
  
  // Update indicator position on window resize
  window.addEventListener('resize', updateIndicatorPosition);
});

// Helper function to update the URL query parameter
function updateQueryParam(tabId) {
  router.replace({ 
    query: { 
      ...route.query, 
      tab: tabId 
    }
  }).catch(err => {
    // Handle navigation errors silently (to avoid console errors on duplicated navigation)
    if (err.name !== 'NavigationDuplicated') {
      console.error(err);
    }
  });
}

function setActiveTab(tabId) {
  // Calculate direction of tab change
  const oldIndex = tabs.findIndex(tab => tab.id === activeTab.value);
  const newIndex = tabs.findIndex(tab => tab.id === tabId);
  
  if (oldIndex !== -1 && newIndex !== -1) {
    tabChangeDirection.value = newIndex > oldIndex ? 1 : -1;
  } else {
    tabChangeDirection.value = 0;
  }
  
  activeTab.value = tabId;
  updateQueryParam(tabId);
}

function setActiveTabMobile(tabId) {
  setActiveTab(tabId);
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

// Active indicator
.active-indicator {
  position: absolute;
  bottom: -1px;
  height: 2px;
  background-color: mix.color('primary');
  z-index: 1;
  
  @media (max-width: 800px) {
    display: none;
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
