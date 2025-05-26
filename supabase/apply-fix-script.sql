-- First, check if the database tables exist, create them if they don't

-- Create default_area_cover_assignments table if it doesn't exist
CREATE TABLE IF NOT EXISTS default_area_cover_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  shift_type TEXT NOT NULL CHECK (shift_type IN ('week_day', 'week_night', 'weekend_day', 'weekend_night')),
  start_time TIME NOT NULL DEFAULT '08:00:00',
  end_time TIME NOT NULL DEFAULT '16:00:00',
  color TEXT DEFAULT '#4285F4',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(department_id, shift_type)
);

-- Create default_area_cover_porter_assignments table if it doesn't exist
CREATE TABLE IF NOT EXISTS default_area_cover_porter_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  default_area_cover_assignment_id UUID NOT NULL REFERENCES default_area_cover_assignments(id) ON DELETE CASCADE,
  porter_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  start_time TIME NOT NULL DEFAULT '08:00:00',
  end_time TIME NOT NULL DEFAULT '16:00:00',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create default_service_cover_assignments table if it doesn't exist
CREATE TABLE IF NOT EXISTS default_service_cover_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  service_id UUID NOT NULL REFERENCES support_services(id) ON DELETE CASCADE,
  shift_type TEXT NOT NULL CHECK (shift_type IN ('week_day', 'week_night', 'weekend_day', 'weekend_night')),
  start_time TIME NOT NULL DEFAULT '08:00:00',
  end_time TIME NOT NULL DEFAULT '16:00:00',
  color TEXT DEFAULT '#4285F4',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(service_id, shift_type)
);

-- Create default_service_cover_porter_assignments table if it doesn't exist
CREATE TABLE IF NOT EXISTS default_service_cover_porter_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  default_service_cover_assignment_id UUID NOT NULL REFERENCES default_service_cover_assignments(id) ON DELETE CASCADE,
  porter_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  start_time TIME NOT NULL DEFAULT '08:00:00',
  end_time TIME NOT NULL DEFAULT '16:00:00',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create or replace the function to copy defaults when creating new shifts
CREATE OR REPLACE FUNCTION copy_defaults_to_shift(p_shift_id UUID, p_shift_type VARCHAR)
RETURNS VOID AS $$
DECLARE
  v_area_cover_assignment_id UUID;
  v_service_cover_assignment_id UUID;
  v_default_area_cover_id UUID;
  v_default_service_cover_id UUID;
  v_porter_id UUID;
  v_start_time TIME;
  v_end_time TIME;
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

-- Create trigger function to call copy_defaults_to_shift
CREATE OR REPLACE FUNCTION copy_defaults_on_shift_creation()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM copy_defaults_to_shift(NEW.id, NEW.shift_type);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger if it doesn't exist
DROP TRIGGER IF EXISTS copy_defaults_on_shift_creation ON shifts;
CREATE TRIGGER copy_defaults_on_shift_creation
AFTER INSERT ON shifts
FOR EACH ROW
EXECUTE FUNCTION copy_defaults_on_shift_creation();
