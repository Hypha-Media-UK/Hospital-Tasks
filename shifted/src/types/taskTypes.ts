export interface TaskType {
  id: string
  name: string
  created_at?: string
  updated_at?: string
}

export interface TaskItem {
  id: string
  task_type_id: string
  name: string
  is_regular: boolean
  created_at?: string
  updated_at?: string
}

export interface TaskTypeAssignment {
  id: string
  task_type_id: string
  department_id: string
  is_origin: boolean
  is_destination: boolean
  created_at?: string
  updated_at?: string
}

export interface TaskItemAssignment {
  id: string
  task_item_id: string
  department_id: string
  is_origin: boolean
  is_destination: boolean
  created_at?: string
  updated_at?: string
}

export interface TaskTypeWithItems extends TaskType {
  items: TaskItem[]
}

export interface DepartmentAssignmentData {
  department_id: string
  is_origin: boolean
  is_destination: boolean
}

export interface AssignmentModalProps {
  taskTypeId?: string
  taskItemId?: string
  title: string
}
