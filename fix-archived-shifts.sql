-- DIAGNOSIS: Check the current state of shifts in the database
SELECT COUNT(*) as total_shifts, 
       SUM(CASE WHEN is_active = true THEN 1 ELSE 0 END) as active_shifts,
       SUM(CASE WHEN is_active = false THEN 1 ELSE 0 END) as archived_shifts
FROM shifts;

-- DIAGNOSIS: Verify if there are any archived shifts in the database
SELECT id, shift_type, start_time, end_time, is_active, supervisor_id
FROM shifts 
WHERE is_active = false 
LIMIT 5;

-- DIAGNOSIS: Check if there's an issue with the supervisor join
SELECT 
    s.id, s.shift_type, s.is_active,
    s.supervisor_id,
    staff.id as actual_staff_id,
    staff.first_name, staff.last_name
FROM 
    shifts s
LEFT JOIN 
    staff ON s.supervisor_id = staff.id
WHERE 
    s.is_active = false
LIMIT 10;

-- FIXES: Database optimization for better query performance
ANALYZE shifts;
ANALYZE staff;

-- FIXES: Ensure proper indexing for better query performance
DROP INDEX IF EXISTS idx_shifts_is_active;
CREATE INDEX IF NOT EXISTS idx_shifts_is_active ON shifts(is_active);

DROP INDEX IF EXISTS idx_shifts_supervisor_id;
CREATE INDEX IF NOT EXISTS idx_shifts_supervisor_id ON shifts(supervisor_id);

-- FIXES: Fix any archived shifts that have NULL end_time values 
-- (this would prevent them from showing up in ORDER BY end_time queries)
UPDATE shifts
SET end_time = start_time + interval '8 hours'
WHERE is_active = false AND end_time IS NULL;

-- FIXES: Fix any potential records with wrong is_active status
-- Shifts with end_time should be marked as inactive
UPDATE shifts
SET is_active = false
WHERE end_time IS NOT NULL AND is_active = true;

-- DIAGNOSIS: Verify the query that should match what the application is using
SELECT 
    s.*,
    sup.id as supervisor_id,
    sup.first_name as supervisor_first_name,
    sup.last_name as supervisor_last_name,
    sup.role as supervisor_role
FROM 
    shifts s
LEFT JOIN 
    staff sup ON s.supervisor_id = sup.id
WHERE 
    s.is_active = false
ORDER BY 
    s.end_time DESC
LIMIT 20;

-- FINAL VERIFICATION: Check if archived shifts are now available
SELECT COUNT(*) as archived_shifts_count
FROM shifts
WHERE is_active = false;
