<template>
  <!-- Clean semantic HTML with minimal classes -->
  <section>
    <header>
      <h2>Staff Management</h2>
      <p>Manage hospital staff members and their assignments</p>
    </header>

    <!-- Search and actions -->
    <nav>
      <label>
        Search staff
        <input 
          type="search" 
          v-model="searchQuery"
          placeholder="Search by name..."
        >
      </label>
      
      <button 
        type="button" 
        class="btn btn-primary"
        @click="openCreateModal"
      >
        Add Staff Member
      </button>
    </nav>

    <!-- Loading state -->
    <div v-if="loading.list" class="loading">
      Loading staff...
    </div>

    <!-- Error state -->
    <div v-else-if="error" class="status-danger">
      {{ error }}
      <button type="button" @click="retry">Retry</button>
    </div>

    <!-- Staff list -->
    <main v-else>
      <article 
        v-for="staff in filteredItems" 
        :key="staff.id"
      >
        <header>
          <h3>{{ staff.firstName }} {{ staff.lastName }}</h3>
          <p>{{ staff.role }} • {{ staff.porterType || 'N/A' }}</p>
        </header>
        
        <main>
          <dl>
            <dt>Availability Pattern</dt>
            <dd>{{ staff.availabilityPattern || 'Not specified' }}</dd>
            
            <dt>Contracted Hours</dt>
            <dd>
              {{ staff.contractedHoursStart || 'N/A' }} - 
              {{ staff.contractedHoursEnd || 'N/A' }}
            </dd>
          </dl>
        </main>
        
        <footer>
          <button 
            type="button" 
            class="btn btn-secondary btn-sm"
            @click="editStaff(staff)"
          >
            Edit
          </button>
          
          <button 
            type="button" 
            class="btn btn-danger btn-sm"
            @click="deleteStaff(staff)"
          >
            Delete
          </button>
        </footer>
      </article>
      
      <!-- Empty state -->
      <div v-if="!hasItems" class="text-center text-muted">
        <p>No staff members found</p>
        <button 
          type="button" 
          class="btn btn-primary"
          @click="openCreateModal"
        >
          Add First Staff Member
        </button>
      </div>
    </main>

    <!-- Create/Edit Modal -->
    <dialog ref="modalRef" @close="closeModal">
      <header>
        <h2>{{ isEditing ? 'Edit' : 'Add' }} Staff Member</h2>
        <button type="button" @click="closeModal">&times;</button>
      </header>
      
      <main>
        <form @submit.prevent="saveStaff">
          <label>
            First Name
            <input 
              type="text" 
              v-model="form.firstName"
              required
            >
            <span class="error-message">First name is required</span>
          </label>
          
          <label>
            Last Name
            <input 
              type="text" 
              v-model="form.lastName"
              required
            >
            <span class="error-message">Last name is required</span>
          </label>
          
          <label>
            Role
            <select v-model="form.role" required>
              <option value="">Select role</option>
              <option value="supervisor">Supervisor</option>
              <option value="porter">Porter</option>
            </select>
            <span class="error-message">Role is required</span>
          </label>
          
          <label v-if="form.role === 'porter'">
            Porter Type
            <select v-model="form.porterType">
              <option value="">Select type</option>
              <option value="shift">Shift Porter</option>
              <option value="relief">Relief Porter</option>
            </select>
          </label>
          
          <label>
            Availability Pattern
            <input 
              type="text" 
              v-model="form.availabilityPattern"
              placeholder="e.g., Weekdays - Days"
            >
          </label>
          
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: var(--space-md);">
            <label>
              Start Time
              <input 
                type="time" 
                v-model="form.contractedHoursStart"
              >
            </label>
            
            <label>
              End Time
              <input 
                type="time" 
                v-model="form.contractedHoursEnd"
              >
            </label>
          </div>
        </form>
      </main>
      
      <footer>
        <button 
          type="button" 
          class="btn btn-secondary"
          @click="closeModal"
        >
          Cancel
        </button>
        
        <button 
          type="submit" 
          class="btn btn-primary"
          :disabled="loading.create || loading.update"
          @click="saveStaff"
        >
          {{ isEditing ? 'Update' : 'Create' }}
        </button>
      </footer>
    </dialog>
  </section>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useStaffStore } from '../stores/staff';
import type { Staff } from '@hospital-tasks/shared';

// Store
const staffStore = useStaffStore();

// Reactive refs
const modalRef = ref<HTMLDialogElement>();
const isEditing = ref(false);
const editingStaff = ref<Staff | null>(null);

// Form data
const form = ref({
  firstName: '',
  lastName: '',
  role: '',
  porterType: '',
  availabilityPattern: '',
  contractedHoursStart: '',
  contractedHoursEnd: '',
});

// Computed
const { 
  items, 
  filteredItems, 
  hasItems, 
  loading, 
  error,
  searchQuery 
} = staffStore;

// Methods
function openCreateModal() {
  isEditing.value = false;
  editingStaff.value = null;
  resetForm();
  modalRef.value?.showModal();
}

function editStaff(staff: Staff) {
  isEditing.value = true;
  editingStaff.value = staff;
  
  // Populate form
  form.value = {
    firstName: staff.firstName,
    lastName: staff.lastName,
    role: staff.role,
    porterType: staff.porterType || '',
    availabilityPattern: staff.availabilityPattern || '',
    contractedHoursStart: staff.contractedHoursStart || '',
    contractedHoursEnd: staff.contractedHoursEnd || '',
  };
  
  modalRef.value?.showModal();
}

function closeModal() {
  modalRef.value?.close();
  resetForm();
}

function resetForm() {
  form.value = {
    firstName: '',
    lastName: '',
    role: '',
    porterType: '',
    availabilityPattern: '',
    contractedHoursStart: '',
    contractedHoursEnd: '',
  };
}

async function saveStaff() {
  try {
    const data = {
      ...form.value,
      porterType: form.value.role === 'porter' ? form.value.porterType : undefined,
    };

    if (isEditing.value && editingStaff.value) {
      await staffStore.updateItem(editingStaff.value.id, data);
    } else {
      await staffStore.createItem(data);
    }
    
    closeModal();
  } catch (error) {
    console.error('Error saving staff:', error);
  }
}

async function deleteStaff(staff: Staff) {
  if (confirm(`Are you sure you want to delete ${staff.firstName} ${staff.lastName}?`)) {
    try {
      await staffStore.deleteItem(staff.id);
    } catch (error) {
      console.error('Error deleting staff:', error);
    }
  }
}

function retry() {
  staffStore.fetchItems();
}

// Lifecycle
onMounted(() => {
  staffStore.fetchItems();
});
</script>

<style scoped>
/* Component-specific styles using sibling selectors */
section > header {
  margin-bottom: var(--space-xl);
}

section > nav {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--space-lg);
  margin-bottom: var(--space-xl);
}

section > nav > label {
  flex: 1;
  max-width: 300px;
}

section > main {
  display: grid;
  gap: var(--space-lg);
}

/* Definition list styling */
dl {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: var(--space-xs) var(--space-md);
  margin: 0;
}

dt {
  font-weight: var(--font-weight-medium);
  color: var(--color-gray-700);
  font-size: var(--font-size-sm);
}

dd {
  margin: 0;
  color: var(--color-gray-900);
  font-size: var(--font-size-sm);
}

/* Modal specific styles */
dialog {
  width: min(600px, 90vw);
}

dialog form {
  margin: 0;
}
</style>
