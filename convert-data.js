#!/usr/bin/env node

/**
 * PostgreSQL to MySQL Data Conversion Script
 * Converts data from supabase/hospital-20250705-1431.sql to MySQL format
 */

const fs = require('fs');
const path = require('path');

// Read the PostgreSQL dump file
const pgDumpPath = 'supabase/hospital-20250705-1431.sql';
const outputPath = 'mysql-data.sql';

console.log('Starting PostgreSQL to MySQL data conversion...');

if (!fs.existsSync(pgDumpPath)) {
    console.error(`Error: ${pgDumpPath} not found!`);
    process.exit(1);
}

const pgDump = fs.readFileSync(pgDumpPath, 'utf8');

// Extract INSERT statements
const insertRegex = /INSERT INTO "public"\."([^"]+)" \([^)]+\) VALUES\s*([\s\S]*?);/g;
let mysqlData = [];

// Add header
mysqlData.push('-- ============================================================================');
mysqlData.push('-- Hospital Tasks - MySQL Data Import');
mysqlData.push('-- Converted from PostgreSQL dump');
mysqlData.push('-- ============================================================================');
mysqlData.push('');
mysqlData.push('USE hospital_tasks;');
mysqlData.push('');
mysqlData.push('-- Disable foreign key checks for data import');
mysqlData.push('SET FOREIGN_KEY_CHECKS = 0;');
mysqlData.push('');

// Table processing order (to handle foreign key dependencies)
const tableOrder = [
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
];

// Store all INSERT statements by table
const tableInserts = {};

let match;
while ((match = insertRegex.exec(pgDump)) !== null) {
    const tableName = match[1];
    const valuesSection = match[2];
    
    if (!tableInserts[tableName]) {
        tableInserts[tableName] = [];
    }
    
    // Parse the VALUES section
    const values = parseValues(valuesSection);
    tableInserts[tableName].push(...values);
}

// Function to parse VALUES section
function parseValues(valuesSection) {
    const values = [];
    const lines = valuesSection.split('\n');
    let currentValue = '';
    let inParens = false;
    let parenCount = 0;
    
    for (let line of lines) {
        line = line.trim();
        if (!line) continue;
        
        for (let char of line) {
            if (char === '(') {
                parenCount++;
                if (parenCount === 1) {
                    inParens = true;
                    currentValue = '(';
                } else {
                    currentValue += char;
                }
            } else if (char === ')') {
                parenCount--;
                currentValue += char;
                if (parenCount === 0) {
                    inParens = false;
                    // Check if this is the end of a value (followed by comma or end)
                    const remaining = line.substring(line.indexOf(char) + 1).trim();
                    if (remaining === '' || remaining.startsWith(',')) {
                        values.push(currentValue);
                        currentValue = '';
                    }
                }
            } else if (inParens) {
                currentValue += char;
            }
        }
    }
    
    return values;
}

// Function to convert PostgreSQL value to MySQL
function convertValue(value, tableName) {
    // Remove PostgreSQL-specific syntax
    value = value.replace(/::text/g, '');
    value = value.replace(/::character varying/g, '');
    value = value.replace(/::timestamp with time zone/g, '');
    value = value.replace(/::time without time zone/g, '');
    value = value.replace(/::date/g, '');
    value = value.replace(/::boolean/g, '');
    value = value.replace(/::integer/g, '');
    
    // Handle timezone timestamps - convert to UTC
    value = value.replace(/(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?)\+00/g, '$1');
    
    // Fix the supervisor issue - set is_supervisor to true for supervisors in shift_porter_pool
    if (tableName === 'shift_porter_pool') {
        // This is a temporary fix - we'll need to identify supervisors properly
        // For now, we'll fix this in the API layer
    }
    
    return value;
}

// Process tables in dependency order
for (const tableName of tableOrder) {
    if (tableInserts[tableName]) {
        mysqlData.push(`-- Data for table: ${tableName}`);
        mysqlData.push(`DELETE FROM ${tableName};`);
        
        const values = tableInserts[tableName];
        if (values.length > 0) {
            // Get column names from the original INSERT
            const insertMatch = pgDump.match(new RegExp(`INSERT INTO "public"\\."${tableName}" \\(([^)]+)\\)`, 'i'));
            if (insertMatch) {
                let columns = insertMatch[1];
                // Clean up column names - remove quotes and schema references
                columns = columns.replace(/"/g, '');
                
                mysqlData.push(`INSERT INTO ${tableName} (${columns}) VALUES`);
                
                // Convert and add values
                const convertedValues = values.map(value => convertValue(value, tableName));
                mysqlData.push(convertedValues.join(',\n') + ';');
            }
        }
        mysqlData.push('');
    }
}

// Re-enable foreign key checks
mysqlData.push('-- Re-enable foreign key checks');
mysqlData.push('SET FOREIGN_KEY_CHECKS = 1;');
mysqlData.push('');

// Fix supervisor issue with UPDATE statement
mysqlData.push('-- Fix supervisor issue in shift_porter_pool');
mysqlData.push('-- Update porter pool entries to mark supervisors correctly');
mysqlData.push(`UPDATE shift_porter_pool spp 
JOIN shifts s ON spp.shift_id = s.id 
SET spp.is_supervisor = TRUE 
WHERE spp.porter_id = s.supervisor_id;`);
mysqlData.push('');

mysqlData.push('-- Data conversion completed');

// Write the output file
fs.writeFileSync(outputPath, mysqlData.join('\n'));

console.log(`✅ Data conversion completed!`);
console.log(`📁 Output file: ${outputPath}`);
console.log(`📊 Processed ${Object.keys(tableInserts).length} tables`);
console.log(`📝 Total INSERT statements: ${Object.values(tableInserts).reduce((sum, arr) => sum + arr.length, 0)}`);

// Show table summary
console.log('\n📋 Table Summary:');
for (const tableName of tableOrder) {
    if (tableInserts[tableName]) {
        console.log(`   ${tableName}: ${tableInserts[tableName].length} records`);
    }
}

console.log('\n🔧 Next steps:');
console.log('1. Review mysql-data.sql for any conversion issues');
console.log('2. Import schema: mysql -u root -p hospital_tasks < mysql-schema.sql');
console.log('3. Import data: mysql -u root -p hospital_tasks < mysql-data.sql');
