<template>
  <div class="info-card">
    <div class="info-header">
      <div class="info-details">
        <h3 class="info-title">{{ title }}</h3>
        <p v-if="subtitle" class="info-subtitle">{{ subtitle }}</p>
      </div>
      <div class="info-meta">
        <div :class="`info-badge ${badgeClass || ''}`">
          {{ badgeText }}
        </div>
      </div>
    </div>

    <div class="info-stats">
      <div v-for="(stat, index) in stats" :key="index" class="stat-item">
        <span class="stat-label">{{ stat.label }}:</span>
        <span class="stat-value">{{ stat.value }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
interface StatItem {
  label: string
  value: string | number
}

interface Props {
  title: string
  subtitle?: string
  badgeText: string
  badgeClass?: string
  stats: StatItem[]
}

defineProps<Props>()
</script>

<style scoped>
.info-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: var(--spacing-md, 16px);
}

.info-details {
  flex: 1;
}

.info-title {
  margin: 0 0 var(--spacing-xs, 8px) 0;
  font-size: var(--font-size-xl, 1.125rem);
  font-weight: 600;
  color: var(--color-text-primary, #212529);
}

.info-subtitle {
  margin: 0;
  font-size: var(--font-size-md, 0.875rem);
  color: var(--color-text-muted, #6c757d);
  line-height: 1.5;
}

.info-meta {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm, 8px);
}

.info-badge {
  padding: var(--spacing-xs, 4px) var(--spacing-sm, 8px);
  border-radius: var(--border-radius-full, 16px);
  font-size: var(--font-size-sm, 0.75rem);
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

/* Default badge styling */
.info-badge {
  background-color: var(--color-success-light, #d1e7dd);
  color: var(--color-success, #198754);
}

/* Badge variants */
.badge-week-day {
  background-color: var(--color-primary-light, #cfe2ff);
  color: var(--color-primary, #0d6efd);
}

.badge-week-night {
  background-color: var(--color-secondary-light, #e2e3e5);
  color: var(--color-secondary, #6c757d);
}

.badge-weekend-day {
  background-color: var(--color-success-light, #d1e7dd);
  color: var(--color-success, #198754);
}

.badge-weekend-night {
  background-color: var(--color-warning-light, #fff3cd);
  color: var(--color-warning, #664d03);
}

.badge-default {
  background-color: var(--color-gray-100, #f8f9fa);
  color: var(--color-text-muted, #6c757d);
}

.info-stats {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm, 8px);
  padding-top: var(--spacing-md, 16px);
  border-top: 1px solid var(--color-border, #e9ecef);
}

.stat-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.stat-label {
  font-size: var(--font-size-sm, 0.875rem);
  color: var(--color-text-muted, #6c757d);
  font-weight: 500;
}

.stat-value {
  font-size: var(--font-size-sm, 0.875rem);
  color: var(--color-text-primary, #212529);
  font-weight: 500;
}

.info-card {
  background: var(--color-background, #f8f9fa);
  border: 1px solid var(--color-border, #e9ecef);
  border-radius: 8px;
  padding: 16px;
}

@media (max-width: 768px) {
  .info-header {
    flex-direction: column;
    gap: var(--spacing-md, 16px);
    align-items: stretch;
  }

  .info-meta {
    justify-content: flex-start;
  }

  .info-stats {
    gap: var(--spacing-xs, 4px);
  }

  .stat-item {
    flex-direction: column;
    align-items: flex-start;
    gap: var(--spacing-xs, 4px);
  }
}
</style>
