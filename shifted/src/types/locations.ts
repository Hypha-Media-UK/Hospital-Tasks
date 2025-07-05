export interface Building {
  id: string
  name: string
  sort_order: number
  porter_serviced?: boolean
  created_at?: string
  updated_at?: string
}

export interface Department {
  id: string
  building_id: string
  name: string
  is_frequent: boolean
  sort_order: number
  created_at?: string
  updated_at?: string
}

export interface DepartmentTaskAssignment {
  id: string
  department_id: string
  task_type_id: string
  task_item_id: string
  created_at?: string
  updated_at?: string
}

export interface BuildingWithDepartments extends Building {
  departments: Department[]
}
