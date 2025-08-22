<template>
  <section>
    <header>
      <h1>Hospital Tasks Dashboard</h1>
      <p>Modern, DRY, and performant hospital task management system</p>
    </header>
    
    <main class="dashboard">
      <article>
        <header>
          <h3>Staff Management</h3>
          <p>Manage hospital staff and assignments</p>
        </header>
        <main>
          <p>Total staff members: <strong>{{ staffCount }}</strong></p>
        </main>
        <footer>
          <router-link to="/staff" class="btn btn-primary">
            Manage Staff
          </router-link>
        </footer>
      </article>
      
      <article>
        <header>
          <h3>Buildings & Departments</h3>
          <p>Organize hospital locations</p>
        </header>
        <main>
          <p>Buildings: <strong>{{ buildingCount }}</strong></p>
          <p>Departments: <strong>{{ departmentCount }}</strong></p>
        </main>
        <footer>
          <router-link to="/buildings" class="btn btn-primary">
            Manage Buildings
          </router-link>
        </footer>
      </article>
      
      <article>
        <header>
          <h3>Task Management</h3>
          <p>Configure task types and items</p>
        </header>
        <main>
          <p>Task types: <strong>{{ taskTypeCount }}</strong></p>
        </main>
        <footer>
          <router-link to="/task-types" class="btn btn-primary">
            Manage Tasks
          </router-link>
        </footer>
      </article>
      
      <article>
        <header>
          <h3>Shift Planning</h3>
          <p>Plan and manage work shifts</p>
        </header>
        <main>
          <p>Active shifts: <strong>{{ shiftCount }}</strong></p>
        </main>
        <footer>
          <router-link to="/shifts" class="btn btn-primary">
            Manage Shifts
          </router-link>
        </footer>
      </article>
    </main>
  </section>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useStaffStore } from '../stores/staff';

// Stores
const staffStore = useStaffStore();

// Reactive data
const staffCount = ref(0);
const buildingCount = ref(0);
const departmentCount = ref(0);
const taskTypeCount = ref(0);
const shiftCount = ref(0);

// Load dashboard data
onMounted(async () => {
  try {
    // Load staff count
    await staffStore.fetchItems({ limit: 1 });
    staffCount.value = staffStore.pagination.total;
    
    // TODO: Load other counts when stores are ready
    buildingCount.value = 0;
    departmentCount.value = 0;
    taskTypeCount.value = 0;
    shiftCount.value = 0;
  } catch (error) {
    console.error('Error loading dashboard data:', error);
  }
});
</script>

<style scoped>
section > header {
  text-align: center;
  margin-bottom: var(--space-2xl);
}

section > header h1 {
  margin-bottom: var(--space-sm);
  color: var(--color-primary);
}

section > header p {
  color: var(--color-gray-600);
  font-size: var(--font-size-lg);
}

/* Dashboard grid responsive behavior */
.dashboard {
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
}

@container (min-width: 768px) {
  .dashboard {
    grid-template-columns: repeat(2, 1fr);
  }
}

@container (min-width: 1200px) {
  .dashboard {
    grid-template-columns: repeat(4, 1fr);
  }
}
</style>
