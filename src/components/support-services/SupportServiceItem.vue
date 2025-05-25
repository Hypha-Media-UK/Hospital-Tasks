<template>
  <div class="service-item" :style="{ borderLeftColor: assignment.color || '#4285F4' }">
    <div class="service-details">
      <h3 class="service-name">{{ assignment.service.name }}</h3>
      
      <div class="service-info">
        <div class="service-time">
          {{ formatTimeRange(assignment.start_time, assignment.end_time) }}
        </div>
        
        <div v-if="assignment.service.description" class="service-description">
          {{ assignment.service.description }}
        </div>
      </div>
      
      <div class="porter-assignments">
        <h4 v-if="assignment.porter_assignments.length > 0">
          Assigned Porters
        </h4>
        
        <div class="porters-list">
          <div 
            v-for="porterAssignment in assignment.porter_assignments" 
            :key="porterAssignment.id"
            class="porter-item"
          >
            <div class="porter-name">
              {{ porterAssignment.porter.first_name }} {{ porterAssignment.porter.last_name }}
            </div>
            <div class="porter-time">
              {{ formatTimeRange(porterAssignment.start_time, porterAssignment.end_time) }}
            </div>
          </div>
        </div>
        
        <div v-if="assignment.porter_assignments.length === 0" class="no-porters">
          No porters assigned
        </div>
      </div>
    </div>
    
    <div class="service-actions">
      <button @click="$emit('edit', assignment)" class="btn-edit" title="Edit service">
        <span class="icon">✏️</span>
      </button>
      <button @click="$emit('remove', assignment.id)" class="btn-remove" title="Remove service">
        <span class="icon">🗑️</span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { defineProps, defineEmits } from 'vue';

// Props
const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

// Emits
defineEmits(['edit', 'remove']);

// Helper function to format time range
function formatTimeRange(startTime, endTime) {
  if (!startTime || !endTime) return '';
  
  // Format times (assumes HH:MM format)
  const formatTime = (time) => {
    if (typeof time === 'string') {
      // Handle 24-hour time format string (e.g., "14:30:00")
      return time.substring(0, 5); // Get HH:MM part
    }
    return '';
  };
  
  return `${formatTime(startTime)} - ${formatTime(endTime)}`;
}
</script>

<style lang="scss" scoped>
@use "sass:color";
@use '../../assets/scss/mixins' as mix;

.service-item {
  background-color: white;
  border-radius: mix.radius('md');
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  padding: 16px;
  display: flex;
  border-left: 4px solid #4285F4; // Default color, will be overridden by inline style
  
  .service-details {
    flex: 1;
  }
  
  .service-name {
    margin-top: 0;
    margin-bottom: 8px;
    font-size: mix.font-size('md');
    font-weight: 600;
  }
  
  .service-info {
    margin-bottom: 12px;
    
    .service-time {
      display: inline-block;
      padding: 4px 8px;
      background-color: rgba(0, 0, 0, 0.05);
      border-radius: mix.radius('sm');
      font-size: mix.font-size('sm');
      margin-bottom: 6px;
    }
    
    .service-description {
      font-size: mix.font-size('sm');
      color: rgba(0, 0, 0, 0.7);
    }
  }
  
  .porter-assignments {
    h4 {
      font-size: mix.font-size('sm');
      font-weight: 600;
      margin: 12px 0 8px;
      padding-bottom: 4px;
      border-bottom: 1px solid rgba(0, 0, 0, 0.05);
    }
    
    .porters-list {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    
    .porter-item {
      background-color: #f9f9f9;
      padding: 8px;
      border-radius: mix.radius('sm');
      font-size: mix.font-size('sm');
      
      .porter-name {
        font-weight: 500;
      }
      
      .porter-time {
        font-size: mix.font-size('xs');
        color: rgba(0, 0, 0, 0.6);
      }
    }
    
    .no-porters {
      font-size: mix.font-size('sm');
      font-style: italic;
      color: rgba(0, 0, 0, 0.5);
      padding: 8px 0;
    }
  }
  
  .service-actions {
    display: flex;
    flex-direction: column;
    gap: 8px;
    
    button {
      background: none;
      border: none;
      cursor: pointer;
      padding: 6px;
      border-radius: mix.radius('sm');
      
      .icon {
        font-size: 16px;
      }
      
      &.btn-edit:hover {
        background-color: rgba(0, 0, 0, 0.05);
      }
      
      &.btn-remove:hover {
        background-color: rgba(234, 67, 53, 0.1);
      }
    }
  }
}
</style>
