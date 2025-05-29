-- Add availability fields to staff table
ALTER TABLE staff 
ADD COLUMN IF NOT EXISTS availability_pattern VARCHAR(50),
ADD COLUMN IF NOT EXISTS contracted_hours_start TIME,
ADD COLUMN IF NOT EXISTS contracted_hours_end TIME;
