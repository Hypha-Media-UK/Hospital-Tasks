-- Seed data for buildings
INSERT INTO buildings (id, name, address) VALUES
('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Main Hospital', '123 Medical Drive'),
('f47ac10b-58cc-4372-a567-0e02b2c3d480', 'East Wing', '125 Medical Drive'),
('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Research Center', '200 Science Boulevard');

-- Seed data for departments
INSERT INTO departments (id, building_id, name, is_frequent) VALUES
('f47ac10b-58cc-4372-a567-0e02b2c3d482', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Emergency', true),
('f47ac10b-58cc-4372-a567-0e02b2c3d483', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Radiology', false),
('f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'ICU', true),
('f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d480', 'Cardiology', false),
('f47ac10b-58cc-4372-a567-0e02b2c3d486', 'f47ac10b-58cc-4372-a567-0e02b2c3d480', 'Neurology', false),
('f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Clinical Trials', false),
('f47ac10b-58cc-4372-a567-0e02b2c3d488', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Laboratories', true);
