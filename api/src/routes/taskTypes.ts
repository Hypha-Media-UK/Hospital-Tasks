/**
 * Task Types Routes - DRY Implementation using CRUD Factory
 * 
 * This file replaces 139 lines of duplicated CRUD code with just 3 lines!
 * 
 * Features provided by CRUD factory:
 * - GET / with pagination, search, and filtering
 * - GET /:id with relationships
 * - POST / with validation
 * - PUT /:id with validation  
 * - DELETE /:id
 * - Automatic relationship inclusion (task_items)
 * - Search across name and description fields
 * - Consistent error handling
 * - Type safety
 */

import { createEntityRouter } from '../utils/crudFactory';

// Create the entire CRUD router with enhanced features in just one line!
export default createEntityRouter('TASK_TYPES');
