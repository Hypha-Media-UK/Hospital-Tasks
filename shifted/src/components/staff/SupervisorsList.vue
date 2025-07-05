<template>
  <div class="supervisors-list">
    <div class="list-header">
      <div class="header-info">
        <h4>Supervisors</h4>
        <p v-if="supervisors.length > 0">
          {{ supervisors.length }} supervisor{{ supervisors.length !== 1 ? 's' : '' }} registered
        </p>
        <p v-else class="no-supervisors">
          No supervisors registered
        </p>
      </div>
      <BaseButton
        variant="primary"
        size="sm"
        @click="showAddSupervisor = true"
      >
        <PlusIcon class="w-4 h-4" />
        Add Supervisor
      </BaseButton>
    </div>

    <div v-if="loading.supervisors" class="loading-state">
      <div class="loading-spinner"></div>
      <p>Loading supervisors...</p>
    </div>

    <div v-else-if="supervisors.length === 0" class="empty-state">
      <div class="empty-icon">
        <StarIcon class="w-12 h-12" />
      </div>
      <h3>No Supervisors</h3>
      <p>Add your first supervisor to get started with staff management.</p>
      <BaseButton
        variant="primary"
        @click="showAddSupervisor = true"
      >
        <PlusIcon class="w-4 h-4" />
        Add First Supervisor
      </BaseButton>
    </div>

    <div v-else class="supervisors-grid">
      <div
        v-for="supervisor in supervisors"
        :key="supervisor.id"
        class="supervisor-card"
      >
        <div class="card-header">
          <div class="supervisor-info">
            <h5 class="supervisor-name">{{ supervisor.first_name }} {{ supervisor.last_name }}</h5>
            <p class="supervisor-role">Supervisor</p>
          </div>
          <div class="card-actions">
            <button class="action-btn edit-btn" title="Edit Supervisor">
              <EditIcon class="w-4 h-4" />
            </button>
            <button class="action-btn delete-btn" title="Delete Supervisor">
              <TrashIcon class="w-4 h-4" />
            </button>
          </div>
        </div>
        <div class="card-body">
          <div v-if="supervisor.department" class="department-info">
            <span class="label">Department:</span>
            <span class="value">{{ supervisor.department.name }}</span>
          </div>
          <div v-if="supervisor.email" class="contact-info">
            <span class="label">Email:</span>
            <span class="value">{{ supervisor.email }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Add Supervisor Modal Placeholder -->
    <div v-if="showAddSupervisor" class="modal-overlay" @click="showAddSupervisor = false">
      <div class="modal-content" @click.stop>
        <div class="modal-header">
          <h3>Add Supervisor</h3>
          <button class="close-btn" @click="showAddSupervisor = false">×</button>
        </div>
        <div class="modal-body">
          <p>Add Supervisor Modal - Coming Soon</p>
        </div>
        <div class="modal-footer">
          <BaseButton variant="secondary" @click="showAddSupervisor = false">Cancel</BaseButton>
          <BaseButton variant="primary" @click="showAddSupervisor = false">Save</BaseButton>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useStaffStore } from '../../stores/staffStore'
import BaseButton from '../ui/BaseButton.vue'
import PlusIcon from '../icons/PlusIcon.vue'
import StarIcon from '../icons/StarIcon.vue'
import EditIcon from '../icons/EditIcon.vue'
import TrashIcon from '../icons/TrashIcon.vue'

const staffStore = useStaffStore()
const showAddSupervisor = ref(false)

const { supervisors, loading } = staffStore
</script>

<style scoped>
.supervisors-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
}

.list-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: var(--spacing);
  flex-wrap: wrap;
}

.header-info h4 {
  font-size: 1.125rem;
  font-weight: 600;
  margin-bottom: var(--spacing-xs);
  color: var(--color-text);
}

.header-info p {
  color: var(--color-text-light);
  font-size: 0.875rem;
  margin: 0;
}

.loading-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-2xl);
  text-align: center;
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

.empty-icon {
  margin-bottom: var(--spacing-lg);
  opacity: 0.6;
  color: var(--color-text-muted);
}

.empty-state h3 {
  margin-bottom: var(--spacing-sm);
  color: var(--color-text);
}

.empty-state p {
  margin-bottom: var(--spacing-lg);
  max-width: 400px;
}

.supervisors-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: var(--spacing);
}

@container (min-width: 640px) {
  .supervisors-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@container (min-width: 1024px) {
  .supervisors-grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

.supervisor-card {
  background: var(--color-background);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  overflow: hidden;
  transition: all 0.2s ease;
}

.supervisor-card:hover {
  border-color: var(--color-border-hover);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: var(--spacing);
  gap: var(--spacing-sm);
}

.supervisor-info {
  flex: 1;
  min-width: 0;
}

.supervisor-name {
  font-size: 1rem;
  font-weight: 600;
  margin: 0 0 var(--spacing-xs) 0;
  color: var(--color-text);
  line-height: 1.4;
}

.supervisor-role {
  font-size: 0.875rem;
  color: var(--color-text-light);
  margin: 0;
  line-height: 1.4;
}

.card-actions {
  display: flex;
  gap: var(--spacing-xs);
  flex-shrink: 0;
}

.action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border: none;
  border-radius: var(--radius-sm);
  background: var(--color-background-alt);
  color: var(--color-text-light);
  cursor: pointer;
  transition: all 0.2s ease;
}

.action-btn:hover {
  background: var(--color-border);
  color: var(--color-text);
}

.edit-btn:hover {
  background: var(--color-primary-light);
  color: var(--color-primary);
}

.delete-btn:hover {
  background: var(--color-danger-light);
  color: var(--color-danger);
}

.card-body {
  padding: 0 var(--spacing) var(--spacing) var(--spacing);
}

.department-info,
.contact-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--spacing-xs);
}

.label {
  font-size: 0.875rem;
  color: var(--color-text-light);
  font-weight: 500;
}

.value {
  font-size: 0.875rem;
  color: var(--color-text);
  font-weight: 600;
}

/* Modal styles */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: var(--color-background);
  border-radius: var(--radius-lg);
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
  max-width: 500px;
  width: 90%;
  max-height: 90vh;
  overflow: hidden;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-lg);
  border-bottom: 1px solid var(--color-border);
}

.modal-header h3 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--color-text-light);
  padding: 0;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--radius);
}

.close-btn:hover {
  background: var(--color-background-alt);
  color: var(--color-text);
}

.modal-body {
  padding: var(--spacing-lg);
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: var(--spacing);
  padding: var(--spacing-lg);
  border-top: 1px solid var(--color-border);
}
</style>
