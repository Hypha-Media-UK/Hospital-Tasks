<template>
  <BaseModal
    title="Add Support Service"
    size="md"
    show-footer
    @close="$emit('close')"
  >
    <p>Add Service Modal - Coming Soon</p>
    <p>Shift Type: {{ shiftType }}</p>

    <template #footer>
      <BaseButton variant="secondary" @click="$emit('close')">Cancel</BaseButton>
      <BaseButton variant="primary" @click="$emit('saved')">Save</BaseButton>
    </template>
  </BaseModal>
</template>

<script setup lang="ts">
import BaseButton from '../ui/BaseButton.vue'
import BaseModal from '../ui/BaseModal.vue'
import type { ShiftType } from '../../types/supportServices'

interface Props {
  shiftType: ShiftType
}

interface Emits {
  (e: 'close'): void
  (e: 'saved'): void
}

defineProps<Props>()
defineEmits<Emits>()
</script>

<style scoped>
/* No modal styles needed - handled by BaseModal */
</style>
