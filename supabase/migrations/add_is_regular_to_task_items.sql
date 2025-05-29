-- Add is_regular column to task_items table
ALTER TABLE task_items
ADD COLUMN is_regular BOOLEAN DEFAULT FALSE;
