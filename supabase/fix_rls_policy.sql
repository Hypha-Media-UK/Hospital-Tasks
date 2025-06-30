-- Fix RLS policy for shift_porter_building_assignments table
-- This should be run in the Supabase SQL Editor

-- Drop the existing policy
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON shift_porter_building_assignments;

-- Create a more permissive policy that works with your authentication setup
CREATE POLICY "Enable all operations for authenticated users" ON shift_porter_building_assignments
    FOR ALL 
    TO authenticated 
    USING (true) 
    WITH CHECK (true);

-- Alternative: If the above doesn't work, try this more basic policy
-- DROP POLICY IF EXISTS "Enable all operations for authenticated users" ON shift_porter_building_assignments;
-- CREATE POLICY "Allow all access" ON shift_porter_building_assignments
--     FOR ALL 
--     USING (true) 
--     WITH CHECK (true);

-- Verify the policy was created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'shift_porter_building_assignments';
