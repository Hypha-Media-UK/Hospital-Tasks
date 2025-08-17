# Time Formatting Issues Throughout the App

## 🔍 **Issue Summary**
The same time formatting issue that affected the staff routes exists throughout multiple API routes. The problem is that:
- **GET requests** format time fields correctly: `"08:30"`
- **POST/PUT requests** return raw DateTime objects: `"1970-01-01T08:30:00.000Z"`

This causes the frontend to display incorrect time values like "1970--1970-" instead of "08:30-16:30".

## 🛠️ **Solution Implemented**
Created shared utility functions in `api/src/middleware/errorHandler.ts`:

```typescript
// Format time field for API response
export const formatTimeField = (timeValue: any): string | null => {
  if (!timeValue) return null;
  if (timeValue instanceof Date) {
    return timeValue.toISOString().substring(11, 16); // Extract HH:MM
  }
  return timeValue;
};

// Convert HH:MM string to database DateTime
export const formatTimeForDB = (timeStr: string | null): Date | null => {
  if (!timeStr) return null;
  if (typeof timeStr === 'string' && timeStr.match(/^\d{2}:\d{2}$/)) {
    return new Date(`1970-01-01T${timeStr}:00.000Z`);
  }
  return timeStr as any;
};

// Format multiple time fields in an object
export const formatObjectTimeFields = (obj: any, timeFields: string[]): any => {
  if (!obj) return obj;
  const formatted = { ...obj };
  timeFields.forEach(field => {
    if (formatted[field]) {
      formatted[field] = formatTimeField(formatted[field]);
    }
  });
  return formatted;
};
```

## 📋 **Routes That Need Fixing**

### ✅ **FIXED: Staff Routes** (`api/src/routes/staff.ts`)
- Updated to use shared utilities
- All POST/PUT responses now format time correctly

### ❌ **NEEDS FIXING: Area Cover Routes** (`api/src/routes/areaCover.ts`)
**Time Fields:** `start_time`, `end_time`
**Issues Found:**
- Lines 114-115, 181-182: POST/PUT responses don't format time
- Lines 294-295, 339-340: Porter assignment responses don't format time

**Fix Required:**
```typescript
// Replace raw responses with:
const response = formatObjectTimeFields(assignment, ['start_time', 'end_time']);
res.status(201).json(response);
```

### ❌ **NEEDS FIXING: Support Services Routes** (`api/src/routes/supportServices.ts`)
**Time Fields:** `start_time`, `end_time`
**Issues Found:**
- Has time parsing logic but missing response formatting
- Multiple endpoints handle time fields inconsistently

**Fix Required:**
- Apply `formatObjectTimeFields` to all POST/PUT responses
- Update existing `parseTimeString` to use shared `formatTimeForDB`

### ❌ **NEEDS FIXING: Settings/Shift Defaults** (`api/src/routes/settings.ts`)
**Time Fields:** `start_time`, `end_time`
**Issues Found:**
- Lines 93-94: POST creates DateTime but doesn't format response
- Lines 36-44: PUT updates time but doesn't format response

**Fix Required:**
```typescript
// After creating/updating shift default:
const formattedShiftDefault = formatObjectTimeFields(shiftDefault, ['start_time', 'end_time']);
res.status(201).json(formattedShiftDefault);
```

### ⚠️ **DIFFERENT ISSUE: Shifts Routes** (`api/src/routes/shifts.ts`)
**Time Fields:** `start_time`, `end_time`
**Note:** These are full DateTime timestamps, not just time values
**Issues Found:**
- Uses full timestamps for shift start/end times
- Different from other routes that use @db.Time fields
- May need different formatting approach

### ⚠️ **STRING FIELDS: Tasks Routes** (`api/src/routes/tasks.ts`)
**Time Fields:** `time_received`, `time_allocated`, `time_completed`
**Note:** These are stored as VARCHAR strings, not @db.Time
**Status:** Likely no formatting issues as they're already strings

## 🎯 **Priority Fix Order**

1. **HIGH PRIORITY:**
   - ✅ Staff Routes (COMPLETED)
   - ❌ Area Cover Routes (PARTIALLY STARTED)
   - ❌ Support Services Routes
   - ❌ Settings/Shift Defaults Routes

2. **MEDIUM PRIORITY:**
   - ❌ Shifts Routes (different issue - full timestamps)

3. **LOW PRIORITY:**
   - ✅ Tasks Routes (likely no issues - string fields)

## 🔧 **Systematic Fix Approach**

For each route file:

1. **Import utilities:**
   ```typescript
   import { formatObjectTimeFields, formatTimeForDB } from '../middleware/errorHandler';
   ```

2. **Update input parsing:**
   ```typescript
   // Replace manual time parsing with:
   const startTime = formatTimeForDB(start_time);
   const endTime = formatTimeForDB(end_time);
   ```

3. **Update response formatting:**
   ```typescript
   // Replace raw responses with:
   const formattedResponse = formatObjectTimeFields(data, ['start_time', 'end_time']);
   res.status(201).json(formattedResponse);
   ```

## 🧪 **Testing Strategy**

After fixing each route:
1. Test POST requests return formatted times: `"08:30"`
2. Test PUT requests return formatted times: `"08:30"`
3. Test GET requests still work correctly
4. Test frontend displays times correctly

## 📊 **Database Schema Reference**

Fields using `@db.Time(0)` that need formatting:
- `staff.contracted_hours_start`, `staff.contracted_hours_end`
- `default_area_cover_assignments.start_time`, `default_area_cover_assignments.end_time`
- `default_area_cover_porter_assignments.start_time`, `default_area_cover_porter_assignments.end_time`
- `default_service_cover_assignments.start_time`, `default_service_cover_assignments.end_time`
- `default_service_cover_porter_assignments.start_time`, `default_service_cover_porter_assignments.end_time`
- `shift_defaults.start_time`, `shift_defaults.end_time`
- `shift_area_cover_assignments.start_time`, `shift_area_cover_assignments.end_time`
- `shift_area_cover_porter_assignments.start_time`, `shift_area_cover_porter_assignments.end_time`
- `shift_porter_absences.start_time`, `shift_porter_absences.end_time`
- `shift_support_service_assignments.start_time`, `shift_support_service_assignments.end_time`
- `shift_support_service_porter_assignments.start_time`, `shift_support_service_porter_assignments.end_time`
- `support_service_assignments.start_time`, `support_service_assignments.end_time`
- `support_service_porter_assignments.start_time`, `support_service_porter_assignments.end_time`
