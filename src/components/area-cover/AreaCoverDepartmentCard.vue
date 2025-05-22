<template>
  <div class="department-card" :style="{ borderLeftColor: assignment.color || '#4285F4' }">
    <div class="department-card__header">
      <div class="department-card__name">
        {{ assignment.department.name }}
      </div>
      <div class="department-card__building">
        {{ assignment.department.building?.name || 'Unknown Building' }}
      </div>
      <button 
        class="department-card__remove" 
        title="Remove department"
        @click="$emit('remove', assignment.id)"
      >
        &times;
      </button>
    </div>
    
    <div class="department-card__content">
      <!-- Time settings -->
      <div class="time-settings">
        <div class="time-group">
          <label for="startTime">Start Time</label>
          <input 
            type="time" 
            id="startTime" 
            v-model="startTime" 
            @change="updateTimes"
          />
        </div>
        
        <div class="time-group">
          <label for="endTime">End Time</label>
          <input 
            type="time" 
            id="endTime" 
            v-model="endTime" 
            @change="updateTimes"
          />
        </div>
      </div>
      
      <!-- Color picker -->
      <div class="color-settings">
        <label for="color">Color</label>
        <input 
          type="color" 
          id="color" 
          v-model="color" 
          @change="updateColor"
        />
      </div>
      
      <!-- Porter assignment -->
      <div class="porter-assignment">
        <label>Assigned Porter</label>
        
        <div v-if="assignment.porter" class="porter-pill">
          <span class="porter-name">
            {{ assignment.porter.first_name }} {{ assignment.porter.last_name }}
          </span>
          <button 
            class="porter-remove" 
            title="Remove porter assignment"
            @click="removePorter"
          >
            &times;
          </button>
        </div>
        
        <div v-else class="porter-selector">
          <select 
            v-model="selectedPorterId" 
            @change="assignPorter"
          >
            <option value="">-- Select Porter --</option>
            <option 
              v-for="porter in porters" 
              :key="porter.id" 
              :value="porter.id"
            >
              {{ porter.first_name }} {{ porter.last_name }}
            </option>
          </select>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAreaCoverStore } from '../../stores/areaCoverStore';
import { useStaffStore } from '../../stores/staffStore';

const props = defineProps({
  assignment: {
    type: Object,
    required: true
  }
});

const emit = defineEmits(['update', 'remove']);

const areaCoverStore = useAreaCoverStore();
const staffStore = useStaffStore();

// Local state
const startTime = ref('');
const endTime = ref('');
const color = ref('#4285F4');
const selectedPorterId = ref('');

// Computed
const porters = computed(() => {
  return staffStore.sortedPorters;
});

// Methods
const updateTimes = () => {
  emit('update', props.assignment.id, {
    start_time: startTime.value + ':00',
    end_time: endTime.value + ':00'
  });
};

const updateColor = () => {
  emit('update', props.assignment.id, { color: color.value });
};

const assignPorter = () => {
  if (selectedPorterId.value) {
    areaCoverStore.assignPorter(props.assignment.id, selectedPorterId.value);
  }
};

const removePorter = () => {
  areaCoverStore.removePorter(props.assignment.id);
};

// Initialize component state from props
const initializeState = () => {
  // Parse times from HH:MM:SS format to HH:MM for the time input
  if (props.assignment.start_time) {
    startTime.value = props.assignment.start_time.slice(0, 5);
  }
  
  if (props.assignment.end_time) {
    endTime.value = props.assignment.end_time.slice(0, 5);
  }
  
  // Set color
  color.value = props.assignment.color || '#4285F4';
};

// Fetch porters if not already loaded
onMounted(async () => {
  initializeState();
  
  if (staffStore.porters.length === 0) {
    await staffStore.fetchPorters();
  }
});
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
  
  &:hover {
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
  }
  
  &__header {
    padding: 12px 16px;
    position: relative;
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
  }
  
  &__name {
    font-weight: 600;
    font-size: mix.font-size('md');
    margin-bottom: 4px;
  }
  
  &__building {
    font-size: mix.font-size('sm');
    color: rgba(0, 0, 0, 0.6);
  }
  
  &__remove {
    position: absolute;
    top: 8px;
    right: 8px;
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background-color: rgba(0, 0, 0, 0.05);
    border: none;
    font-size: 16px;
    line-height: 1;
    cursor: pointer;
    transition: background-color 0.2s ease;
    
    &:hover {
      background-color: rgba(0, 0, 0, 0.1);
    }
  }
  
  &__content {
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
}

// Time settings
.time-settings {
  display: flex;
  gap: 16px;
  
  .time-group {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
    
    label {
      font-size: mix.font-size('sm');
      font-weight: 500;
      color: rgba(0, 0, 0, 0.7);
    }
    
    input[type="time"] {
      padding: 6px 8px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('sm');
      font-size: mix.font-size('md');
      
      &:focus {
        outline: none;
        border-color: mix.color('primary');
        box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
      }
    }
  }
}

// Color settings
.color-settings {
  display: flex;
  flex-direction: column;
  gap: 4px;
  
  label {
    font-size: mix.font-size('sm');
    font-weight: 500;
    color: rgba(0, 0, 0, 0.7);
  }
  
  input[type="color"] {
    height: 32px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-radius: mix.radius('sm');
    
    &:focus {
      outline: none;
      border-color: mix.color('primary');
      box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
  }
}

// Porter assignment
.porter-assignment {
  display: flex;
  flex-direction: column;
  gap: 8px;
  
  label {
    font-size: mix.font-size('sm');
    font-weight: 500;
    color: rgba(0, 0, 0, 0.7);
  }
  
  .porter-selector {
    select {
      width: 100%;
      padding: 6px 8px;
      border: 1px solid rgba(0, 0, 0, 0.2);
      border-radius: mix.radius('sm');
      font-size: mix.font-size('md');
      
      &:focus {
        outline: none;
        border-color: mix.color('primary');
        box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
      }
    }
  }
  
  .porter-pill {
    display: inline-flex;
    align-items: center;
    background-color: mix.color('primary');
    color: white;
    border-radius: 100px;
    padding: 4px 8px 4px 12px;
    gap: 8px;
    
    .porter-name {
      font-weight: 500;
      font-size: mix.font-size('sm');
    }
    
    .porter-remove {
      width: 18px;
      height: 18px;
      border-radius: 50%;
      background-color: rgba(255, 255, 255, 0.2);
      border: none;
      font-size: 12px;
      line-height: 1;
      color: white;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      
      &:hover {
        background-color: rgba(255, 255, 255, 0.3);
      }
    }
  }
}
</style>
