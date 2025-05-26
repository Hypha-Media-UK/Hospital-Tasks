# Hospital Task Management System Database Schema

## Understanding the Fix

The issue was occurring because there were multiple competing database triggers trying to copy default assignments to new shifts. This was causing a 409 Conflict error when creating new shifts, and also causing changes in shift-specific assignments to affect default settings.

## Schema Overview

The database schema properly separates default assignments from shift-specific assignments:

### Default Settings Tables
- `default_area_cover_assignments` - Stores default department assignments for each shift type
- `default_area_cover_porter_assignments` - Stores default porter assignments for area cover
- `default_service_cover_assignments` - Stores default service assignments for each shift type
- `default_service_cover_porter_assignments` - Stores default porter assignments for service cover

### Shift-Specific Tables
- `shift_area_cover_assignments` - Stores department assignments for a specific shift
- `shift_area_cover_porter_assignments` - Stores porter assignments for area cover in a specific shift
- `shift_support_service_assignments` - Stores service assignments for a specific shift
- `shift_support_service_porter_assignments` - Stores porter assignments for service cover in a specific shift

## Data Flow

1. Default assignments are configured in the Settings screen:
   - These are stored in the `default_*` tables
   - Changes here will affect future shifts but not existing shifts

2. When a new shift is created:
   - The trigger `copy_defaults_to_new_shift` calls `copy_defaults_on_shift_creation()`
   - This copies the appropriate default assignments to the shift-specific tables
   - Each shift gets its own copies of all assignments

3. When editing a shift:
   - Changes are made only to the shift-specific tables
   - These changes don't affect the default settings

## Implementation Notes

1. The `cleanup-and-fix-triggers.sql` script:
   - Removes redundant triggers and functions
   - Ensures proper data migration from old to new schema
   - Creates a clean, non-conflicting structure
   - Preserves all existing data

2. After applying this script:
   - Creating new shifts should work without the 409 error
   - Changes to assignments in a shift will not affect default settings
   - Default settings will only be used when creating new shifts

## Applying the Fix

1. Run the `cleanup-and-fix-triggers.sql` script on your Supabase database
2. The existing `shiftsStore.js` file already has the proper methods for working with shift-specific assignments
3. No front-end code changes should be needed, as the fix is entirely on the database side
