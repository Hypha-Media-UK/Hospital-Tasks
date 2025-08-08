#!/bin/bash

# ============================================================================
# Quick Fix - Import Fixed Data
# ============================================================================

set -e

echo "🔧 Importing Fixed Data to MySQL"
echo "================================"

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

# Check if DDEV is running
if ! ddev describe >/dev/null 2>&1; then
    print_error "DDEV is not running. Please start DDEV first with 'ddev start'"
    exit 1
fi

# Check if fixed data file exists
if [ ! -f "mysql-data-fixed.sql" ]; then
    print_error "Fixed data file not found. Running data extraction..."
    python3 fix-data-extraction.py
    if [ $? -ne 0 ]; then
        print_error "Data extraction failed"
        exit 1
    fi
fi

# Reset database with schema
print_status "Resetting database with fresh schema..."
ddev mysql -e "DROP DATABASE IF EXISTS hospital_tasks; CREATE DATABASE hospital_tasks CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

print_status "Importing schema..."
ddev mysql hospital_tasks < mysql-schema.sql

if [ $? -eq 0 ]; then
    print_success "Schema imported successfully"
else
    print_error "Schema import failed"
    exit 1
fi

# Import fixed data
print_status "Importing fixed data..."
ddev mysql hospital_tasks < mysql-data-fixed.sql

if [ $? -eq 0 ]; then
    print_success "Fixed data imported successfully!"
else
    print_error "Data import failed"
    exit 1
fi

# Verify data
print_status "Verifying data import..."
TABLE_COUNT=$(ddev mysql hospital_tasks -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'hospital_tasks';" -s -N)
RECORD_COUNT=$(ddev mysql hospital_tasks -e "SELECT COUNT(*) FROM staff;" -s -N)
SUPERVISOR_COUNT=$(ddev mysql hospital_tasks -e "SELECT COUNT(*) FROM shift_porter_pool WHERE is_supervisor = TRUE;" -s -N)

print_success "Database verification:"
echo "   📊 Tables: $TABLE_COUNT"
echo "   👥 Staff records: $RECORD_COUNT"
echo "   👨‍💼 Supervisors in porter pool: $SUPERVISOR_COUNT"

if [ "$SUPERVISOR_COUNT" -gt "0" ]; then
    print_success "Supervisor issue has been fixed!"
else
    print_error "Supervisor issue still exists"
fi

echo ""
print_success "🎉 Fixed data import completed!"
echo ""
echo "🚀 Next steps:"
echo "   1. Start API: ddev exec 'cd api && npm run dev'"
echo "   2. Start frontend: ddev exec 'npm run dev'"
echo "   3. Test porter pool functionality"
