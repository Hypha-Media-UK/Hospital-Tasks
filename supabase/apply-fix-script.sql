-- Script to fix the issue where changes to shift-specific assignments affect default settings
-- This script will:
-- 1. Verify the trigger function properly copies defaults to new shifts
-- 2. Remove any potential cross-table triggers that might be causing conflicts
-- 3. Ensure that shift-specific tables are fully independent from default tables

-- First, make sure we have the correct trigger installed on the shifts table
DROP TRIGGER IF EXISTS trigger_copy_default_assignments ON shifts;
DROP TRIGGER IF EXISTS copy_defaults_on_shift_creation ON shifts;
DROP TRIGGER IF EXISTS copy_defaults_to_new_shift ON shifts;

-- Drop any functions that might conflict with our desired behavior
DROP FUNCTION IF EXISTS copy_default_assignments_to_shift();

-- Create or replace the function that copies defaults to new shifts
CREATE OR REPLACE FUNCTION copy_defaults_to_shift(p_shift_id UUID, p_shift_type VARCHAR)
RETURNS VOID AS $$
DECLARE
  v_area_cover_assignment_id UUID;
  v_service_cover_assignment_id UUID;
  v_default_area_cover_id UUID;
  v_default_service_cover_id UUID;
  r_area_assignment RECORD;
  r_service_assignment RECORD;
  r_area_porter RECORD;
  r_service_porter RECORD;
BEGIN
  -- Copy area cover assignments from defaults to shift
  FOR r_area_assignment IN 
    SELECT * FROM default_area_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Insert into shift_area_cover_assignments
    INSERT INTO shift_area_cover_assignments (
      shift_id, department_id, start_time, end_time, color
    ) VALUES (
      p_shift_id, r_area_assignment.department_id, r_area_assignment.start_time, 
      r_area_assignment.end_time, r_area_assignment.color
    ) RETURNING id INTO v_area_cover_assignment_id;
    
    -- Store the default ID for later
    v_default_area_cover_id := r_area_assignment.id;
    
    -- Copy porter assignments for this area cover
    FOR r_area_porter IN 
      SELECT * FROM default_area_cover_porter_assignments 
      WHERE default_area_cover_assignment_id = v_default_area_cover_id
    LOOP
      INSERT INTO shift_area_cover_porter_assignments (
        shift_area_cover_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_area_cover_assignment_id, r_area_porter.porter_id, 
        r_area_porter.start_time, r_area_porter.end_time
      );
    END LOOP;
  END LOOP;
  
  -- Copy service cover assignments from defaults to shift
  FOR r_service_assignment IN 
    SELECT * FROM default_service_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Insert into shift_support_service_assignments
    INSERT INTO shift_support_service_assignments (
      shift_id, service_id, start_time, end_time, color
    ) VALUES (
      p_shift_id, r_service_assignment.service_id, r_service_assignment.start_time, 
      r_service_assignment.end_time, r_service_assignment.color
    ) RETURNING id INTO v_service_cover_assignment_id;
    
    -- Store the default ID for later
    v_default_service_cover_id := r_service_assignment.id;
    
    -- Copy porter assignments for this service cover
    FOR r_service_porter IN 
      SELECT * FROM default_service_cover_porter_assignments 
      WHERE default_service_cover_assignment_id = v_default_service_cover_id
    LOOP
      INSERT INTO shift_support_service_porter_assignments (
        shift_support_service_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_service_cover_assignment_id, r_service_porter.porter_id, 
        r_service_porter.start_time, r_service_porter.end_time
      );
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create a wrapper function for the trigger
CREATE OR REPLACE FUNCTION copy_defaults_on_shift_creation()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM copy_defaults_to_shift(NEW.id, NEW.shift_type);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a single trigger that uses the wrapper function
CREATE TRIGGER copy_defaults_to_new_shift
AFTER INSERT ON shifts
FOR EACH ROW
EXECUTE FUNCTION copy_defaults_on_shift_creation();

-- Now remove any potential triggers on shift-specific tables that might be 
-- causing changes to propagate back to default tables

-- Check and remove any triggers on shift_area_cover_assignments
DO $$
DECLARE
  trigger_name text;
BEGIN
  FOR trigger_name IN (
    SELECT trigger_name FROM information_schema.triggers 
    WHERE event_object_table = 'shift_area_cover_assignments'
  )
  LOOP
    EXECUTE 'DROP TRIGGER IF EXISTS ' || trigger_name || ' ON shift_area_cover_assignments';
  END LOOP;
END$$;

-- Check and remove any triggers on shift_area_cover_porter_assignments
DO $$
DECLARE
  trigger_name text;
BEGIN
  FOR trigger_name IN (
    SELECT trigger_name FROM information_schema.triggers 
    WHERE event_object_table = 'shift_area_cover_porter_assignments'
  )
  LOOP
    EXECUTE 'DROP TRIGGER IF EXISTS ' || trigger_name || ' ON shift_area_cover_porter_assignments';
  END LOOP;
END$$;

-- Check and remove any triggers on shift_support_service_assignments
DO $$
DECLARE
  trigger_name text;
BEGIN
  FOR trigger_name IN (
    SELECT trigger_name FROM information_schema.triggers 
    WHERE event_object_table = 'shift_support_service_assignments'
  )
  LOOP
    EXECUTE 'DROP TRIGGER IF EXISTS ' || trigger_name || ' ON shift_support_service_assignments';
  END LOOP;
END$$;

-- Check and remove any triggers on shift_support_service_porter_assignments
DO $$
DECLARE
  trigger_name text;
BEGIN
  FOR trigger_name IN (
    SELECT trigger_name FROM information_schema.triggers 
    WHERE event_object_table = 'shift_support_service_porter_assignments'
  )
  LOOP
    EXECUTE 'DROP TRIGGER IF EXISTS ' || trigger_name || ' ON shift_support_service_porter_assignments';
  END LOOP;
END$$;

-- Confirm that all tables exist with proper constraints
DO $$
BEGIN
  -- Check if shift_area_cover_assignments table exists with proper constraint
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'shift_area_cover_assignments_shift_id_department_id_key'
      AND table_name = 'shift_area_cover_assignments'
  ) THEN
    -- Add the constraint if it doesn't exist
    ALTER TABLE shift_area_cover_assignments 
    ADD CONSTRAINT shift_area_cover_assignments_shift_id_department_id_key 
    UNIQUE (shift_id, department_id);
  END IF;

  -- Check if shift_support_service_assignments table exists with proper constraint
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'shift_support_service_assignments_shift_id_service_id_key'
      AND table_name = 'shift_support_service_assignments'
  ) THEN
    -- Add the constraint if it doesn't exist
    ALTER TABLE shift_support_service_assignments 
    ADD CONSTRAINT shift_support_service_assignments_shift_id_service_id_key 
    UNIQUE (shift_id, service_id);
  END IF;
END$$;
