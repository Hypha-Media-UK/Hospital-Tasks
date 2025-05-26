-- Cleanup and fix triggers script
-- This script resolves the 409 Conflict error when creating shifts
-- and ensures proper separation between default settings and shift-specific assignments

-- 1. First, drop all existing triggers on the shifts table
DROP TRIGGER IF EXISTS trigger_copy_default_assignments ON shifts;
DROP TRIGGER IF EXISTS copy_defaults_on_shift_creation ON shifts;
DROP TRIGGER IF EXISTS copy_defaults_to_new_shift ON shifts;

-- 2. Drop redundant functions that are no longer needed
DROP FUNCTION IF EXISTS copy_default_assignments_to_shift();

-- 3. Keep only the most complete implementation
-- We'll use copy_defaults_to_shift() as our main function
-- It properly handles copying from default tables to shift-specific tables

-- 4. We won't create a trigger here yet - we'll create it properly in step 8
-- after defining the proper trigger function

-- 5. Clean up any possible orphaned assignments in area_cover_assignments and support_service_assignments
-- that are not linked to any shift but might still affect defaults

-- First, let's ensure all default assignments are properly migrated to the default tables
-- Area cover assignments migration (if not already done)
INSERT INTO default_area_cover_assignments 
  (department_id, shift_type, start_time, end_time, color)
SELECT DISTINCT ON (department_id, shift_type)
  department_id, 
  shift_type, 
  start_time, 
  end_time, 
  color
FROM area_cover_assignments
WHERE shift_type IS NOT NULL
ON CONFLICT (department_id, shift_type) DO UPDATE 
SET 
  start_time = EXCLUDED.start_time,
  end_time = EXCLUDED.end_time,
  color = EXCLUDED.color,
  updated_at = now();

-- Porter assignments migration
INSERT INTO default_area_cover_porter_assignments 
  (default_area_cover_assignment_id, porter_id, start_time, end_time)
SELECT 
  daca.id,
  apa.porter_id,
  apa.start_time,
  apa.end_time
FROM area_cover_porter_assignments apa
JOIN area_cover_assignments aca ON apa.area_cover_assignment_id = aca.id
JOIN default_area_cover_assignments daca ON 
  daca.department_id = aca.department_id AND 
  daca.shift_type = aca.shift_type
WHERE aca.shift_type IS NOT NULL
ON CONFLICT DO NOTHING;

-- Support service assignments migration
INSERT INTO default_service_cover_assignments 
  (service_id, shift_type, start_time, end_time, color)
SELECT DISTINCT ON (service_id, shift_type)
  service_id, 
  shift_type, 
  start_time, 
  end_time, 
  color
FROM support_service_assignments
WHERE shift_type IS NOT NULL
ON CONFLICT (service_id, shift_type) DO UPDATE 
SET 
  start_time = EXCLUDED.start_time,
  end_time = EXCLUDED.end_time,
  color = EXCLUDED.color,
  updated_at = now();

-- Support service porter assignments migration
INSERT INTO default_service_cover_porter_assignments 
  (default_service_cover_assignment_id, porter_id, start_time, end_time)
SELECT 
  dsca.id,
  spa.porter_id,
  spa.start_time,
  spa.end_time
FROM support_service_porter_assignments spa
JOIN support_service_assignments ssa ON spa.support_service_assignment_id = ssa.id
JOIN default_service_cover_assignments dsca ON 
  dsca.service_id = ssa.service_id AND 
  dsca.shift_type = ssa.shift_type
WHERE ssa.shift_type IS NOT NULL
ON CONFLICT DO NOTHING;

-- 6. Update the copy_defaults_to_shift function to ensure it's properly defined
-- This function should take two parameters: the shift ID and shift type

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

-- 7. Create a new copy_defaults_on_shift_creation function
-- This is a wrapper function that matches the expected signature for the trigger
CREATE OR REPLACE FUNCTION copy_defaults_on_shift_creation()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM copy_defaults_to_shift(NEW.id, NEW.shift_type);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Create a single trigger that uses the wrapper function
DROP TRIGGER IF EXISTS copy_defaults_to_new_shift ON shifts;
CREATE TRIGGER copy_defaults_to_new_shift
AFTER INSERT ON shifts
FOR EACH ROW
EXECUTE FUNCTION copy_defaults_on_shift_creation();

-- 9. Verify all necessary tables exist and have the correct structure
DO $$
BEGIN
  -- Check if shift_area_cover_assignments table exists
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'shift_area_cover_assignments') THEN
    CREATE TABLE shift_area_cover_assignments (
      id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
      shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
      department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
      start_time TIME NOT NULL,
      end_time TIME NOT NULL,
      color TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
      UNIQUE(shift_id, department_id)
    );
  END IF;

  -- Check if shift_area_cover_porter_assignments table exists
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'shift_area_cover_porter_assignments') THEN
    CREATE TABLE shift_area_cover_porter_assignments (
      id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
      shift_area_cover_assignment_id UUID NOT NULL REFERENCES shift_area_cover_assignments(id) ON DELETE CASCADE,
      porter_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
      start_time TIME NOT NULL,
      end_time TIME NOT NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
      UNIQUE(shift_area_cover_assignment_id, porter_id)
    );
  END IF;

  -- Check if shift_support_service_assignments table exists
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'shift_support_service_assignments') THEN
    CREATE TABLE shift_support_service_assignments (
      id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
      shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
      service_id UUID NOT NULL REFERENCES support_services(id) ON DELETE CASCADE,
      start_time TIME NOT NULL,
      end_time TIME NOT NULL,
      color TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
      UNIQUE(shift_id, service_id)
    );
  END IF;

  -- Check if shift_support_service_porter_assignments table exists
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'shift_support_service_porter_assignments') THEN
    CREATE TABLE shift_support_service_porter_assignments (
      id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
      shift_support_service_assignment_id UUID NOT NULL REFERENCES shift_support_service_assignments(id) ON DELETE CASCADE,
      porter_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
      start_time TIME NOT NULL,
      end_time TIME NOT NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
      UNIQUE(shift_support_service_assignment_id, porter_id)
    );
  END IF;
END$$;
