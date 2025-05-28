-- Add sort_order field to buildings table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'buildings' AND column_name = 'sort_order') THEN
        ALTER TABLE buildings ADD COLUMN sort_order INTEGER DEFAULT 0;
    END IF;
END $$;

-- Add sort_order field to departments table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'departments' AND column_name = 'sort_order') THEN
        ALTER TABLE departments ADD COLUMN sort_order INTEGER DEFAULT 0;
    END IF;
END $$;

-- Set initial sort_order values based on row number
UPDATE buildings 
SET sort_order = sub.rn * 10
FROM (
    SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) as rn 
    FROM buildings
) sub
WHERE buildings.id = sub.id AND buildings.sort_order = 0;

UPDATE departments 
SET sort_order = sub.rn * 10
FROM (
    SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) as rn 
    FROM departments
) sub
WHERE departments.id = sub.id AND departments.sort_order = 0;

-- Create an index on buildings sort_order for faster queries
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'buildings_sort_order_idx') THEN
        CREATE INDEX buildings_sort_order_idx ON buildings(sort_order);
    END IF;
END $$;

-- Create an index on departments sort_order for faster queries
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'departments_sort_order_idx') THEN
        CREATE INDEX departments_sort_order_idx ON departments(sort_order);
    END IF;
END $$;

-- Also create an index on departments.is_frequent for faster querying of frequent departments
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'departments_is_frequent_idx') THEN
        CREATE INDEX departments_is_frequent_idx ON departments(is_frequent);
    END IF;
END $$;
