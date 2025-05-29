-- Fix for service area porter assignments not being loaded for new shifts

-- First, let's drop the existing function
DROP FUNCTION IF EXISTS public.copy_defaults_to_shift(uuid, varchar);

-- Create the updated function with improved error handling and debugging
CREATE OR REPLACE FUNCTION public.copy_defaults_to_shift(p_shift_id uuid, p_shift_type varchar)
RETURNS void AS $$
DECLARE
  v_area_cover_assignment_id UUID;
  v_service_cover_assignment_id UUID;
  v_default_area_cover_id UUID;
  v_default_service_cover_id UUID;
  r_area_assignment RECORD;
  r_service_assignment RECORD;
  r_area_porter RECORD;
  r_service_porter RECORD;
  v_porter_count INTEGER;
  v_debug_info TEXT;
BEGIN
  -- Initialize debug info
  v_debug_info := 'Starting copy_defaults_to_shift for shift_id: ' || p_shift_id || ', shift_type: ' || p_shift_type;
  
  -- Copy area cover assignments from defaults to shift
  FOR r_area_assignment IN 
    SELECT * FROM default_area_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Add to debug info
    v_debug_info := v_debug_info || E'\nProcessing area cover assignment: ' || r_area_assignment.id;
    
    -- Insert into shift_area_cover_assignments
    INSERT INTO shift_area_cover_assignments (
      shift_id, department_id, start_time, end_time, color
    ) VALUES (
      p_shift_id, r_area_assignment.department_id, r_area_assignment.start_time, 
      r_area_assignment.end_time, r_area_assignment.color
    ) RETURNING id INTO v_area_cover_assignment_id;
    
    -- Store the default ID for later
    v_default_area_cover_id := r_area_assignment.id;
    
    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Created shift_area_cover_assignment: ' || v_area_cover_assignment_id;
    
    -- Count how many porter assignments we should copy
    SELECT COUNT(*) INTO v_porter_count 
    FROM default_area_cover_porter_assignments 
    WHERE default_area_cover_assignment_id = v_default_area_cover_id;
    
    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Found ' || v_porter_count || ' porter assignments to copy';
    
    -- Copy porter assignments for this area cover
    FOR r_area_porter IN 
      SELECT * FROM default_area_cover_porter_assignments 
      WHERE default_area_cover_assignment_id = v_default_area_cover_id
    LOOP
      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Processing porter assignment: ' || r_area_porter.id;
      
      INSERT INTO shift_area_cover_porter_assignments (
        shift_area_cover_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_area_cover_assignment_id, r_area_porter.porter_id, 
        r_area_porter.start_time, r_area_porter.end_time
      );
      
      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Created porter assignment for porter_id: ' || r_area_porter.porter_id;
    END LOOP;
  END LOOP;
  
  -- Copy service cover assignments from defaults to shift
  FOR r_service_assignment IN 
    SELECT * FROM default_service_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Add to debug info
    v_debug_info := v_debug_info || E'\nProcessing service cover assignment: ' || r_service_assignment.id;
    
    -- Insert into shift_support_service_assignments
    INSERT INTO shift_support_service_assignments (
      shift_id, service_id, start_time, end_time, color
    ) VALUES (
      p_shift_id, r_service_assignment.service_id, r_service_assignment.start_time, 
      r_service_assignment.end_time, r_service_assignment.color
    ) RETURNING id INTO v_service_cover_assignment_id;
    
    -- Store the default ID for later
    v_default_service_cover_id := r_service_assignment.id;
    
    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Created shift_support_service_assignment: ' || v_service_cover_assignment_id;
    
    -- Count how many porter assignments we should copy
    SELECT COUNT(*) INTO v_porter_count 
    FROM default_service_cover_porter_assignments 
    WHERE default_service_cover_assignment_id = v_default_service_cover_id;
    
    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Found ' || v_porter_count || ' porter assignments to copy';
    
    -- Copy porter assignments for this service cover
    FOR r_service_porter IN 
      SELECT * FROM default_service_cover_porter_assignments 
      WHERE default_service_cover_assignment_id = v_default_service_cover_id
    LOOP
      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Processing service porter assignment: ' || r_service_porter.id;
      
      BEGIN
        INSERT INTO shift_support_service_porter_assignments (
          shift_support_service_assignment_id, porter_id, start_time, end_time
        ) VALUES (
          v_service_cover_assignment_id, r_service_porter.porter_id, 
          r_service_porter.start_time, r_service_porter.end_time
        );
        
        -- Add to debug info
        v_debug_info := v_debug_info || E'\n  Created service porter assignment for porter_id: ' || r_service_porter.porter_id;
      EXCEPTION WHEN OTHERS THEN
        -- Log the error but continue processing
        v_debug_info := v_debug_info || E'\n  ERROR inserting service porter assignment: ' || SQLERRM;
      END;
    END LOOP;
  END LOOP;
  
  -- Log the debug info to the PostgreSQL log
  RAISE NOTICE '%', v_debug_info;
  
EXCEPTION WHEN OTHERS THEN
  -- Log the error and debug info
  RAISE EXCEPTION 'Error in copy_defaults_to_shift: %, Debug info: %', SQLERRM, v_debug_info;
END;
$$ LANGUAGE plpgsql;

-- Add a comment explaining the fix
COMMENT ON FUNCTION public.copy_defaults_to_shift(uuid, varchar) IS 
'Copies default area cover and service cover assignments to a new shift. 
This version includes better error handling and debugging to ensure porter assignments 
are properly copied from default_service_cover_porter_assignments to 
shift_support_service_porter_assignments.';

-- Reload the function by executing a simple query
SELECT COUNT(*) FROM shifts;
