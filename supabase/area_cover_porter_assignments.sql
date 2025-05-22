-- Create area_cover_porter_assignments table for multiple porter assignments per department
CREATE TABLE IF NOT EXISTS area_cover_porter_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  area_cover_assignment_id UUID NOT NULL REFERENCES area_cover_assignments(id) ON DELETE CASCADE,
  porter_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(area_cover_assignment_id, porter_id)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS area_cover_porter_assignments_area_cover_id_idx 
  ON area_cover_porter_assignments(area_cover_assignment_id);
  
CREATE INDEX IF NOT EXISTS area_cover_porter_assignments_porter_id_idx 
  ON area_cover_porter_assignments(porter_id);

-- Create trigger for updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_area_cover_porter_assignments_updated_at'
  ) THEN
    CREATE TRIGGER update_area_cover_porter_assignments_updated_at
    BEFORE UPDATE ON area_cover_porter_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
  END IF;
END
$$;

-- Add sample data
INSERT INTO area_cover_porter_assignments 
  (area_cover_assignment_id, porter_id, start_time, end_time)
VALUES
  -- Day assignments
  ('b560c26d-710d-46bb-b8ec-29a3f47857fe', 'f45a46c3-2240-462f-9895-494965ecd1a8', '08:00:00', '12:00:00'),
  
  -- Night assignments (sample data to be added later)
  -- ('da7c9105-d530-4b40-b3db-1e7a73145b70', 'f45a46c3-2240-462f-9895-494965ecd1a8', '20:00:00', '00:00:00')
  
ON CONFLICT (area_cover_assignment_id, porter_id) DO NOTHING;
