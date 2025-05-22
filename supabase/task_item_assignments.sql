-- Create task_item_department_assignments table for task item assignments
CREATE TABLE task_item_department_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_item_id UUID NOT NULL REFERENCES task_items(id) ON DELETE CASCADE,
  department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  is_origin BOOLEAN DEFAULT FALSE,
  is_destination BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(task_item_id, department_id)
);

-- Create indexes for faster queries
CREATE INDEX task_item_dept_assign_task_item_id_idx ON task_item_department_assignments(task_item_id);
CREATE INDEX task_item_dept_assign_dept_id_idx ON task_item_department_assignments(department_id);
