#!/bin/bash

# ============================================================================
# Manual Import Script - Hospital Tasks
# ============================================================================

echo "🏥 Manual Import - Hospital Tasks Database"
echo "=========================================="

# Check if DDEV is running
if ! ddev describe >/dev/null 2>&1; then
    echo "❌ DDEV is not running. Please run 'ddev start' first."
    exit 1
fi

echo "✅ DDEV is running"

# Step 1: Create database
echo "📊 Creating database..."
ddev mysql -e "DROP DATABASE IF EXISTS hospital_tasks; CREATE DATABASE hospital_tasks CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

if [ $? -eq 0 ]; then
    echo "✅ Database created"
else
    echo "❌ Database creation failed"
    exit 1
fi

# Step 2: Import schema
echo "📋 Importing schema..."
ddev mysql hospital_tasks < mysql-schema.sql

if [ $? -eq 0 ]; then
    echo "✅ Schema imported"
else
    echo "❌ Schema import failed"
    exit 1
fi

# Step 3: Import fixed data
echo "📦 Importing fixed data..."
ddev mysql hospital_tasks < mysql-data-fixed.sql

if [ $? -eq 0 ]; then
    echo "✅ Data imported successfully!"
else
    echo "❌ Data import failed"
    exit 1
fi

# Step 4: Verify import
echo "🔍 Verifying import..."
TABLES=$(ddev mysql hospital_tasks -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'hospital_tasks';" -s -N)
STAFF=$(ddev mysql hospital_tasks -e "SELECT COUNT(*) FROM staff;" -s -N)
SUPERVISORS=$(ddev mysql hospital_tasks -e "SELECT COUNT(*) FROM shift_porter_pool WHERE is_supervisor = TRUE;" -s -N)

echo "📊 Import Summary:"
echo "   Tables: $TABLES"
echo "   Staff: $STAFF"
echo "   Supervisors in porter pool: $SUPERVISORS"

if [ "$SUPERVISORS" -gt "0" ]; then
    echo "✅ Supervisor issue fixed!"
else
    echo "⚠️  Supervisor issue may still exist"
fi

echo ""
echo "🎉 Manual import completed!"
echo ""
echo "🚀 Next steps:"
echo "   1. Start API: ddev exec 'cd api && npm run dev'"
echo "   2. Start frontend: ddev exec 'npm run dev'"
echo "   3. Visit: https://hospital-tasks.ddev.site"
