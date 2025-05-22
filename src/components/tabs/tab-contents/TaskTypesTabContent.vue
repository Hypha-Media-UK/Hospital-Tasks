<template>
  <div class="task-types-tab">
    <TaskTypesList />
  </div>
</template>

<script setup>
import TaskTypesList from '../../task-types/TaskTypesList.vue';
</script>

<style lang="scss" scoped>
.task-types-tab {
  padding: 16px 0;
}
</style>
