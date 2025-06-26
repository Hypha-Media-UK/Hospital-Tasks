-- Add shift_date column to shifts table
-- This column will store the date the shift is for (separate from when it was created)

ALTER TABLE shifts ADD COLUMN shift_date DATE;

-- Update existing shifts to have a shift_date based on their start_time
UPDATE shifts 
SET shift_date = DATE(start_time AT TIME ZONE 'UTC');

-- Make the column NOT NULL after populating it
ALTER TABLE shifts ALTER COLUMN shift_date SET NOT NULL;

-- Add an index for better performance
CREATE INDEX idx_shifts_shift_date ON shifts(shift_date);

-- Add a comment to explain the column
COMMENT ON COLUMN shifts.shift_date IS 'The date this shift is scheduled for (YYYY-MM-DD format)';
