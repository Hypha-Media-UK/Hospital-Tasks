#!/usr/bin/env python3

"""
Improved PostgreSQL to MySQL Data Extraction Script
Handles complex data parsing more reliably
"""

import re
import sys
import os

def main():
    pg_dump_path = 'supabase/hospital-20250705-1431.sql'
    output_path = 'mysql-data-fixed.sql'
    
    print('🔄 Starting improved PostgreSQL to MySQL data extraction...')
    
    if not os.path.exists(pg_dump_path):
        print(f'❌ Error: {pg_dump_path} not found!')
        sys.exit(1)
    
    with open(pg_dump_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Table processing order (respecting foreign key dependencies)
    table_order = [
        'app_settings',
        'buildings', 
        'departments',
        'staff',
        'shifts',
        'shift_defaults',
        'task_types',
        'task_items',
        'support_services',
        'default_area_cover_assignments',
        'default_area_cover_porter_assignments', 
        'default_service_cover_assignments',
        'default_service_cover_porter_assignments',
        'support_service_assignments',
        'support_service_porter_assignments',
        'shift_porter_pool',
        'shift_area_cover_assignments',
        'shift_area_cover_porter_assignments',
        'shift_support_service_assignments', 
        'shift_support_service_porter_assignments',
        'shift_tasks',
        'task_type_department_assignments',
        'task_item_department_assignments',
        'department_task_assignments',
        'porter_absences',
        'shift_porter_absences',
        'staff_department_assignments',
        'shift_porter_building_assignments'
    ]
    
    # Start building output
    output_lines = [
        '-- ============================================================================',
        '-- Hospital Tasks - MySQL Data Import (Fixed)', 
        '-- Converted from PostgreSQL dump with improved parsing',
        '-- ============================================================================',
        '',
        'USE hospital_tasks;',
        '',
        '-- Disable foreign key checks for data import',
        'SET FOREIGN_KEY_CHECKS = 0;',
        ''
    ]
    
    # Process each table
    total_records = 0
    processed_tables = 0
    
    for table_name in table_order:
        print(f'📝 Processing table: {table_name}')
        
        # Find the INSERT statement for this table
        insert_pattern = f'INSERT INTO "public"."{table_name}" \\([^)]+\\) VALUES\\s*([^;]+);'
        match = re.search(insert_pattern, content, re.DOTALL)
        
        if match:
            # Get column definition
            column_pattern = f'INSERT INTO "public"."{table_name}" \\(([^)]+)\\)'
            column_match = re.search(column_pattern, content)
            
            if column_match:
                columns = column_match.group(1)
                # Clean column names - remove quotes
                columns = columns.replace('"', '')
                
                # Get the VALUES section
                values_section = match.group(1).strip()
                
                # Parse values more carefully
                parsed_values = parse_values_carefully(values_section)
                
                if parsed_values:
                    output_lines.append(f'-- Data for table: {table_name}')
                    output_lines.append(f'DELETE FROM {table_name};')
                    output_lines.append(f'INSERT INTO {table_name} ({columns}) VALUES')
                    
                    # Clean and join values
                    cleaned_values = []
                    for value in parsed_values:
                        cleaned_value = clean_value(value, table_name)
                        if cleaned_value:
                            cleaned_values.append(cleaned_value)
                    
                    if cleaned_values:
                        output_lines.append(',\n'.join(cleaned_values) + ';')
                        total_records += len(cleaned_values)
                        print(f'   ✅ {len(cleaned_values)} records processed')
                    
                    output_lines.append('')
                    processed_tables += 1
                else:
                    print(f'   ⚠️  No valid data found for {table_name}')
        else:
            print(f'   ⚠️  No INSERT statement found for {table_name}')
    
    # Add supervisor fix
    output_lines.extend([
        '-- Fix supervisor issue in shift_porter_pool',
        '-- Update porter pool entries to mark supervisors correctly',
        'UPDATE shift_porter_pool spp',
        'JOIN shifts s ON spp.shift_id = s.id', 
        'SET spp.is_supervisor = TRUE',
        'WHERE spp.porter_id = s.supervisor_id;',
        '',
        '-- Re-enable foreign key checks',
        'SET FOREIGN_KEY_CHECKS = 1;',
        '',
        '-- Data import completed'
    ])
    
    # Write output file
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(output_lines))
    
    print(f'✅ Improved data extraction completed!')
    print(f'📁 Output file: {output_path}')
    print(f'📊 Processed {processed_tables} tables')
    print(f'📝 Total records: {total_records}')

def parse_values_carefully(values_section):
    """Parse VALUES section more carefully to handle complex data"""
    values = []
    current_value = ""
    paren_count = 0
    in_string = False
    escape_next = False
    quote_char = None
    
    i = 0
    while i < len(values_section):
        char = values_section[i]
        
        if escape_next:
            current_value += char
            escape_next = False
        elif char == '\\':
            current_value += char
            escape_next = True
        elif char in ("'", '"') and not in_string:
            in_string = True
            quote_char = char
            current_value += char
        elif char == quote_char and in_string:
            in_string = False
            quote_char = None
            current_value += char
        elif char == '(' and not in_string:
            paren_count += 1
            current_value += char
        elif char == ')' and not in_string:
            paren_count -= 1
            current_value += char
            
            if paren_count == 0:
                # End of a complete value tuple
                value = current_value.strip()
                if value and value != '()':
                    values.append(value)
                current_value = ""
                
                # Skip comma and whitespace
                i += 1
                while i < len(values_section) and values_section[i] in ', \n\t':
                    i += 1
                i -= 1  # Adjust for the increment at the end of the loop
        else:
            current_value += char
        
        i += 1
    
    return values

def clean_value(value, table_name):
    """Clean and convert PostgreSQL value to MySQL format"""
    if not value or value.strip() == '()':
        return None
    
    # Remove PostgreSQL-specific type casts
    value = re.sub(r'::[a-zA-Z_\s]+', '', value)
    
    # Handle timezone timestamps - remove +00 timezone
    value = re.sub(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?)\+00', r'\1', value)
    
    # Handle NULL values properly
    value = re.sub(r'\bNULL\b', 'NULL', value)
    
    # Ensure proper string escaping
    # This is a basic approach - for production, use proper SQL escaping
    
    return value.strip()

if __name__ == '__main__':
    main()
