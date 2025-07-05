<template>
  <BaseModal
    title="Edit Support Service"
    size="md"
    show-footer
    @close="$emit('close')"
  >
    <p>Edit Service Modal - Coming Soon</p>
    <p>Service: {{ service?.name || 'Unknown' }}</p>

    <template #footer>
      <BaseButton variant="secondary" @click="$emit('close')">Cancel</BaseButton>
      <BaseButton variant="primary" @click="$emit('saved')">Save Changes</BaseButton>
    </template>
  </BaseModal>
</template>

<script setup lang="ts">
import BaseButton from '../ui/BaseButton.vue'
import BaseModal from '../ui/BaseModal.vue'
import type { SupportService } from '../../types/supportServices'

interface Props {
  service: SupportService | null
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
