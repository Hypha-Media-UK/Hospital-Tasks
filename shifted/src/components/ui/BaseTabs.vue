<template>
  <div class="base-tabs">
    <!-- Tab Headers -->
    <div class="tabs-header" :class="{ 'tabs-header--mobile-hidden': hideMobileHeaders }">
      <button
        v-for="tab in tabs"
        :key="tab.id"
        :class="['tab-button', { 'tab-button--active': activeTab === tab.id }]"
        @click="setActiveTab(tab.id)"
      >
        <component v-if="tab.icon" :is="tab.icon" :size="16" />
        {{ tab.label }}
      </button>
    </div>

    <!-- Mobile Dropdown (when needed) -->
    <div v-if="showMobileDropdown" class="mobile-dropdown">
      <button
        class="mobile-dropdown-trigger"
        @click="toggleMobileMenu"
        :aria-expanded="isMobileMenuOpen"
      >
        <component v-if="activeTabData?.icon" :is="activeTabData.icon" :size="16" />
        {{ activeTabData?.label }}
        <span class="dropdown-arrow" :class="{ 'dropdown-arrow--open': isMobileMenuOpen }">▼</span>
      </button>

      <div v-if="isMobileMenuOpen" class="mobile-menu">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          :class="['mobile-menu-item', { 'mobile-menu-item--active': activeTab === tab.id }]"
          @click="setActiveTabMobile(tab.id)"
        >
          <component v-if="tab.icon" :is="tab.icon" :size="16" />
          {{ tab.label }}
        </button>
      </div>
    </div>

    <!-- Tab Content -->
    <div class="tab-content">
      <slot :activeTab="activeTab" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'

interface Tab {
  id: string
  label: string
  icon?: any
}

interface Props {
  tabs: Tab[]
  defaultTab?: string
  queryParam?: string
  showMobileDropdown?: boolean
  hideMobileHeaders?: boolean
}

interface Emits {
  tabChange: [tabId: string]
}

const props = withDefaults(defineProps<Props>(), {
  defaultTab: '',
  queryParam: 'tab',
  showMobileDropdown: false,
  hideMobileHeaders: false
})

const emit = defineEmits<Emits>()
const route = useRoute()
const router = useRouter()

const activeTab = ref('')
const isMobileMenuOpen = ref(false)

const activeTabData = computed(() =>
  props.tabs.find(tab => tab.id === activeTab.value)
)

const setActiveTab = (tabId: string) => {
  if (activeTab.value === tabId) return

  activeTab.value = tabId
  updateQueryParam(tabId)
  emit('tabChange', tabId)
}

const setActiveTabMobile = (tabId: string) => {
  setActiveTab(tabId)
  isMobileMenuOpen.value = false
}

const toggleMobileMenu = () => {
  isMobileMenuOpen.value = !isMobileMenuOpen.value
}

const updateQueryParam = (tabId: string) => {
  if (!props.queryParam) return

  router.replace({
    query: {
      ...route.query,
      [props.queryParam]: tabId
    }
  }).catch(err => {
    if (err.name !== 'NavigationDuplicated') {
      console.error(err)
    }
  })
}


const handleClickOutside = (event: Event) => {
  const target = event.target as Element
  if (!target.closest('.mobile-dropdown')) {
    isMobileMenuOpen.value = false
  }
}

onMounted(() => {
  // Initialize active tab from query param or default
  const queryTab = route.query[props.queryParam] as string
  if (queryTab && props.tabs.some(tab => tab.id === queryTab)) {
    activeTab.value = queryTab
  } else if (props.defaultTab) {
    activeTab.value = props.defaultTab
  } else if (props.tabs.length > 0) {
    activeTab.value = props.tabs[0].id
  }

  // Set up click outside detection
  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<style scoped>
.base-tabs {
  width: 100%;
}

/* Tab Headers */
.tabs-header {
  display: flex;
  border-bottom: 1px solid #e2e8f0;
  margin-bottom: 1.5rem;
  overflow-x: auto;
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.tabs-header::-webkit-scrollbar {
  display: none;
}

.tabs-header--mobile-hidden {
  @media (max-width: 768px) {
    display: none;
  }
}

.tab-button {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  border: none;
  background: none;
  cursor: pointer;
  font-weight: 500;
  color: #64748b;
  border-bottom: 2px solid transparent;
  transition: all 0.2s ease;
  white-space: nowrap;
  min-width: fit-content;
}

.tab-button:hover {
  color: #4285f4;
  background-color: #f8fafc;
}

.tab-button--active {
  color: #4285f4;
  border-bottom-color: #4285f4;
}

/* Mobile Dropdown */
.mobile-dropdown {
  position: relative;
  margin-bottom: 1rem;

  @media (min-width: 769px) {
    display: none;
  }
}

.mobile-dropdown-trigger {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 0.75rem 1rem;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.375rem;
  cursor: pointer;
  font-weight: 500;
  color: #334155;
  gap: 0.5rem;
}

.mobile-dropdown-trigger:hover {
  background-color: #f8fafc;
}

.dropdown-arrow {
  transition: transform 0.2s ease;
  font-size: 0.75rem;
  margin-left: auto;
}

.dropdown-arrow--open {
  transform: rotate(180deg);
}

.mobile-menu {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 0.375rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  z-index: 50;
  margin-top: 0.25rem;
}

.mobile-menu-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.75rem 1rem;
  border: none;
  background: none;
  cursor: pointer;
  font-weight: 500;
  color: #64748b;
  text-align: left;
  border-bottom: 1px solid #f1f5f9;
}

.mobile-menu-item:last-child {
  border-bottom: none;
}

.mobile-menu-item:hover {
  background-color: #f8fafc;
  color: #334155;
}

.mobile-menu-item--active {
  color: #4285f4;
  background-color: #eff6ff;
}

/* Tab Content */
.tab-content {
  min-height: 200px;
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .tabs-header {
    margin-bottom: 0;
  }

  .tab-content {
    margin-top: 1rem;
  }
}
</style>
