-- Add porter_serviced column to buildings table
-- This indicates which buildings require porter service

ALTER TABLE buildings 
ADD COLUMN porter_serviced BOOLEAN DEFAULT false;

-- Add abbreviation column for building short names (2 characters max)
ALTER TABLE buildings 
ADD COLUMN abbreviation VARCHAR(2);

-- Add comments for documentation
COMMENT ON COLUMN buildings.porter_serviced IS 'Indicates whether this building requires porter service';
COMMENT ON COLUMN buildings.abbreviation IS 'Two-character abbreviation for building display on porter cards';
