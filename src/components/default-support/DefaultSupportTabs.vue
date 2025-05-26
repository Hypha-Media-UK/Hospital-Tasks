<template>
  <div class="default-support-tabs">
    <div class="tabs">
      <div 
        :class="['tab', { active: activeTab === 'area' }]" 
        @click="activeTab = 'area'"
      >
        Area Cover
      </div>
      <div 
        :class="['tab', { active: activeTab === 'service' }]" 
        @click="activeTab = 'service'"
      >
        Service Cover
      </div>
    </div>
    
    <div class="tab-content">
      <DefaultAreaCoverSection v-if="activeTab === 'area'" />
      <DefaultServiceCoverSection v-else-if="activeTab === 'service'" />
    </div>
  </div>
</template>

<script>
import DefaultAreaCoverSection from './DefaultAreaCoverSection.vue';
import DefaultServiceCoverSection from './DefaultServiceCoverSection.vue';

export default {
  name: 'DefaultSupportTabs',
  components: {
    DefaultAreaCoverSection,
    DefaultServiceCoverSection
  },
  data() {
    return {
      activeTab: 'area'
    };
  }
};
</script>

<style scoped>
.default-support-tabs {
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
}

.tabs {
  display: flex;
  border-bottom: 1px solid #ddd;
  margin-bottom: 20px;
}

.tab {
  padding: 10px 20px;
  cursor: pointer;
  border-bottom: 3px solid transparent;
  font-weight: 500;
  color: #666;
  transition: all 0.3s ease;
}

.tab:hover {
  color: #333;
}

.tab.active {
  border-bottom: 3px solid #4285F4;
  color: #4285F4;
}

.tab-content {
  padding: 10px 0;
}
</style>
