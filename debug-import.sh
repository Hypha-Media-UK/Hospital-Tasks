#!/bin/bash

# ============================================================================
# Debug Import Script - Hospital Tasks
# ============================================================================

echo "🔍 Debug Import - Hospital Tasks Database"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Step 1: Check DDEV status
print_status "Checking DDEV status..."
if ! ddev describe >/dev/null 2>&1; then
    print_error "DDEV is not running. Please run 'ddev start' first."
    exit 1
fi
print_success "DDEV is running"

# Step 2: Check file existence
print_status "Checking required files..."

if [ ! -f "mysql-schema.sql" ]; then
    print_error "mysql-schema.sql not found!"
    exit 1
fi
print_success "mysql-schema.sql found ($(du -h mysql-schema.sql | cut -f1))"

if [ ! -f "mysql-data-fixed.sql" ]; then
    print_warning "mysql-data-fixed.sql not found, checking for mysql-data.sql..."
    if [ ! -f "mysql-data.sql" ]; then
        print_error "No data file found!"
        exit 1
    else
        print_warning "Using mysql-data.sql instead"
        DATA_FILE="mysql-data.sql"
    fi
else
    print_success "mysql-data-fixed.sql found ($(du -h mysql-data-fixed.sql | cut -f1))"
    DATA_FILE="mysql-data-fixed.sql"
fi

# Step 3: Check current database state
print_status "Checking current database state..."
CURRENT_DB_EXISTS=$(ddev mysql -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'hospital_tasks';" -s -N)

if [ "$CURRENT_DB_EXISTS" = "hospital_tasks" ]; then
    print_warning "hospital_tasks database already exists"
    CURRENT_TABLES=$(ddev mysql -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'hospital_tasks';" -s -N)
    print_status "Current table count: $CURRENT_TABLES"
else
    print_status "hospital_tasks database does not exist"
fi

# Step 4: Test schema file syntax
print_status "Testing schema file syntax..."
if ddev mysql --execute="SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';" 2>/dev/null; then
    print_success "MySQL connection working"
else
    print_error "MySQL connection failed"
    exit 1
fi

# Step 5: Create fresh database
print_status "Creating fresh database..."
ddev mysql -e "DROP DATABASE IF EXISTS hospital_tasks; CREATE DATABASE hospital_tasks CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>&1

if [ $? -eq 0 ]; then
    print_success "Database created successfully"
else
    print_error "Database creation failed"
    exit 1
fi

# Step 6: Import schema with error checking
print_status "Importing schema with detailed error checking..."
SCHEMA_OUTPUT=$(ddev mysql hospital_tasks < mysql-schema.sql 2>&1)
SCHEMA_EXIT_CODE=$?

if [ $SCHEMA_EXIT_CODE -eq 0 ]; then
    print_success "Schema imported successfully"
else
    print_error "Schema import failed with exit code: $SCHEMA_EXIT_CODE"
    echo "Error output:"
    echo "$SCHEMA_OUTPUT"
    exit 1
fi

# Step 7: Verify schema import
print_status "Verifying schema import..."
TABLE_COUNT=$(ddev mysql -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'hospital_tasks';" -s -N)
print_status "Tables created: $TABLE_COUNT"

if [ "$TABLE_COUNT" -eq "0" ]; then
    print_error "No tables were created!"
    print_status "Checking for any objects in the database..."
    ddev mysql -e "USE hospital_tasks; SHOW TABLES;"
    exit 1
elif [ "$TABLE_COUNT" -lt "28" ]; then
    print_warning "Expected 28 tables, but only $TABLE_COUNT were created"
    print_status "Tables that were created:"
    ddev mysql -e "USE hospital_tasks; SHOW TABLES;"
else
    print_success "All $TABLE_COUNT tables created successfully"
fi

# Step 8: Import data with error checking
print_status "Importing data from $DATA_FILE..."
DATA_OUTPUT=$(ddev mysql hospital_tasks < "$DATA_FILE" 2>&1)
DATA_EXIT_CODE=$?

if [ $DATA_EXIT_CODE -eq 0 ]; then
    print_success "Data imported successfully"
else
    print_error "Data import failed with exit code: $DATA_EXIT_CODE"
    echo "Error output:"
    echo "$DATA_OUTPUT"
    
    # Show the problematic line if possible
    if echo "$DATA_OUTPUT" | grep -q "at line"; then
        LINE_NUM=$(echo "$DATA_OUTPUT" | grep -o "at line [0-9]*" | grep -o "[0-9]*")
        print_status "Error at line $LINE_NUM in $DATA_FILE:"
        sed -n "${LINE_NUM}p" "$DATA_FILE"
    fi
    exit 1
fi

# Step 9: Verify data import
print_status "Verifying data import..."
STAFF_COUNT=$(ddev mysql -e "SELECT COUNT(*) FROM hospital_tasks.staff;" -s -N 2>/dev/null || echo "0")
SHIFTS_COUNT=$(ddev mysql -e "SELECT COUNT(*) FROM hospital_tasks.shifts;" -s -N 2>/dev/null || echo "0")
SUPERVISOR_COUNT=$(ddev mysql -e "SELECT COUNT(*) FROM hospital_tasks.shift_porter_pool WHERE is_supervisor = TRUE;" -s -N 2>/dev/null || echo "0")

print_success "Data verification complete:"
echo "   📊 Tables: $TABLE_COUNT"
echo "   👥 Staff: $STAFF_COUNT"
echo "   📋 Shifts: $SHIFTS_COUNT"
echo "   👨‍💼 Supervisors in porter pool: $SUPERVISOR_COUNT"

if [ "$SUPERVISOR_COUNT" -gt "0" ]; then
    print_success "Supervisor issue has been fixed!"
else
    print_warning "Supervisor issue may still exist"
fi

# Step 10: Show sample data
print_status "Sample data from key tables:"
echo ""
echo "Buildings:"
ddev mysql -e "SELECT name, abbreviation FROM hospital_tasks.buildings LIMIT 3;" 2>/dev/null || echo "No building data"

echo ""
echo "Staff (first 3):"
ddev mysql -e "SELECT first_name, last_name, role FROM hospital_tasks.staff LIMIT 3;" 2>/dev/null || echo "No staff data"

echo ""
echo "Shifts (first 2):"
ddev mysql -e "SELECT id, shift_type, shift_date FROM hospital_tasks.shifts LIMIT 2;" 2>/dev/null || echo "No shift data"

echo ""
print_success "🎉 Debug import completed!"
echo ""
echo "🚀 If everything looks good, you can now:"
echo "   1. Start API: ddev exec 'cd api && npm run dev'"
echo "   2. Start frontend: ddev exec 'npm run dev'"
echo "   3. Visit: https://hospital-tasks.ddev.site"
