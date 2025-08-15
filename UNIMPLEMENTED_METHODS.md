# Unimplemented Frontend Methods Analysis

This document tracks frontend methods that are not yet implemented and their corresponding backend API status.

## Status Legend
- ✅ **IMPLEMENTED** - Both frontend and backend are working
- ❌ **MISSING** - Method/API does not exist or is placeholder
- 🔄 **PARTIAL** - Some functionality exists but incomplete
- 📋 **PLANNED** - Marked for future implementation

---

## 1. Area Cover Store ✅ **FIXED**
**File:** `src/stores/areaCoverStore.js`
**Status:** All methods now implemented and working

- ✅ `addPorterAssignment()` → `POST /api/area-cover/assignments/:id/porter-assignments`
- ✅ `updatePorterAssignment()` → `PUT /api/area-cover/porter-assignments/:id`
- ✅ `removePorterAssignment()` → `DELETE /api/area-cover/porter-assignments/:id`

---

## 2. Task Store ❌ **BACKEND NEEDED**
**File:** `src/stores/taskStore.js`
**Backend:** `api/src/routes/tasks.ts`
**Status:** Backend only has placeholder endpoint

### Frontend Methods (Not Implemented)
- ❌ `fetchTasks()` - "Tasks API not yet implemented"
- ❌ `createTask()` - "Task creation not yet implemented"
- ❌ `updateTask()` - "Task update not yet implemented"
- ❌ `deleteTask()` - "Task deletion not yet implemented"

### Backend Status
- ❌ Only returns `{ message: 'tasks endpoint - coming soon' }`
- 📋 **Action Required:** Implement full tasks CRUD API

---

## 3. Shifts Store - Building Assignments 🔄 **PARTIAL**
**File:** `src/stores/shiftsStore.js`
**Backend:** `api/src/routes/shifts.ts`
**Status:** Advanced feature set - some APIs exist, some don't

### Frontend Methods (Not Implemented)
- ❌ `isPorterAssignedToBuilding()` - "not yet implemented"
- ❌ `fetchShiftPorterBuildingAssignments()` - "not yet implemented"
- ❌ `cleanupAllExpiredAssignments()` - "not yet implemented"
- ❌ `duplicateShift()` - "not yet implemented"
- ❌ `togglePorterBuildingAssignment()` - "not yet implemented"

### Backend Status Analysis
**Existing APIs:**
- ✅ `GET /api/shifts` - Get all shifts
- ✅ `POST /api/shifts` - Create shift
- ✅ `PUT /api/shifts/:id` - Update shift
- ✅ `DELETE /api/shifts/:id` - Delete shift
- ✅ `GET /api/shifts/:id/porter-pool` - Get shift porter pool
- ✅ `POST /api/shifts/:id/porter-pool` - Add porter to pool

**Missing APIs for Building Assignments:**
- ❌ No building-specific porter assignment endpoints
- ❌ No cleanup/maintenance endpoints
- ❌ No shift duplication endpoint
- 📋 **Action Required:** Design and implement building assignment system

---

## 4. Other Placeholder Methods
**File:** `src/stores/areaCoverStore.js`
- ❌ `fetchShiftPorterBuildingAssignments()` - "not yet implemented"
  - **Note:** This appears to be related to the building assignment system above

---

## Implementation Priority

### 🔥 **HIGH PRIORITY** (User-Facing Features)
1. ✅ **Area Cover Porter Assignments** - COMPLETED
   - These were causing immediate console errors

### 🟡 **MEDIUM PRIORITY** (Core Functionality)
2. **Task Management System**
   - Backend API needs to be built first
   - Frontend methods are correctly showing "not implemented"
   - Required for task assignment and tracking features

### 🔵 **LOW PRIORITY** (Advanced Features)
3. **Building-Specific Porter Assignments**
   - Complex feature requiring new database schema
   - Multiple related APIs needed
   - Advanced shift management functionality

---

## Development Notes

### Good Practices Observed
- ✅ Frontend methods show clear "not yet implemented" messages
- ✅ Methods return appropriate default values (null, false, empty arrays)
- ✅ Error handling prevents silent failures
- ✅ Console logging helps with debugging

### Recommendations
1. **Keep placeholder messages** until backend APIs are ready
2. **Implement backend APIs first** before updating frontend methods
3. **Test thoroughly** when connecting frontend to new backend endpoints
4. **Update this document** when implementing new features

---

## Last Updated
August 15, 2025 - Area Cover Store porter assignment methods implemented and tested.
