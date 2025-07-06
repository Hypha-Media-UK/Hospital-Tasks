<template>
  <BaseManagementContainer
    :title="config.entityNamePlural"
    :items="items"
    :loading="loading"
    :loading-text="`Loading ${config.entityNamePlural.toLowerCase()}...`"
    :empty-icon="config.emptyIcon"
    :empty-title="config.emptyTitle"
    :empty-description="config.emptyDescription"
    :add-button-text="`Add ${config.entityName}`"
    @add-item="openAddModal"
  >
    <template #items="{ items }">
      <component
        :is="cardComponent"
        v-for="item in items"
        :key="item.id"
        v-bind="getCardProps(item)"
        @edit="editEntity"
        @delete="deleteEntity"
        @deleted="handleEntityDeleted"
        @assignment-click="openAssignmentModal"
      />
    </template>

    <template #modals>
      <!-- Add Entity Modal -->
      <BaseModal
        v-if="showAddModal"
        :title="`Add ${config.entityName}`"
        size="md"
        show-footer
        @close="closeAddModal"
      >
        <BaseFormField
          :id="`${entityKey}Name`"
          :label="`${config.entityName} Name`"
          v-model="entityForm.name"
          :placeholder="`Enter ${config.entityName.toLowerCase()} name`"
          required
          @keyup.enter="addEntity"
          @keyup.esc="closeAddModal"
          ref="entityNameInput"
        />

        <template #footer>
          <BaseButton @click="closeAddModal" variant="secondary">
            Cancel
          </BaseButton>
          <BaseButton
            @click="addEntity"
            variant="primary"
            :disabled="!entityForm.name.trim() || loading"
          >
            {{ loading ? 'Adding...' : `Add ${config.entityName}` }}
          </BaseButton>
        </template>
      </BaseModal>

      <!-- Edit Entity Modal -->
      <BaseModal
        v-if="showEditModal"
        :title="`Edit ${config.entityName}`"
        size="md"
        show-footer
        @close="closeEditModal"
      >
        <BaseFormField
          :id="`edit${entityKey}Name`"
          :label="`${config.entityName} Name`"
          v-model="editEntityForm.name"
          :placeholder="`Enter ${config.entityName.toLowerCase()} name`"
          required
          @keyup.enter="updateEntity"
          @keyup.esc="closeEditModal"
        />

        <template #footer>
          <BaseButton @click="closeEditModal" variant="secondary">
            Cancel
          </BaseButton>
          <BaseButton
            @click="updateEntity"
            variant="primary"
            :disabled="!editEntityForm.name.trim() || loading"
          >
            {{ loading ? 'Updating...' : `Update ${config.entityName}` }}
          </BaseButton>
        </template>
      </BaseModal>

      <!-- Assignment Modal (if supported) -->
      <component
        v-if="hasAssignments && assignmentModal.show"
        :is="assignmentModalComponent"
        :task-type-id="assignmentModal.taskTypeId"
        :task-item-id="assignmentModal.taskItemId"
        :title="assignmentModal.title"
        @close="closeAssignmentModal"
        @saved="handleAssignmentsSaved"
      />
    </template>
  </BaseManagementContainer>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, nextTick } from 'vue'
import BaseButton from './BaseButton.vue'
import BaseModal from './BaseModal.vue'
import BaseManagementContainer from './BaseManagementContainer.vue'
import BaseFormField from './BaseFormField.vue'

interface EntityConfig {
  entityName: string
  entityNamePlural: string
  emptyIcon: any
  emptyTitle: string
  emptyDescription: string
}

interface Props {
  config: EntityConfig
  store: any
  cardComponent: any
  hasAssignments?: boolean
  assignmentModalComponent?: any
}

const props = defineProps<Props>()

// State
const showAddModal = ref(false)
const showEditModal = ref(false)
const entityNameInput = ref<HTMLInputElement>()

const entityForm = ref({
  name: ''
})

const editEntityForm = ref({
  id: '',
  name: ''
})

const assignmentModal = ref({
  show: false,
  taskTypeId: undefined as string | undefined,
  taskItemId: undefined as string | undefined,
  title: ''
})

// Computed
const entityKey = computed(() =>
  props.config.entityName.replace(/\s+/g, '')
)

const items = computed(() => {
  // Generic way to get items from store
  const storeItems = props.store.buildings ||
                    props.store.taskTypesWithItems ||
                    props.store.items ||
                    []
  return storeItems
})

const loading = computed(() => {
  return props.store.isEntitiesLoading || false
})

// Methods
const getCardProps = (item: any) => {
  // Return appropriate props based on entity type
  if (props.store.buildings) {
    return { building: item }
  } else if (props.store.taskTypesWithItems) {
    return { 'task-type': item }
  }
  return { item }
}

const addEntity = async () => {
  if (!entityForm.value.name.trim()) return

  let success = false

  if (props.store.addBuilding) {
    success = await props.store.addBuilding({
      name: entityForm.value.name.trim(),
      sort_order: items.value.length
    })
  } else if (props.store.addTaskType) {
    success = await props.store.addTaskType({
      name: entityForm.value.name.trim()
    })
  }

  if (success) {
    closeAddModal()
  }
}

const editEntity = (entity: any) => {
  editEntityForm.value = {
    id: entity.id,
    name: entity.name
  }
  showEditModal.value = true
}

const updateEntity = async () => {
  if (!editEntityForm.value.name.trim()) return

  let success = false

  if (props.store.updateBuilding) {
    success = await props.store.updateBuilding(editEntityForm.value.id, {
      name: editEntityForm.value.name.trim()
    })
  } else if (props.store.updateTaskType) {
    success = await props.store.updateTaskType(editEntityForm.value.id, {
      name: editEntityForm.value.name.trim()
    })
  }

  if (success) {
    closeEditModal()
  }
}

const deleteEntity = async (entity: any) => {
  const entityName = entity.name
  const confirmMessage = props.store.buildings
    ? `Are you sure you want to delete "${entityName}" and all its departments?`
    : `Are you sure you want to delete "${entityName}"?`

  if (confirm(confirmMessage)) {
    if (props.store.deleteBuilding) {
      await props.store.deleteBuilding(entity.id)
    } else if (props.store.deleteTaskType) {
      await props.store.deleteTaskType(entity.id)
    }
  }
}

const handleEntityDeleted = (entityId: string) => {
  // Entity is already removed from store, no additional action needed
}

const closeAddModal = () => {
  entityForm.value.name = ''
  showAddModal.value = false
}

const closeEditModal = () => {
  editEntityForm.value = { id: '', name: '' }
  showEditModal.value = false
}

const openAddModal = async () => {
  showAddModal.value = true
  await nextTick()
  entityNameInput.value?.focus()
}

// Assignment modal methods (for task types)
const openAssignmentModal = (title: string, taskTypeId?: string, taskItemId?: string) => {
  if (props.hasAssignments) {
    assignmentModal.value = {
      show: true,
      taskTypeId,
      taskItemId,
      title
    }
  }
}

const closeAssignmentModal = () => {
  assignmentModal.value = {
    show: false,
    taskTypeId: undefined,
    taskItemId: undefined,
    title: ''
  }
}

const handleAssignmentsSaved = () => {
  closeAssignmentModal()
}

// Expose methods for child components
defineExpose({
  openAssignmentModal
})

// Initialize
onMounted(async () => {
  await props.store.initialize()
})
</script>

<style scoped>
/* No component-specific styles needed - all handled by base components */
</style>
