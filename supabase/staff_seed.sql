-- Clear existing staff data if needed
-- TRUNCATE TABLE staff RESTART IDENTITY CASCADE;

-- Add sample staff data
INSERT INTO staff (first_name, last_name, role)
VALUES 
  ('John', 'Smith', 'supervisor'),
  ('Sarah', 'Johnson', 'supervisor'),
  ('Michael', 'Johnson', 'porter'),
  ('Emma', 'Williams', 'porter'),
  ('David', 'Brown', 'porter')
ON CONFLICT (id) DO NOTHING;

-- Assign departments to some staff members
UPDATE staff SET department_id = (
  SELECT id FROM departments 
  WHERE name = 'Cardiologyies' 
  LIMIT 1
)
WHERE first_name = 'Michael' AND last_name = 'Johnson';

UPDATE staff SET department_id = (
  SELECT id FROM departments 
  WHERE name = 'Neurology' 
  LIMIT 1
)
WHERE first_name = 'Sarah' AND last_name = 'Johnson';
