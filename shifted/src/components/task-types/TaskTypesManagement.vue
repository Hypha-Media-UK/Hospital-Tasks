<template>
  <BaseEntityManagement
    :config="taskTypeConfig"
    :store="taskTypesStore"
    :card-component="TaskTypeCard"
    :has-assignments="true"
    :assignment-modal-component="AssignmentModal"
  />
</template>

<script setup lang="ts">
import { useTaskTypesStore } from '../../stores/taskTypesStore'
import BaseEntityManagement from '../ui/BaseEntityManagement.vue'
import TaskTypeCard from './TaskTypeCard.vue'
import AssignmentModal from './AssignmentModal.vue'
import TaskIcon from '../icons/TaskIcon.vue'

const taskTypesStore = useTaskTypesStore()

const taskTypeConfig = {
  entityName: 'Task Type',
  entityNamePlural: 'Task Types',
  emptyIcon: TaskIcon,
  emptyTitle: 'No Task Types',
  emptyDescription: 'Create your first task type to get started with task management.'
}
</script>

<style scoped>
/* No component-specific styles needed - all handled by base components */
</style>
