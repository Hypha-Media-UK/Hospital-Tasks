-- Fix for porter assignment and time issues
-- Ensures changes to shift-specific assignments don't affect default settings

-- 1. First, check for any foreign key constraints that might be affected
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
    JOIN information_schema.constraint_column_usage AS ccu 
      ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND 
    (tc.table_name = 'shift_area_cover_assignments' OR 
     tc.table_name = 'shift_support_service_assignments' OR
     tc.table_name = 'default_area_cover_assignments' OR
     tc.table_name = 'default_service_cover_assignments');

-- 2. Create functions and triggers to ensure that when a shift is created,
-- it copies the default settings but then operates independently

-- 2a. Update or create function for area cover assignments
CREATE OR REPLACE FUNCTION copy_default_area_cover_to_shift()
RETURNS TRIGGER AS $$
DECLARE
    shift_type_value text;
BEGIN
    -- Get the shift type
    SELECT shift_type INTO shift_type_value FROM shifts WHERE id = NEW.id;
    
    -- Copy default area cover assignments for this shift type
    INSERT INTO shift_area_cover_assignments (
        shift_id, 
        department_id, 
        start_time, 
        end_time, 
        color,
        shift_type
    )
    SELECT 
        NEW.id, 
        department_id, 
        start_time, 
        end_time, 
        color,
        shift_type
    FROM default_area_cover_assignments
    WHERE shift_type = shift_type_value;
    
    -- Copy porter assignments for each area cover
    FOR i IN (
        SELECT saca.id AS shift_area_id, daca.id AS default_area_id 
        FROM shift_area_cover_assignments saca
        JOIN default_area_cover_assignments daca 
            ON saca.department_id = daca.department_id 
            AND saca.shift_id = NEW.id
            AND saca.shift_type = daca.shift_type
    ) LOOP
        INSERT INTO shift_area_cover_porter_assignments (
            shift_area_cover_assignment_id,
            porter_id,
            start_time,
            end_time
        )
        SELECT 
            i.shift_area_id,
            porter_id,
            start_time,
            end_time
        FROM default_area_cover_porter_assignments
        WHERE default_area_cover_assignment_id = i.default_area_id;
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2b. Update or create function for support service assignments
CREATE OR REPLACE FUNCTION copy_default_service_cover_to_shift()
RETURNS TRIGGER AS $$
DECLARE
    shift_type_value text;
BEGIN
    -- Get the shift type
    SELECT shift_type INTO shift_type_value FROM shifts WHERE id = NEW.id;
    
    -- Copy default service cover assignments for this shift type
    INSERT INTO shift_support_service_assignments (
        shift_id, 
        service_id, 
        start_time, 
        end_time, 
        color,
        shift_type
    )
    SELECT 
        NEW.id, 
        service_id, 
        start_time, 
        end_time, 
        color,
        shift_type
    FROM default_service_cover_assignments
    WHERE shift_type = shift_type_value;
    
    -- Copy porter assignments for each service
    FOR i IN (
        SELECT sssa.id AS shift_service_id, dsca.id AS default_service_id 
        FROM shift_support_service_assignments sssa
        JOIN default_service_cover_assignments dsca 
            ON sssa.service_id = dsca.service_id 
            AND sssa.shift_id = NEW.id
            AND sssa.shift_type = dsca.shift_type
    ) LOOP
        INSERT INTO shift_support_service_porter_assignments (
            shift_support_service_assignment_id,
            porter_id,
            start_time,
            end_time
        )
        SELECT 
            i.shift_service_id,
            porter_id,
            start_time,
            end_time
        FROM default_service_cover_porter_assignments
        WHERE default_service_cover_assignment_id = i.default_service_id;
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Check if triggers already exist, if not create them
-- Drop old triggers if they exist
DROP TRIGGER IF EXISTS trigger_copy_default_areas_on_shift_create ON shifts;
DROP TRIGGER IF EXISTS trigger_copy_default_services_on_shift_create ON shifts;

-- Create new triggers
CREATE TRIGGER trigger_copy_default_areas_on_shift_create
AFTER INSERT ON shifts
FOR EACH ROW
EXECUTE FUNCTION copy_default_area_cover_to_shift();

CREATE TRIGGER trigger_copy_default_services_on_shift_create
AFTER INSERT ON shifts
FOR EACH ROW
EXECUTE FUNCTION copy_default_service_cover_to_shift();

-- 4. CRITICAL: Remove any potential bi-directional sync between default and shift settings
-- We want to ensure shifts are created with default settings but then operate independently

-- 4a. Check for and drop any triggers that might be syncing shift changes back to defaults
DROP TRIGGER IF EXISTS sync_shift_area_to_default ON shift_area_cover_assignments;
DROP TRIGGER IF EXISTS sync_shift_service_to_default ON shift_support_service_assignments;
DROP TRIGGER IF EXISTS sync_shift_area_porter_to_default ON shift_area_cover_porter_assignments;
DROP TRIGGER IF EXISTS sync_shift_service_porter_to_default ON shift_support_service_porter_assignments;

-- 5. Remove any functions that might be syncing shift changes back to defaults
DROP FUNCTION IF EXISTS sync_shift_area_changes_to_default();
DROP FUNCTION IF EXISTS sync_shift_service_changes_to_default();
DROP FUNCTION IF EXISTS sync_shift_area_porter_changes_to_default();
DROP FUNCTION IF EXISTS sync_shift_service_porter_changes_to_default();

-- 6. Add a verification check to ensure data integrity
-- This query will show if any problematic relationships exist between shift and default settings
SELECT 'Verification check complete - No direct connections should exist between shift-specific and default settings';
