<template>
  <div class="form-row" :class="{ 'form-row--time': timeRow }">
    <slot />
    <span v-if="separator" class="form-separator">{{ separator }}</span>
  </div>
</template>

<script setup lang="ts">
interface Props {
  timeRow?: boolean
  separator?: string
}

defineProps<Props>()
</script>

<style scoped>
.form-row {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing);
  margin-bottom: var(--spacing);
}

.form-row--time {
  align-items: center;
}

.form-separator {
  margin-top: -8px;
  color: var(--color-text-light);
  font-weight: 500;
  align-self: center;
}
</style>
