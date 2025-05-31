-- Add minimum_porters column to default_area_cover_assignments
ALTER TABLE default_area_cover_assignments
ADD COLUMN minimum_porters INTEGER DEFAULT 1;

-- Add minimum_porters column to default_service_cover_assignments  
ALTER TABLE default_service_cover_assignments
ADD COLUMN minimum_porters INTEGER DEFAULT 1;
