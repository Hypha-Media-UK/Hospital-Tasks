<template>
  <BaseEntityManagement
    :config="buildingConfig"
    :store="locationsStore"
    :card-component="BuildingCard"
  />
</template>

<script setup lang="ts">
import { useLocationsStore } from '../../stores/locationsStore'
import BaseEntityManagement from '../ui/BaseEntityManagement.vue'
import BuildingCard from './BuildingCard.vue'
import MapPinIcon from '../icons/MapPinIcon.vue'

const locationsStore = useLocationsStore()

const buildingConfig = {
  entityName: 'Building',
  entityNamePlural: 'Locations',
  emptyIcon: MapPinIcon,
  emptyTitle: 'No Buildings Added',
  emptyDescription: 'Add your first building to start organizing locations and departments.'
}
</script>

<style scoped>
/* No component-specific styles needed - all handled by base components */
</style>
