<template>
  <svg
    xmlns="http://www.w3.org/2000/svg"
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    :fill="filled ? 'currentColor' : 'none'"
    stroke="currentColor"
    stroke-width="2"
    stroke-linecap="round"
    stroke-linejoin="round"
    :class="{ 'star-filled': filled }"
  >
    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon>
  </svg>
</template>

<script setup lang="ts">
interface Props {
  size?: number | string
  filled?: boolean
}

withDefaults(defineProps<Props>(), {
  size: 16,
  filled: false
})
</script>

<style scoped>
.star-filled {
  fill: currentColor;
}
</style>
