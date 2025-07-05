<template>
  <div class="active-shifts-tab">
    <div class="tab-header">
      <h2 class="text-lg font-semibold">Active Shifts</h2>
      <button
        v-if="selectedShifts.length > 0"
        @click="exportSelectedShifts"
        class="btn btn-success btn-sm"
      >
        Export {{ selectedShifts.length }} Selected
      </button>
    </div>

    <div v-if="loading" class="loading-state">
      <div class="loading-spinner"></div>
      <p>Loading shifts...</p>
    </div>

    <div v-else-if="shifts.length === 0" class="empty-state">
      <div class="empty-icon">
        <svg width="64" height="64" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 8V12L15 15" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
          <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"/>
        </svg>
      </div>
      <h3>No Active Shifts</h3>
      <p>Create a new shift to get started.</p>
    </div>

    <div v-else class="shifts-content">
      <div class="selection-controls" v-if="shifts.length > 0">
        <label class="checkbox-label">
          <input
            type="checkbox"
            :checked="isAllSelected"
            @change="toggleSelectAll"
          />
          <span class="checkbox-text">Select All ({{ shifts.length }})</span>
        </label>
      </div>

      <div class="shifts-grid">
        <ShiftCard
          v-for="shift in shifts"
          :key="shift.id"
          :shift="shift"
          :selected="isShiftSelected(shift)"
          @select="toggleShiftSelection(shift)"
          @view="viewShift(shift.id)"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useShiftsStore } from '../../stores/shiftsStore.ts'
import ShiftCard from '../shift/ShiftCard.vue'

const router = useRouter()
const shiftsStore = useShiftsStore()

const selectedShifts = ref([])
const loading = ref(true)

const shifts = computed(() => shiftsStore.activeShifts || [])

const isAllSelected = computed(() => {
  return shifts.value.length > 0 && selectedShifts.value.length === shifts.value.length
})

const isShiftSelected = (shift) => {
  return selectedShifts.value.some(s => s.id === shift.id)
}

const toggleSelectAll = () => {
  if (isAllSelected.value) {
    selectedShifts.value = []
  } else {
    selectedShifts.value = [...shifts.value]
  }
}

const toggleShiftSelection = (shift) => {
  const index = selectedShifts.value.findIndex(s => s.id === shift.id)
  if (index === -1) {
    selectedShifts.value.push(shift)
  } else {
    selectedShifts.value.splice(index, 1)
  }
}

const viewShift = (shiftId) => {
  router.push(`/shift-management/${shiftId}`)
}

const exportSelectedShifts = () => {
  // TODO: Implement export functionality
}

onMounted(async () => {
  try {
    await shiftsStore.fetchActiveShifts()
  } catch (error) {
    console.error('Error loading shifts:', error)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.active-shifts-tab {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.tab-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: var(--spacing);
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-2xl);
  gap: var(--spacing);
  color: var(--color-text-light);
}

.loading-spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--color-border);
  border-top: 3px solid var(--color-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-2xl);
  text-align: center;
  color: var(--color-text-light);
}

.empty-icon {
  margin-bottom: var(--spacing-lg);
  opacity: 0.6;
}

.empty-state h3 {
  margin-bottom: var(--spacing-sm);
  color: var(--color-text);
}

.shifts-content {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.selection-controls {
  display: flex;
  justify-content: flex-end;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  cursor: pointer;
  padding: var(--spacing-sm) var(--spacing);
  border-radius: var(--radius);
  background: var(--color-background-alt);
  font-size: 0.875rem;
  font-weight: 500;
}

.checkbox-label:hover {
  background: var(--color-border-light);
}

.checkbox-text {
  user-select: none;
}

.shifts-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--spacing);
}

@container (min-width: 640px) {
  .shifts-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@container (min-width: 1024px) {
  .shifts-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}
</style>
