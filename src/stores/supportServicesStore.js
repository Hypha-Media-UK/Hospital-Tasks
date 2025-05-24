import { defineStore } from 'pinia';
import { supabase } from '../services/supabase';

export const useSupportServicesStore = defineStore('supportServices', {
  state: () => ({
    supportServices: [],
    servicePorterAssignments: {},
    loading: false,
    error: null
  }),
  
  actions: {
    // Load all support services from Supabase
    async loadSupportServices() {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_services')
          .select('*')
          .order('name');
        
        if (error) throw error;
        
        this.supportServices = data || [];
        return data;
      } catch (error) {
        console.error('Error loading support services:', error);
        this.error = 'Failed to load support services';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Add a new support service
    async addSupportService(service) {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_services')
          .insert({
            name: service.name,
            description: service.description || null,
            is_active: true
          })
          .select();
        
        if (error) throw error;
        
        // Add the new service to the local array
        if (data && data.length > 0) {
          this.supportServices.push(data[0]);
          // Sort the array by name
          this.supportServices.sort((a, b) => a.name.localeCompare(b.name));
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error adding support service:', error);
        this.error = 'Failed to add support service';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Update an existing support service
    async updateSupportService(service) {
      this.loading = true;
      this.error = null;
      
      try {
        const { data, error } = await supabase
          .from('support_services')
          .update({
            name: service.name,
            description: service.description,
            is_active: service.is_active,
            updated_at: new Date().toISOString()
          })
          .eq('id', service.id)
          .select();
        
        if (error) throw error;
        
        // Update the service in the local array
        if (data && data.length > 0) {
          const index = this.supportServices.findIndex(s => s.id === service.id);
          if (index !== -1) {
            this.supportServices[index] = data[0];
          }
          // Sort the array by name
          this.supportServices.sort((a, b) => a.name.localeCompare(b.name));
        }
        
        return data && data[0];
      } catch (error) {
        console.error('Error updating support service:', error);
        this.error = 'Failed to update support service';
        return null;
      } finally {
        this.loading = false;
      }
    },
    
    // Remove a support service
    async removeSupportService(serviceId) {
      this.loading = true;
      this.error = null;
      
      try {
        const { error } = await supabase
          .from('support_services')
          .delete()
          .eq('id', serviceId);
        
        if (error) throw error;
        
        // Remove the service from the local array
        this.supportServices = this.supportServices.filter(s => s.id !== serviceId);
        
        return true;
      } catch (error) {
        console.error('Error removing support service:', error);
        this.error = 'Failed to remove support service';
        return false;
      } finally {
        this.loading = false;
      }
    },
    
    // Eventually, add methods for porter assignments
    async loadPorterAssignments() {
      // Future implementation to load porter assignments
    }
  }
});
