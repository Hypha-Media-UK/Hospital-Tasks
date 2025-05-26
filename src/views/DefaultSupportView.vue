<template>
  <div class="default-support-view">
    <h1>Default Support Configuration</h1>
    <p class="description">
      Configure default area and service coverage for each shift type. These settings will be used as templates when creating new shifts.
    </p>
    
    <DefaultSupportTabs />
  </div>
</template>

<script>
import DefaultSupportTabs from '../components/default-support/DefaultSupportTabs.vue';

export default {
  name: 'DefaultSupportView',
  components: {
    DefaultSupportTabs
  }
};
</script>

<style scoped>
.default-support-view {
  padding: 20px;
}

h1 {
  margin-bottom: 10px;
  color: #333;
}

.description {
  margin-bottom: 25px;
  color: #666;
  max-width: 800px;
}
</style>
