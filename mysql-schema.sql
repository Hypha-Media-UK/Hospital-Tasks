-- ============================================================================
-- Hospital Tasks - MySQL Schema Conversion
-- Converted from PostgreSQL to MySQL 8.0
-- ============================================================================

-- Set MySQL specific settings
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';
SET time_zone = '+00:00';

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS hospital_tasks CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE hospital_tasks;

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- App Settings Table
CREATE TABLE app_settings (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    time_format VARCHAR(10) NOT NULL DEFAULT '24h',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Buildings Table
CREATE TABLE buildings (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL,
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    sort_order INT DEFAULT 0,
    porter_serviced BOOLEAN DEFAULT TRUE,
    abbreviation VARCHAR(10)
);

-- Departments Table
CREATE TABLE departments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    building_id CHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,
    is_frequent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    sort_order INT DEFAULT 0,
    color VARCHAR(20) DEFAULT '#CCCCCC',
    FOREIGN KEY (building_id) REFERENCES buildings(id) ON DELETE CASCADE
);

-- Staff Table (Supervisors and Porters)
CREATE TABLE staff (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    role ENUM('supervisor', 'porter') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    department_id CHAR(36),
    porter_type VARCHAR(50) DEFAULT 'shift',
    availability_pattern VARCHAR(100),
    contracted_hours_start TIME,
    contracted_hours_end TIME,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL,
    CONSTRAINT check_porter_type CHECK (porter_type IN ('shift', 'relief') OR porter_type IS NULL)
);

-- Shifts Table
CREATE TABLE shifts (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    supervisor_id CHAR(36) NOT NULL,
    shift_type VARCHAR(50) NOT NULL,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    shift_date DATE NOT NULL,
    FOREIGN KEY (supervisor_id) REFERENCES staff(id) ON DELETE CASCADE,
    CONSTRAINT shifts_shift_type_check CHECK (shift_type IN ('week_day', 'week_night', 'weekend_day', 'weekend_night'))
);

-- Shift Porter Pool (Porter assignments to shifts)
CREATE TABLE shift_porter_pool (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    shift_id CHAR(36) NOT NULL,
    porter_id CHAR(36) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_supervisor BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
    FOREIGN KEY (porter_id) REFERENCES staff(id) ON DELETE CASCADE,
    UNIQUE KEY unique_shift_porter (shift_id, porter_id)
);

-- Shift Defaults Table
CREATE TABLE shift_defaults (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    shift_type VARCHAR(50) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    color VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================================================
-- TASK MANAGEMENT TABLES
-- ============================================================================

-- Task Types Table
CREATE TABLE task_types (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Task Items Table
CREATE TABLE task_items (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    task_type_id CHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_regular BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (task_type_id) REFERENCES task_types(id) ON DELETE CASCADE
);

-- Shift Tasks Table
CREATE TABLE shift_tasks (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    shift_id CHAR(36) NOT NULL,
    task_item_id CHAR(36) NOT NULL,
    porter_id CHAR(36),
    origin_department_id CHAR(36),
    destination_department_id CHAR(36),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    time_received VARCHAR(50) DEFAULT '00:00',
    time_allocated VARCHAR(50) DEFAULT '00:01',
    time_completed VARCHAR(50) DEFAULT '00:20',
    FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
    FOREIGN KEY (task_item_id) REFERENCES task_items(id) ON DELETE CASCADE,
    FOREIGN KEY (porter_id) REFERENCES staff(id) ON DELETE SET NULL,
    FOREIGN KEY (origin_department_id) REFERENCES departments(id) ON DELETE SET NULL,
    FOREIGN KEY (destination_department_id) REFERENCES departments(id) ON DELETE SET NULL,
    CONSTRAINT shift_tasks_status_check CHECK (status IN ('pending', 'completed'))
);

-- Task Type Department Assignments
CREATE TABLE task_type_department_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    task_type_id CHAR(36) NOT NULL,
    department_id CHAR(36) NOT NULL,
    is_origin BOOLEAN DEFAULT FALSE,
    is_destination BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (task_type_id) REFERENCES task_types(id) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
);

-- Task Item Department Assignments
CREATE TABLE task_item_department_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    task_item_id CHAR(36) NOT NULL,
    department_id CHAR(36) NOT NULL,
    is_origin BOOLEAN DEFAULT FALSE,
    is_destination BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (task_item_id) REFERENCES task_items(id) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
);

