-- Remove timezone and time_format columns from app_settings table
-- This migration removes the timezone functionality that has been replaced with browser-based timezone detection

-- Check if timezone column exists before attempting to drop it
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'app_settings' 
     AND COLUMN_NAME = 'timezone') > 0,
    'ALTER TABLE app_settings DROP COLUMN timezone',
    'SELECT "timezone column does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Check if time_format column exists before attempting to drop it
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = 'app_settings' 
     AND COLUMN_NAME = 'time_format') > 0,
    'ALTER TABLE app_settings DROP COLUMN time_format',
    'SELECT "time_format column does not exist" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add a comment to document this change (MySQL syntax)
ALTER TABLE app_settings COMMENT = 'Application settings table. Timezone functionality removed in favor of browser-based timezone detection with 24-hour format.';
