import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import type { PaginationParams, PaginationMeta } from '@hospital-tasks/shared';

// ============================================================================
// GENERIC ENTITY STORE FACTORY - DRY STORE PATTERN
// ============================================================================

interface EntityStoreConfig<T, TCreate, TUpdate> {
  name: string;
  apiComposable: () => {
    loading: any;
    error: any;
    getAll: (params?: any) => Promise<{ data: T[]; pagination: PaginationMeta }>;
    getOne: (id: string) => Promise<T>;
    create: (data: TCreate) => Promise<T>;
    update: (id: string, data: TUpdate) => Promise<T>;
    delete: (id: string) => Promise<void>;
  };
}

export function createEntityStore<T extends { id: string }, TCreate, TUpdate>(
  config: EntityStoreConfig<T, TCreate, TUpdate>
) {
  return defineStore(config.name, () => {
    // State
    const items = ref<T[]>([]);
    const currentItem = ref<T | null>(null);
    const pagination = ref<PaginationMeta>({
      total: 0,
      limit: 100,
      offset: 0,
      hasMore: false,
    });
    const loading = ref({
      list: false,
      item: false,
      create: false,
      update: false,
      delete: false,
    });
    const error = ref<string | null>(null);
    const searchQuery = ref('');

    // API instance
    const api = config.apiComposable();

    // Getters
    const filteredItems = computed(() => {
      if (!searchQuery.value) return items.value;
      
      const query = searchQuery.value.toLowerCase();
      return items.value.filter(item => 
        Object.values(item).some(value => 
          String(value).toLowerCase().includes(query)
        )
      );
    });

    const hasItems = computed(() => items.value.length > 0);
    const isLoading = computed(() => Object.values(loading.value).some(Boolean));

    // Actions
    async function fetchItems(params?: PaginationParams & { search?: string }) {
      loading.value.list = true;
      error.value = null;

      try {
        const response = await api.getAll(params);
        items.value = response.data;
        pagination.value = response.pagination;
      } catch (err) {
        error.value = err instanceof Error ? err.message : 'Failed to fetch items';
        console.error(`Error fetching ${config.name}:`, err);
      } finally {
        loading.value.list = false;
      }
    }

    async function fetchItem(id: string) {
      loading.value.item = true;
      error.value = null;

      try {
        const item = await api.getOne(id);
        currentItem.value = item;
        
        // Update item in list if it exists
        const index = items.value.findIndex(i => i.id === id);
        if (index !== -1) {
          items.value[index] = item;
        }
        
        return item;
      } catch (err) {
        error.value = err instanceof Error ? err.message : 'Failed to fetch item';
        console.error(`Error fetching ${config.name} item:`, err);
        throw err;
      } finally {
        loading.value.item = false;
      }
    }

    async function createItem(data: TCreate) {
      loading.value.create = true;
      error.value = null;

      try {
        const newItem = await api.create(data);
        items.value.unshift(newItem);
        pagination.value.total += 1;
        return newItem;
      } catch (err) {
        error.value = err instanceof Error ? err.message : 'Failed to create item';
        console.error(`Error creating ${config.name}:`, err);
        throw err;
      } finally {
        loading.value.create = false;
      }
    }

    async function updateItem(id: string, data: TUpdate) {
      loading.value.update = true;
      error.value = null;

      try {
        const updatedItem = await api.update(id, data);
        
        // Update in list
        const index = items.value.findIndex(i => i.id === id);
        if (index !== -1) {
          items.value[index] = updatedItem;
        }
        
        // Update current item if it's the same
        if (currentItem.value?.id === id) {
          currentItem.value = updatedItem;
        }
        
        return updatedItem;
      } catch (err) {
        error.value = err instanceof Error ? err.message : 'Failed to update item';
        console.error(`Error updating ${config.name}:`, err);
        throw err;
      } finally {
        loading.value.update = false;
      }
    }

    async function deleteItem(id: string) {
      loading.value.delete = true;
      error.value = null;

      try {
        await api.delete(id);
        
        // Remove from list
        const index = items.value.findIndex(i => i.id === id);
        if (index !== -1) {
          items.value.splice(index, 1);
          pagination.value.total -= 1;
        }
        
        // Clear current item if it's the same
        if (currentItem.value?.id === id) {
          currentItem.value = null;
        }
      } catch (err) {
        error.value = err instanceof Error ? err.message : 'Failed to delete item';
        console.error(`Error deleting ${config.name}:`, err);
        throw err;
      } finally {
        loading.value.delete = false;
      }
    }

    function setSearchQuery(query: string) {
      searchQuery.value = query;
    }

    function clearError() {
      error.value = null;
    }

    function reset() {
      items.value = [];
      currentItem.value = null;
      pagination.value = {
        total: 0,
        limit: 100,
        offset: 0,
        hasMore: false,
      };
      searchQuery.value = '';
      error.value = null;
      Object.keys(loading.value).forEach(key => {
        loading.value[key as keyof typeof loading.value] = false;
      });
    }

    // Return store interface
    return {
      // State
      items: computed(() => items.value),
      currentItem: computed(() => currentItem.value),
      pagination: computed(() => pagination.value),
      loading: computed(() => loading.value),
      error: computed(() => error.value),
      searchQuery: computed(() => searchQuery.value),
      
      // Getters
      filteredItems,
      hasItems,
      isLoading,
      
      // Actions
      fetchItems,
      fetchItem,
      createItem,
      updateItem,
      deleteItem,
      setSearchQuery,
      clearError,
      reset,
    };
  });
}