-- Department Task Assignments
CREATE TABLE department_task_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    department_id CHAR(36) NOT NULL,
    task_type_id CHAR(36) NOT NULL,
    task_item_id CHAR(36) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
    FOREIGN KEY (task_type_id) REFERENCES task_types(id) ON DELETE CASCADE,
    FOREIGN KEY (task_item_id) REFERENCES task_items(id) ON DELETE CASCADE
);

-- ============================================================================
-- ABSENCE MANAGEMENT TABLES
-- ============================================================================

-- Porter Absences (Global absences)
CREATE TABLE porter_absences (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    porter_id CHAR(36) NOT NULL,
    absence_type VARCHAR(50) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (porter_id) REFERENCES staff(id) ON DELETE CASCADE
);

-- Shift Porter Absences (Shift-specific absences)
CREATE TABLE shift_porter_absences (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    shift_id CHAR(36) NOT NULL,
    porter_id CHAR(36) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    absence_reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
    FOREIGN KEY (porter_id) REFERENCES staff(id) ON DELETE CASCADE
);

-- Staff Department Assignments
CREATE TABLE staff_department_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    staff_id CHAR(36) NOT NULL,
    department_id CHAR(36) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
);

-- Shift Porter Building Assignments
CREATE TABLE shift_porter_building_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    shift_id CHAR(36) NOT NULL,
    porter_id CHAR(36) NOT NULL,
    building_id CHAR(36) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
    FOREIGN KEY (porter_id) REFERENCES staff(id) ON DELETE CASCADE,
    FOREIGN KEY (building_id) REFERENCES buildings(id) ON DELETE CASCADE
);

-- ============================================================================
-- SUPPORT SERVICES TABLES
-- ============================================================================

-- Support Services Table
CREATE TABLE support_services (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Default Service Cover Assignments
CREATE TABLE default_service_cover_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    service_id CHAR(36) NOT NULL,
    shift_type VARCHAR(50) NOT NULL,
    start_time TIME DEFAULT '08:00:00',
    end_time TIME DEFAULT '16:00:00',
    color VARCHAR(20) DEFAULT '#4285F4',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    minimum_porters INT DEFAULT 1,
    minimum_porters_mon INT DEFAULT 1,
    minimum_porters_tue INT DEFAULT 1,
    minimum_porters_wed INT DEFAULT 1,
    minimum_porters_thu INT DEFAULT 1,
    minimum_porters_fri INT DEFAULT 1,
    minimum_porters_sat INT DEFAULT 1,
    minimum_porters_sun INT DEFAULT 1,
    FOREIGN KEY (service_id) REFERENCES support_services(id) ON DELETE CASCADE,
    UNIQUE KEY unique_service_shift_type (service_id, shift_type)
);

-- Default Service Cover Porter Assignments
CREATE TABLE default_service_cover_porter_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    default_service_cover_assignment_id CHAR(36) NOT NULL,
    porter_id CHAR(36) NOT NULL,
    start_time TIME DEFAULT '08:00:00',
    end_time TIME DEFAULT '16:00:00',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (default_service_cover_assignment_id) REFERENCES default_service_cover_assignments(id) ON DELETE CASCADE,
    FOREIGN KEY (porter_id) REFERENCES staff(id) ON DELETE CASCADE
);

