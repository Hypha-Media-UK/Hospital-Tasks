-- Apply the missing migration for shift_porter_building_assignments table
-- This should be run in the Supabase SQL Editor

-- Create table for shift porter building assignments
CREATE TABLE IF NOT EXISTS shift_porter_building_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
    porter_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique assignment per porter per shift per building
    UNIQUE(shift_id, porter_id, building_id)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_shift_porter_building_assignments_shift_id ON shift_porter_building_assignments(shift_id);
CREATE INDEX IF NOT EXISTS idx_shift_porter_building_assignments_porter_id ON shift_porter_building_assignments(porter_id);
CREATE INDEX IF NOT EXISTS idx_shift_porter_building_assignments_building_id ON shift_porter_building_assignments(building_id);

-- Add RLS policies
ALTER TABLE shift_porter_building_assignments ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists and recreate
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON shift_porter_building_assignments;

-- Policy to allow all operations for authenticated users
CREATE POLICY "Allow all operations for authenticated users" ON shift_porter_building_assignments
    FOR ALL USING (auth.role() = 'authenticated');

-- Add trigger for updated_at
CREATE OR REPLACE TRIGGER update_shift_porter_building_assignments_updated_at
    BEFORE UPDATE ON shift_porter_building_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Verify the table was created
SELECT 'shift_porter_building_assignments table created successfully' AS status;
