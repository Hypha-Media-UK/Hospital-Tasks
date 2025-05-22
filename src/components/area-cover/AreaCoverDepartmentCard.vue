<template>
  <div 
    class="department-card" 
    :style="{ borderLeftColor: assignment.color || '#4285F4' }"
    @click="showEditModal = true"
    :class="{ 'has-coverage-gap': hasCoverageGap }"
  >
    <div class="department-card__content">
      <div class="department-card__name">
        {{ assignment.department.name }}
      </div>
      <div class="department-card__building">
        {{ assignment.department.building?.name || 'Unknown Building' }}
      </div>
      
      <div v-if="porterAssignments.length > 0" class="department-card__porters">
        <span class="porter-count" :class="{ 'has-coverage-gap': hasCoverageGap }">
          {{ porterAssignments.length }} {{ porterAssignments.length === 1 ? 'Porter' : 'Porters' }}
          <span v-if="hasCoverageGap" class="gap-indicator">Gap</span>
        </span>
      </div>
    </div>
    
    <!-- Edit Department Modal -->
    <EditDepartmentModal 
      v-if="showEditModal" 
      :assignment="assignment"
      @close="showEditModal = false"
      @update="handleUpdate"
      @remove="handleRemove"
    />
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { useAreaCoverStore } from '../../stores/areaCoverStore';
import EditDepartmentModal from './EditDepartmentModal.vue';

const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['update', 'remove']);

const areaCoverStore = useAreaCoverStore();
const showEditModal = ref(false);

// Get porter assignments for this area
const porterAssignments = computed(() => {
  return areaCoverStore.getPorterAssignmentsByAreaId(props.assignment.id);
});

// Check if there's a coverage gap
const hasCoverageGap = computed(() => {
  return areaCoverStore.hasCoverageGap(props.assignment.id);
});

// Forward events from modal to parent
const handleUpdate = (assignmentId, updates) => {
  emit('update', assignmentId, updates);
};

const handleRemove = (assignmentId) => {
  emit('remove', assignmentId);
  showEditModal.value = false;
};
</script>

<style lang="scss" scoped>
@use '../../assets/scss/mixins' as mix;

.department-card {
  background-color: white;
  border-radius: mix.radius('md');
  border-left: 4px solid #4285F4; // Default color, will be overridden by inline style
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  overflow: hidden;
  transition: box-shadow 0.2s ease;
  cursor: pointer;
  position: relative;
  
  &:hover {
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
    background-color: rgba(0, 0, 0, 0.01);
  }
  
  &.has-coverage-gap {
    &::after {
      content: '';
      position: absolute;
      top: 0;
      right: 0;
      width: 0;
      height: 0;
      border-style: solid;
      border-width: 0 12px 12px 0;
      border-color: transparent #EA4335 transparent transparent;
    }
  }
  
  &__content {
    padding: 12px 16px;
  }
  
  &__name {
    font-weight: 600;
    font-size: mix.font-size('md');
    margin-bottom: 4px;
  }
  
  &__building {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
    margin-bottom: 8px;
  }
  
  &__porters {
    margin-top: 8px;
    
    .porter-count {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background-color: rgba(66, 133, 244, 0.1);
      color: mix.color('primary');
      border-radius: 100px;
      padding: 2px 8px;
      font-size: mix.font-size('xs');
      font-weight: 500;
      
      &.has-coverage-gap {
        background-color: rgba(234, 67, 53, 0.1);
        color: #EA4335;
      }
      
      .gap-indicator {
        background-color: #EA4335;
        color: white;
        font-size: mix.font-size('2xs');
        padding: 1px 4px;
        border-radius: 100px;
      }
    }
  }
}
</style>