-- Support Service Assignments
CREATE TABLE support_service_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    service_id CHAR(36) NOT NULL,
    start_time TIME DEFAULT '08:00:00',
    end_time TIME DEFAULT '16:00:00',
    color VARCHAR(20) DEFAULT '#4285F4',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    shift_type VARCHAR(50) NOT NULL,
    FOREIGN KEY (service_id) REFERENCES support_services(id) ON DELETE CASCADE
);

-- Support Service Porter Assignments
CREATE TABLE support_service_porter_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    support_service_assignment_id CHAR(36) NOT NULL,
    porter_id CHAR(36) NOT NULL,
    start_time TIME DEFAULT '08:00:00',
    end_time TIME DEFAULT '16:00:00',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (support_service_assignment_id) REFERENCES support_service_assignments(id) ON DELETE CASCADE,
    FOREIGN KEY (porter_id) REFERENCES staff(id) ON DELETE CASCADE
);

-- Shift Support Service Assignments
CREATE TABLE shift_support_service_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    shift_id CHAR(36) NOT NULL,
    service_id CHAR(36) NOT NULL,
    start_time TIME DEFAULT '08:00:00',
    end_time TIME DEFAULT '16:00:00',
    color VARCHAR(20) DEFAULT '#4285F4',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    minimum_porters INT DEFAULT 1,
    minimum_porters_mon INT DEFAULT 1,
    minimum_porters_tue INT DEFAULT 1,
    minimum_porters_wed INT DEFAULT 1,
    minimum_porters_thu INT DEFAULT 1,
    minimum_porters_fri INT DEFAULT 1,
    minimum_porters_sat INT DEFAULT 1,
    minimum_porters_sun INT DEFAULT 1,
    FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES support_services(id) ON DELETE CASCADE,
    UNIQUE KEY unique_shift_service (shift_id, service_id)
);

-- Shift Support Service Porter Assignments
CREATE TABLE shift_support_service_porter_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    shift_support_service_assignment_id CHAR(36) NOT NULL,
    porter_id CHAR(36) NOT NULL,
    start_time TIME DEFAULT '08:00:00',
    end_time TIME DEFAULT '16:00:00',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    agreed_absence VARCHAR(255),
    FOREIGN KEY (shift_support_service_assignment_id) REFERENCES shift_support_service_assignments(id) ON DELETE CASCADE,
    FOREIGN KEY (porter_id) REFERENCES staff(id) ON DELETE CASCADE
);

-- ============================================================================
-- AREA COVERAGE TABLES
-- ============================================================================

-- Default Area Cover Assignments
CREATE TABLE default_area_cover_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    department_id CHAR(36) NOT NULL,
    shift_type VARCHAR(50) NOT NULL,
    start_time TIME DEFAULT '08:00:00',
    end_time TIME DEFAULT '16:00:00',
    color VARCHAR(20) DEFAULT '#4285F4',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    minimum_porters INT DEFAULT 1,
    minimum_porters_mon INT DEFAULT 1,
    minimum_porters_tue INT DEFAULT 1,
    minimum_porters_wed INT DEFAULT 1,
    minimum_porters_thu INT DEFAULT 1,
    minimum_porters_fri INT DEFAULT 1,
    minimum_porters_sat INT DEFAULT 1,
    minimum_porters_sun INT DEFAULT 1,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
    UNIQUE KEY unique_department_shift_type (department_id, shift_type)
);

-- Default Area Cover Porter Assignments
CREATE TABLE default_area_cover_porter_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    default_area_cover_assignment_id CHAR(36) NOT NULL,
    porter_id CHAR(36) NOT NULL,
    start_time TIME DEFAULT '08:00:00',
    end_time TIME DEFAULT '16:00:00',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (default_area_cover_assignment_id) REFERENCES default_area_cover_assignments(id) ON DELETE CASCADE,
    FOREIGN KEY (porter_id) REFERENCES staff(id) ON DELETE CASCADE
);

