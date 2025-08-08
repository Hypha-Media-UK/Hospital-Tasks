#!/usr/bin/env python3

"""
PostgreSQL to MySQL Data Extraction Script
Extracts INSERT statements from PostgreSQL dump and converts to MySQL format
"""

import re
import sys
import os

def main():
    pg_dump_path = 'supabase/hospital-20250705-1431.sql'
    output_path = 'mysql-data.sql'
    
    print('🔄 Starting PostgreSQL to MySQL data extraction...')
    
    if not os.path.exists(pg_dump_path):
        print(f'❌ Error: {pg_dump_path} not found!')
        sys.exit(1)
    
    with open(pg_dump_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract all INSERT statements
    insert_pattern = r'INSERT INTO "public"\."([^"]+)" \([^)]+\) VALUES\s*(.*?);'
    matches = re.findall(insert_pattern, content, re.DOTALL)
    
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
    
    # Group INSERT statements by table
    table_data = {}
    for table_name, values_section in matches:
        if table_name not in table_data:
            table_data[table_name] = []
        table_data[table_name].append(values_section)
    
    # Start building output
    output_lines = [
        '-- ============================================================================',
        '-- Hospital Tasks - MySQL Data Import', 
        '-- Converted from PostgreSQL dump',
        '-- ============================================================================',
        '',
        'USE hospital_tasks;',
        '',
        '-- Disable foreign key checks for data import',
        'SET FOREIGN_KEY_CHECKS = 0;',
        ''
    ]
    
    # Process tables in dependency order
    total_records = 0
    processed_tables = 0
    
    for table_name in table_order:
        if table_name in table_data:
            print(f'📝 Processing table: {table_name}')
            
            # Get column definition from original INSERT
            column_pattern = f'INSERT INTO "public"."{table_name}" \\(([^)]+)\\)'
            column_match = re.search(column_pattern, content)
            
            if column_match:
                columns = column_match.group(1)
                # Clean column names - remove quotes
                columns = columns.replace('"', '')
                
                output_lines.append(f'-- Data for table: {table_name}')
                output_lines.append(f'DELETE FROM {table_name};')
                
                # Combine all VALUES sections for this table
                all_values = []
                for values_section in table_data[table_name]:
                    # Clean up the values section
                    cleaned_values = clean_values_section(values_section, table_name)
                    all_values.extend(cleaned_values)
                
                if all_values:
                    output_lines.append(f'INSERT INTO {table_name} ({columns}) VALUES')
                    
                    # Join values with commas
                    values_str = ',\n'.join(all_values) + ';'
                    output_lines.append(values_str)
                    
                    total_records += len(all_values)
                
                output_lines.append('')
                processed_tables += 1
    
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
    
    print(f'✅ Data extraction completed!')
    print(f'📁 Output file: {output_path}')
    print(f'📊 Processed {processed_tables} tables')
    print(f'📝 Total records: {total_records}')
    
    print('\n📋 Table Summary:')
    for table_name in table_order:
        if table_name in table_data:
            record_count = sum(len(clean_values_section(vs, table_name)) for vs in table_data[table_name])
            print(f'   {table_name}: {record_count} records')
    
    print('\n🔧 Next steps:')
    print('1. Review mysql-data.sql for any conversion issues')
    print('2. Import schema: mysql -u root -p hospital_tasks < mysql-schema.sql')
    print('3. Import data: mysql -u root -p hospital_tasks < mysql-data.sql')

def clean_values_section(values_section, table_name):
    """Clean and parse VALUES section from PostgreSQL format"""
    
    # Remove PostgreSQL-specific type casts
    values_section = re.sub(r'::[a-zA-Z_ ]+', '', values_section)
    
    # Handle timezone timestamps - remove +00 timezone
    values_section = re.sub(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?)\+00', r'\1', values_section)
    
    # Split into individual value tuples
    # This is a simplified approach - look for patterns like (...),
    values = []
    
    # Find all complete parenthetical groups
    paren_pattern = r'\([^)]*\)'
    matches = re.findall(paren_pattern, values_section, re.DOTALL)
    
    for match in matches:
        # Clean up the match
        cleaned = match.strip()
        if cleaned and cleaned != '()':
            values.append(cleaned)
    
    return values

if __name__ == '__main__':
    main()
