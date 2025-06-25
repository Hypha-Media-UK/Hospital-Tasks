-- Add is_supervisor column to shift_porter_pool table
ALTER TABLE shift_porter_pool 
ADD COLUMN is_supervisor BOOLEAN DEFAULT FALSE;

-- Add index for better performance when querying supervisors
CREATE INDEX idx_shift_porter_pool_supervisor ON shift_porter_pool(shift_id, is_supervisor);

-- Add comment to document the column
COMMENT ON COLUMN shift_porter_pool.is_supervisor IS 'Indicates if this porter entry represents the shift supervisor';
