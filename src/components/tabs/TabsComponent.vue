<template>
  <div class="tabs">
    <!-- Desktop Tabs -->
    <div class="desktop-tabs">
      <AnimatedTabs
        v-model="activeTab"
        :tabs="formattedTabs"
        @tab-change="handleTabChange"
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
      </AnimatedTabs>
    </div>
    
    <!-- Mobile Menu -->
    <div class="mobile-tabs">
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
  </div>
</template>

<script setup>
import { ref, onMounted, computed, nextTick, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { motion } from 'motion-v';
import IconComponent from '../IconComponent.vue';
import AnimatedTabs from '../shared/AnimatedTabs.vue';
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

// Format tabs for the AnimatedTabs component
const formattedTabs = computed(() => {
  return tabs.map(tab => ({
    id: tab.id,
    label: tab.label
  }));
});

// Handle tab change from AnimatedTabs component
function handleTabChange(tabId) {
  setActiveTab(tabId);
}

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
    
    // Special handling for settings tab to properly set settings-tab parameter
    if (route.path === '/settings' && route.query.tab === 'settings') {
      // If we're on settings page and tab=settings, set settings-tab parameter
      // to ensure sub-tabs work correctly
      const settingsTabParam = route.query['settings-tab'];
      if (!settingsTabParam) {
        // If no settings-tab parameter exists, add it with default value
        router.replace({ 
          query: { 
            ...route.query, 
            'settings-tab': 'shiftDefaults'  // Default sub-tab
          }
        }).catch(err => {
          if (err.name !== 'NavigationDuplicated') {
            console.error(err);
          }
        });
      }
    }
  } else if (route.path === '/settings') {
    // Check if the user was redirected from /default-support
    const redirectedFrom = route.redirectedFrom?.path;
    if (redirectedFrom === '/default-support') {
      activeTab.value = 'supportServices';
      // Update URL to include tab param
      updateQueryParam(activeTab.value);
    } else {
      activeTab.value = 'settings'; // Set to settings tab for settings page
      // Update URL to include tab param
      updateQueryParam(activeTab.value);
      
      // Also set the settings-tab parameter if not already set
      if (!route.query['settings-tab']) {
        router.replace({ 
          query: { 
            ...route.query, 
            'tab': 'settings',
            'settings-tab': 'shiftDefaults'  // Default sub-tab
          }
        }).catch(err => {
          if (err.name !== 'NavigationDuplicated') {
            console.error(err);
          }
        });
      }
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

<!-- Styles are now handled by the global CSS layers -->


