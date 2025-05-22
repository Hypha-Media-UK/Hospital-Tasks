-- Add department_id column to the staff table
ALTER TABLE staff 
ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id) ON DELETE SET NULL;

-- Create index for faster queries on department_id
CREATE INDEX IF NOT EXISTS staff_department_id_idx ON staff(department_id);

-- Make sure the role enum type exists (if not already)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_role') THEN
        CREATE TYPE staff_role AS ENUM ('supervisor', 'porter');
    END IF;
END$$;

-- Make sure the updated_at trigger exists
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for staff table if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_trigger 
        WHERE tgname = 'update_staff_updated_at'
    ) THEN
        CREATE TRIGGER update_staff_updated_at
        BEFORE UPDATE ON staff
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END$$;

-- Add sample staff data if not exists
INSERT INTO staff (first_name, last_name, role)
VALUES 
  ('John', 'Smith', 'supervisor'),
  ('Michael', 'Johnson', 'porter')
ON CONFLICT (id) DO NOTHING;
