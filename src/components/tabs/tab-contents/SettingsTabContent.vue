<template>
  <div class="settings-tab">
    <h3>App Settings</h3>
    
    <div class="settings-section">
      <h4>Area Cover</h4>
      <p class="section-description">
        Configure departments that need to be covered by porters during shifts. 
        These settings will be used as defaults when creating new shifts.
      </p>
      
      <AreaCoverTabs />
    </div>
  </div>
</template>

<script setup>
import AreaCoverTabs from '../../area-cover/AreaCoverTabs.vue';
import { useAreaCoverStore } from '../../../stores/areaCoverStore';
import { onMounted } from 'vue';

const areaCoverStore = useAreaCoverStore();

onMounted(() => {
  areaCoverStore.initialize();
});
</script>

<style lang="scss" scoped>
@use '../../../assets/scss/mixins' as mix;

.settings-tab {
  h3 {
    margin-top: 0;
    margin-bottom: 16px;
  }
  
  .settings-section {
    margin-bottom: 32px;
    
    h4 {
      font-size: mix.font-size('lg');
      margin-bottom: 8px;
    }
    
    .section-description {
      color: rgba(0, 0, 0, 0.6);
      margin-bottom: 16px;
    }
  }
}
</style>
