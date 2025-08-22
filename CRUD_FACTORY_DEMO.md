# CRUD Factory Demonstration

## 🔥 **Massive Code Reduction Example**

### **BEFORE: Current taskTypes.ts Route (139 lines)**

```typescript
import { Router, Request, Response } from 'express';
import { prisma } from '../server';

const router = Router();

// GET /api/task-types - Get all task types with optional task items
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      include_items = 'false',
      limit = '100',
      offset = '0' 
    } = req.query;

    const includeItems = include_items === 'true';

    const taskTypes = await prisma.taskType.findMany({
      include: includeItems ? {
        task_items: {
          orderBy: { name: 'asc' }
        }
      } : undefined,
      orderBy: { name: 'asc' },
      take: parseInt(limit as string),
      skip: parseInt(offset as string)
    });
    
    res.json(taskTypes);
  } catch (error) {
    console.error('Error fetching task types:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch task types'
    });
  }
});

// GET /api/task-types/:id - Get specific task type
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { include_items = 'true' } = req.query;

    const includeItems = include_items === 'true';

    const taskType = await prisma.taskType.findUnique({
      where: { id },
      include: includeItems ? {
        task_items: {
          orderBy: { name: 'asc' }
        }
      } : undefined
    });

    if (!taskType) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task type not found'
      });
      return;
    }

    res.json(taskType);
  } catch (error) {
    console.error('Error fetching task type:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch task type'
    });
  }
});

// POST /api/task-types - Create new task type
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const {
      name,
      description
    } = req.body;

    // Validate required fields
    if (!name) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'name is required'
      });
      return;
    }

    const taskType = await prisma.taskType.create({
      data: {
        name,
        description: description || null
      }
    });

    res.status(201).json(taskType);
  } catch (error) {
    console.error('Error creating task type:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create task type'
    });
  }
});

// PUT /api/task-types/:id - Update task type
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Remove id from update data if present
    delete updateData.id;

    const taskType = await prisma.taskType.update({
      where: { id },
      data: updateData
    });

    res.json(taskType);
  } catch (error: any) {
    console.error('Error updating task type:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task type not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update task type'
    });
  }
});

// DELETE /api/task-types/:id - Delete task type
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.taskType.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting task type:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Task type not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete task type'
    });
  }
});

export default router;
```

### **AFTER: Using CRUD Factory (3 lines!)**

```typescript
import { createEntityRouter } from '../utils/crudFactory';

// That's it! Full CRUD functionality in 1 line
export default createEntityRouter('TASK_TYPES');
```

---

## 📊 **Impact Across All Entities**

### **Current State** (Massive Duplication)
- **taskTypes.ts**: 139 lines
- **staff.ts**: 180 lines  
- **buildings.ts**: 125 lines
- **departments.ts**: 145 lines
- **supportServices.ts**: 160 lines
- **taskItems.ts**: 130 lines

**Total**: ~879 lines of nearly identical CRUD code

### **After CRUD Factory** (DRY Implementation)
- **All entity routes**: 3 lines each × 6 entities = **18 lines total**
- **CRUD Factory utility**: ~300 lines (reusable)

**Total**: ~318 lines (**64% reduction**)

---

## 🚀 **Additional Benefits**

### **1. Consistent API Behavior**
- **Standardized pagination** across all entities
- **Uniform error handling** and status codes
- **Consistent search functionality**
- **Standardized response formats**

### **2. Enhanced Features (Free)**
All entities automatically get:
- ✅ **Pagination** with configurable limits
- ✅ **Search** across specified fields
- ✅ **Filtering** by any field
- ✅ **Soft delete** support (configurable)
- ✅ **Proper error handling** with meaningful messages
- ✅ **Input validation** with custom rules
- ✅ **Response formatting** with custom transformers

### **3. Developer Experience**
- **New entity in 5 minutes**: Just add config and route
- **Consistent patterns**: No need to remember different API structures
- **Type safety**: Full TypeScript support
- **Easy testing**: Test the factory once, all entities work

---

## 🎯 **Migration Strategy**

### **Phase 1: Gradual Migration** (Low Risk)
1. Keep existing routes working
2. Add CRUD factory routes alongside
3. Test thoroughly
4. Switch frontend to use new routes
5. Remove old routes

### **Phase 2: Enhanced Features**
1. Add search functionality to frontend
2. Implement pagination UI components
3. Add filtering capabilities
4. Enhance error handling

### **Phase 3: Advanced Features**
1. Add bulk operations
2. Implement field-level permissions
3. Add audit logging
4. Create API documentation generator

---

## 💡 **Real-World Example Usage**

```typescript
// Creating a new entity route becomes trivial:

// 1. Add to CRUD_CONFIGS
LOCATIONS: {
  model: 'locations',
  entityName: 'Location',
  requiredFields: ['name', 'type'],
  optionalFields: ['description', 'capacity'],
  include: { departments: true, equipment: true },
  search: { fields: ['name', 'description'] },
  customValidation: (data) => {
    // Custom business logic
    if (data.capacity && data.capacity < 0) {
      return { isValid: false, errors: ['Capacity must be positive'] };
    }
    return { isValid: true, errors: [] };
  }
}

// 2. Create route file (locations.ts)
export default createEntityRouter('LOCATIONS');

// 3. Register in server.ts
app.use('/api/locations', locationRoutes);

// Done! Full CRUD API with search, pagination, validation, etc.
```

This CRUD factory would be the **highest impact DRY improvement** possible, eliminating hundreds of lines of duplicate code while providing enhanced functionality across all entities.
