-- Create tables for default area cover and service cover assignments
-- These will be used as templates for new shifts but won't be affected by changes to shift-specific assignments

-- Create default_area_cover_assignments table
CREATE TABLE IF NOT EXISTS default_area_cover_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  shift_type TEXT NOT NULL CHECK (shift_type IN ('week_day', 'week_night', 'weekend_day', 'weekend_night')),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  color TEXT NOT NULL DEFAULT '#4285F4',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(department_id, shift_type)
);

-- Create default_area_cover_porter_assignments table
CREATE TABLE IF NOT EXISTS default_area_cover_porter_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  default_area_cover_assignment_id UUID NOT NULL REFERENCES default_area_cover_assignments(id) ON DELETE CASCADE,
  porter_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create default_service_cover_assignments table
CREATE TABLE IF NOT EXISTS default_service_cover_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  service_id UUID NOT NULL REFERENCES support_services(id) ON DELETE CASCADE,
  shift_type TEXT NOT NULL CHECK (shift_type IN ('week_day', 'week_night', 'weekend_day', 'weekend_night')),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  color TEXT NOT NULL DEFAULT '#4285F4',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(service_id, shift_type)
);

-- Create default_service_cover_porter_assignments table
CREATE TABLE IF NOT EXISTS default_service_cover_porter_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  default_service_cover_assignment_id UUID NOT NULL REFERENCES default_service_cover_assignments(id) ON DELETE CASCADE,
  porter_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add function to copy default assignments to new shifts
CREATE OR REPLACE FUNCTION copy_default_assignments_to_shift()
RETURNS TRIGGER AS $$
DECLARE
  new_area_cover_id UUID;
  new_service_cover_id UUID;
  area_assignment RECORD;
  area_porter_assignment RECORD;
  service_assignment RECORD;
  service_porter_assignment RECORD;
BEGIN
  -- Copy default area cover assignments for this shift type
  FOR area_assignment IN 
    SELECT * FROM default_area_cover_assignments 
    WHERE shift_type = NEW.shift_type
  LOOP
    -- Insert area cover assignment for this shift
    INSERT INTO shift_area_cover_assignments (
      shift_id, 
      department_id, 
      start_time, 
      end_time, 
      color
    ) VALUES (
      NEW.id, 
      area_assignment.department_id, 
      area_assignment.start_time, 
      area_assignment.end_time, 
      area_assignment.color
    ) RETURNING id INTO new_area_cover_id;
    
    -- Copy porter assignments for this area cover
    FOR area_porter_assignment IN 
      SELECT * FROM default_area_cover_porter_assignments 
      WHERE default_area_cover_assignment_id = area_assignment.id
    LOOP
      INSERT INTO shift_area_cover_porter_assignments (
        shift_area_cover_assignment_id, 
        porter_id, 
        start_time, 
        end_time
      ) VALUES (
        new_area_cover_id, 
        area_porter_assignment.porter_id, 
        area_porter_assignment.start_time, 
        area_porter_assignment.end_time
      );
    END LOOP;
  END LOOP;
  
  -- Copy default service cover assignments for this shift type
  FOR service_assignment IN 
    SELECT * FROM default_service_cover_assignments 
    WHERE shift_type = NEW.shift_type
  LOOP
    -- Insert service cover assignment for this shift
    INSERT INTO shift_support_service_assignments (
      shift_id, 
      service_id, 
      start_time, 
      end_time, 
      color
    ) VALUES (
      NEW.id, 
      service_assignment.service_id, 
      service_assignment.start_time, 
      service_assignment.end_time, 
      service_assignment.color
    ) RETURNING id INTO new_service_cover_id;
    
    -- Copy porter assignments for this service cover
    FOR service_porter_assignment IN 
      SELECT * FROM default_service_cover_porter_assignments 
      WHERE default_service_cover_assignment_id = service_assignment.id
    LOOP
      INSERT INTO shift_support_service_porter_assignments (
        shift_support_service_assignment_id, 
        porter_id, 
        start_time, 
        end_time
      ) VALUES (
        new_service_cover_id, 
        service_porter_assignment.porter_id, 
        service_porter_assignment.start_time, 
        service_porter_assignment.end_time
      );
    END LOOP;
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to call function when a new shift is created
DROP TRIGGER IF EXISTS trigger_copy_default_assignments ON shifts;
CREATE TRIGGER trigger_copy_default_assignments
AFTER INSERT ON shifts
FOR EACH ROW
EXECUTE FUNCTION copy_default_assignments_to_shift();

-- Migration: Copy existing assignments from area_cover_assignments to default_area_cover_assignments
INSERT INTO default_area_cover_assignments (
  department_id, 
  shift_type, 
  start_time, 
  end_time, 
  color
)
SELECT DISTINCT ON (department_id, shift_type)
  department_id, 
  shift_type, 
  start_time, 
  end_time, 
  color
FROM area_cover_assignments
ON CONFLICT (department_id, shift_type) DO UPDATE 
SET 
  start_time = EXCLUDED.start_time,
  end_time = EXCLUDED.end_time,
  color = EXCLUDED.color,
  updated_at = now();

-- Copy porter assignments for area cover
INSERT INTO default_area_cover_porter_assignments (
  default_area_cover_assignment_id,
  porter_id,
  start_time,
  end_time
)
SELECT 
  daca.id,
  apa.porter_id,
  apa.start_time,
  apa.end_time
FROM area_cover_porter_assignments apa
JOIN area_cover_assignments aca ON apa.area_cover_assignment_id = aca.id
JOIN default_area_cover_assignments daca ON 
  daca.department_id = aca.department_id AND 
  daca.shift_type = aca.shift_type;

-- Migration: Copy existing assignments from support_service_assignments to default_service_cover_assignments
INSERT INTO default_service_cover_assignments (
  service_id, 
  shift_type, 
  start_time, 
  end_time, 
  color
)
SELECT DISTINCT ON (service_id, shift_type)
  service_id, 
  shift_type, 
  start_time, 
  end_time, 
  color
FROM support_service_assignments
ON CONFLICT (service_id, shift_type) DO UPDATE 
SET 
  start_time = EXCLUDED.start_time,
  end_time = EXCLUDED.end_time,
  color = EXCLUDED.color,
  updated_at = now();

-- Copy porter assignments for service cover
INSERT INTO default_service_cover_porter_assignments (
  default_service_cover_assignment_id,
  porter_id,
  start_time,
  end_time
)
SELECT 
  dsca.id,
  spa.porter_id,
  spa.start_time,
  spa.end_time
FROM support_service_porter_assignments spa
JOIN support_service_assignments ssa ON spa.support_service_assignment_id = ssa.id
JOIN default_service_cover_assignments dsca ON 
  dsca.service_id = ssa.service_id AND 
  dsca.shift_type = ssa.shift_type;
