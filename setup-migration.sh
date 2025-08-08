#!/bin/bash

# ============================================================================
# Hospital Tasks - MySQL Migration Setup Script
# ============================================================================

set -e  # Exit on any error

echo "🏥 Hospital Tasks - MySQL Migration Setup"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if required files exist
print_status "Checking required files..."

if [ ! -f "supabase/hospital-20250705-1431.sql" ]; then
    print_error "PostgreSQL dump file not found: supabase/hospital-20250705-1431.sql"
    exit 1
fi

if [ ! -f "mysql-schema.sql" ]; then
    print_error "MySQL schema file not found: mysql-schema.sql"
    exit 1
fi

print_success "Required files found"

# Step 1: Extract data from PostgreSQL dump
print_status "Step 1: Extracting data from PostgreSQL dump..."

if command -v python3 &> /dev/null; then
    print_status "Using improved data extraction script..."
    python3 fix-data-extraction.py
    if [ $? -eq 0 ]; then
        print_success "Data extraction completed using improved Python script"
        # Use the fixed data file
        if [ -f "mysql-data-fixed.sql" ]; then
            cp mysql-data-fixed.sql mysql-data.sql
            print_success "Using fixed data file"
        fi
    else
        print_error "Data extraction failed"
        exit 1
    fi
elif command -v node &> /dev/null; then
    node convert-data.js
    if [ $? -eq 0 ]; then
        print_success "Data extraction completed using Node.js"
    else
        print_error "Data extraction failed"
        exit 1
    fi
else
    print_error "Neither Python3 nor Node.js found. Please install one of them."
    exit 1
fi

# Step 2: Setup DDEV environment
print_status "Step 2: Setting up DDEV environment..."

if ! command -v ddev &> /dev/null; then
    print_error "DDEV not found. Please install DDEV first."
    print_status "Visit: https://ddev.readthedocs.io/en/stable/#installation"
    exit 1
fi

# Initialize DDEV if not already done
if [ ! -f ".ddev/config.yaml" ]; then
    print_error "DDEV config not found. Please ensure .ddev/config.yaml exists."
    exit 1
fi

print_status "Running DDEV setup script..."
chmod +x setup-ddev.sh
./setup-ddev.sh

if [ $? -eq 0 ]; then
    print_success "DDEV setup completed successfully"
else
    print_error "DDEV setup failed"
    exit 1
fi

# Step 3: Create database and import schema
print_status "Step 3: Setting up MySQL database..."

print_status "Creating database..."
ddev mysql -e "DROP DATABASE IF EXISTS hospital_tasks; CREATE DATABASE hospital_tasks CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

print_status "Importing schema..."
ddev mysql hospital_tasks < mysql-schema.sql

if [ $? -eq 0 ]; then
    print_success "Schema imported successfully"
else
    print_error "Failed to import schema"
    exit 1
fi

# Step 4: Import data (use fixed data if available)
if [ -f "mysql-data-fixed.sql" ]; then
    print_status "Step 4: Importing fixed data..."
    ddev mysql hospital_tasks < mysql-data-fixed.sql

    if [ $? -eq 0 ]; then
        print_success "Fixed data imported successfully"
    else
        print_error "Fixed data import failed"
        exit 1
    fi
elif [ -f "mysql-data.sql" ]; then
    print_status "Step 4: Importing data..."
    ddev mysql hospital_tasks < mysql-data.sql

    if [ $? -eq 0 ]; then
        print_success "Data imported successfully"
    else
        print_warning "Data import had issues, but continuing..."
    fi
else
    print_warning "No data file found, skipping data import"
fi

# Step 5: Setup Node.js API
print_status "Step 5: Setting up Node.js API..."

if [ ! -d "api" ]; then
    print_error "API directory not found"
    exit 1
fi

cd api

# Copy environment file
if [ ! -f ".env" ]; then
    cp .env.example .env
    print_success "Created .env file from template"
fi

# Install dependencies
print_status "Installing API dependencies..."
ddev exec "cd api && npm install"

if [ $? -eq 0 ]; then
    print_success "API dependencies installed"
else
    print_error "Failed to install API dependencies"
    exit 1
fi

cd ..

# Step 6: Install frontend dependencies
print_status "Step 6: Setting up frontend dependencies..."

print_status "Installing frontend dependencies..."
ddev exec "npm install"

if [ $? -eq 0 ]; then
    print_success "Frontend dependencies installed"
else
    print_error "Failed to install frontend dependencies"
    exit 1
fi

# Step 7: Test database connection
print_status "Step 7: Testing database connection..."

ddev mysql -e "USE hospital_tasks; SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'hospital_tasks';"

if [ $? -eq 0 ]; then
    print_success "Database connection test passed"
else
    print_error "Database connection test failed"
    exit 1
fi

# Final summary
echo ""
echo "🎉 Migration setup completed successfully!"
echo "========================================"
echo ""
print_success "✅ DDEV environment is running"
print_success "✅ MySQL database created and schema imported"
print_success "✅ Node.js API dependencies installed"
print_success "✅ Frontend dependencies installed"
echo ""
echo "🔗 URLs:"
echo "   Frontend: https://hospital-tasks.ddev.site"
echo "   API: https://hospital-tasks.ddev.site/api"
echo "   Database: accessible via 'ddev mysql'"
echo ""
echo "🚀 Next steps:"
echo "   1. Start the API server: ddev exec 'cd api && npm run dev'"
echo "   2. Start the frontend: ddev exec 'npm run dev'"
echo "   3. Update Vue.js service layer to use new API"
echo ""
echo "📚 Useful commands:"
echo "   ddev logs -f          # View logs"
echo "   ddev mysql            # Access MySQL"
echo "   ddev ssh              # SSH into container"
echo "   ddev stop             # Stop environment"
echo ""
print_warning "Remember to update your Vue.js app to use the new API endpoints!"
