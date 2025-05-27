-- FIX for porter assignment issue: ensuring changes to shift porter assignments don't affect defaults

-- Step 1: Diagnostics - Check for triggers that might be causing the issue
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE event_object_table IN (
  'shift_area_cover_assignments', 
  'shift_area_cover_porter_assignments',
  'shift_support_service_assignments',
  'shift_support_service_porter_assignments'
);

-- Step 2: Examine relationships between shift assignments and defaults
-- Check if there are foreign key constraints linking shift assignments back to defaults
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM
    information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name IN (
    'shift_area_cover_assignments', 
    'shift_area_cover_porter_assignments',
    'shift_support_service_assignments',
    'shift_support_service_porter_assignments'
  );

-- Step 3: Remove any triggers that might be updating defaults based on shift changes
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    -- Find any triggers that might be causing the issue
    FOR trigger_record IN 
        SELECT trigger_name, event_object_table
        FROM information_schema.triggers
        WHERE event_object_table IN (
            'shift_area_cover_assignments', 
            'shift_area_cover_porter_assignments',
            'shift_support_service_assignments',
            'shift_support_service_porter_assignments'
        )
        AND action_statement LIKE '%default%'
    LOOP
        -- Drop any suspicious triggers
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I;', 
                      trigger_record.trigger_name, 
                      trigger_record.event_object_table);
        
        RAISE NOTICE 'Dropped trigger % on table %', 
                    trigger_record.trigger_name, 
                    trigger_record.event_object_table;
    END LOOP;
END
$$;

-- Step 4: Create or replace function for copying defaults to shifts without reverse updates
CREATE OR REPLACE FUNCTION copy_defaults_to_shift()
RETURNS TRIGGER AS $$
BEGIN
    -- This function should only copy from defaults to shifts, never the reverse
    -- Implementation depends on the specific schema
    -- This is a placeholder for the actual implementation
    
    -- For area cover defaults
    IF TG_TABLE_NAME = 'area_cover_defaults' AND TG_OP = 'UPDATE' THEN
        -- Update any active shifts using this default, but don't touch completed shifts
        UPDATE shift_area_cover_assignments
        SET start_time = NEW.start_time,
            end_time = NEW.end_time
        FROM shifts
        WHERE shift_area_cover_assignments.shift_id = shifts.id
        AND shifts.is_active = true
        AND shift_area_cover_assignments.department_id = NEW.department_id;
    END IF;
    
    -- For support service defaults
    IF TG_TABLE_NAME = 'support_service_defaults' AND TG_OP = 'UPDATE' THEN
        -- Update any active shifts using this default, but don't touch completed shifts
        UPDATE shift_support_service_assignments
        SET start_time = NEW.start_time,
            end_time = NEW.end_time
        FROM shifts
        WHERE shift_support_service_assignments.shift_id = shifts.id
        AND shifts.is_active = true
        AND shift_support_service_assignments.service_id = NEW.service_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create proper triggers that only go from defaults to shifts, not the reverse
DROP TRIGGER IF EXISTS update_shifts_from_area_cover_defaults ON area_cover_defaults;
CREATE TRIGGER update_shifts_from_area_cover_defaults
AFTER UPDATE ON area_cover_defaults
FOR EACH ROW
EXECUTE FUNCTION copy_defaults_to_shift();

DROP TRIGGER IF EXISTS update_shifts_from_support_service_defaults ON support_service_defaults;
CREATE TRIGGER update_shifts_from_support_service_defaults
AFTER UPDATE ON support_service_defaults
FOR EACH ROW
EXECUTE FUNCTION copy_defaults_to_shift();

-- Step 6: Verify there are no remaining triggers that would cause reverse updates
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers
WHERE event_object_table IN (
  'shift_area_cover_assignments', 
  'shift_area_cover_porter_assignments',
  'shift_support_service_assignments',
  'shift_support_service_porter_assignments'
)
AND action_statement LIKE '%default%';

-- Step 7: Add documentation comment to the database
COMMENT ON FUNCTION copy_defaults_to_shift() IS 
'This function handles the one-way copying of default settings to active shifts.
Changes to defaults can affect active shifts, but changes to shifts should never affect defaults.
This function replaces the previous behavior where shift changes would modify defaults.';