-- Shift Area Cover Assignments
CREATE TABLE shift_area_cover_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    shift_id CHAR(36) NOT NULL,
    department_id CHAR(36) NOT NULL,
    start_time TIME DEFAULT '08:00:00',
    end_time TIME DEFAULT '16:00:00',
    color VARCHAR(20) DEFAULT '#4285F4',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    minimum_porters INT DEFAULT 1,
    minimum_porters_mon INT DEFAULT 1,
    minimum_porters_tue INT DEFAULT 1,
    minimum_porters_wed INT DEFAULT 1,
    minimum_porters_thu INT DEFAULT 1,
    minimum_porters_fri INT DEFAULT 1,
    minimum_porters_sat INT DEFAULT 1,
    minimum_porters_sun INT DEFAULT 1,
    FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
    UNIQUE KEY unique_shift_department (shift_id, department_id)
);

-- Shift Area Cover Porter Assignments
CREATE TABLE shift_area_cover_porter_assignments (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    shift_area_cover_assignment_id CHAR(36) NOT NULL,
    porter_id CHAR(36) NOT NULL,
    start_time TIME DEFAULT '08:00:00',
    end_time TIME DEFAULT '16:00:00',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    agreed_absence VARCHAR(255),
    FOREIGN KEY (shift_area_cover_assignment_id) REFERENCES shift_area_cover_assignments(id) ON DELETE CASCADE,
    FOREIGN KEY (porter_id) REFERENCES staff(id) ON DELETE CASCADE,
    UNIQUE KEY unique_area_cover_porter (shift_area_cover_assignment_id, porter_id)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Core table indexes
CREATE INDEX idx_departments_building_id ON departments(building_id);
CREATE INDEX idx_staff_role ON staff(role);
CREATE INDEX idx_staff_department_id ON staff(department_id);
CREATE INDEX idx_shifts_supervisor_id ON shifts(supervisor_id);
CREATE INDEX idx_shifts_shift_date ON shifts(shift_date);
CREATE INDEX idx_shifts_is_active ON shifts(is_active);
CREATE INDEX idx_shift_porter_pool_shift_id ON shift_porter_pool(shift_id);
CREATE INDEX idx_shift_porter_pool_porter_id ON shift_porter_pool(porter_id);
CREATE INDEX idx_shift_porter_pool_is_supervisor ON shift_porter_pool(is_supervisor);

-- Task management indexes
CREATE INDEX idx_task_items_task_type_id ON task_items(task_type_id);
CREATE INDEX idx_shift_tasks_shift_id ON shift_tasks(shift_id);
CREATE INDEX idx_shift_tasks_porter_id ON shift_tasks(porter_id);
CREATE INDEX idx_shift_tasks_status ON shift_tasks(status);
CREATE INDEX idx_shift_tasks_origin_dept ON shift_tasks(origin_department_id);
CREATE INDEX idx_shift_tasks_dest_dept ON shift_tasks(destination_department_id);

-- Absence management indexes
CREATE INDEX idx_porter_absences_porter_id ON porter_absences(porter_id);
CREATE INDEX idx_porter_absences_dates ON porter_absences(start_date, end_date);
CREATE INDEX idx_shift_porter_absences_shift_id ON shift_porter_absences(shift_id);
CREATE INDEX idx_shift_porter_absences_porter_id ON shift_porter_absences(porter_id);

-- Area coverage indexes
CREATE INDEX idx_shift_area_cover_shift_id ON shift_area_cover_assignments(shift_id);
CREATE INDEX idx_shift_area_cover_dept_id ON shift_area_cover_assignments(department_id);
CREATE INDEX idx_shift_area_porter_assignment_id ON shift_area_cover_porter_assignments(shift_area_cover_assignment_id);

-- Support service indexes
CREATE INDEX idx_shift_support_service_shift_id ON shift_support_service_assignments(shift_id);
CREATE INDEX idx_shift_support_service_service_id ON shift_support_service_assignments(service_id);
CREATE INDEX idx_shift_support_porter_assignment_id ON shift_support_service_porter_assignments(shift_support_service_assignment_id);
