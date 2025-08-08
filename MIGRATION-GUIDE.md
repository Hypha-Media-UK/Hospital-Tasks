# Hospital Tasks - Supabase to MySQL Migration Guide

## Overview

This guide covers the complete migration from Supabase (PostgreSQL) to MySQL with DDEV and Node.js/Express API.

## Migration Components

### 1. Database Schema (`mysql-schema.sql`)
- ✅ Complete MySQL 8.0 schema conversion
- ✅ All 28 tables converted from PostgreSQL
- ✅ Foreign key relationships maintained
- ✅ Indexes added for performance
- ✅ UUID support using MySQL 8.0 native functions

### 2. Data Conversion Scripts
- ✅ `extract-data.py` - Python script for data extraction
- ✅ `convert-data.js` - Node.js alternative for data extraction
- ✅ Handles PostgreSQL to MySQL data type conversions
- ✅ Fixes supervisor issue in `shift_porter_pool` table

### 3. DDEV Configuration (`.ddev/config.yaml`)
- ✅ Node.js 18 environment
- ✅ MySQL 8.0 database
- ✅ Custom commands for database operations
- ✅ Environment variables configured

### 4. Node.js API (`api/`)
- ✅ Express.js server with security middleware
- ✅ MySQL connection pool with query builder
- ✅ Supabase-like query interface for easy migration
- ✅ Complete route structure for all endpoints
- ✅ Error handling and logging

### 5. Setup Automation (`setup-migration.sh`)
- ✅ Automated migration process
- ✅ Database setup and data import
- ✅ Dependency installation
- ✅ Environment configuration

## Quick Start

### Prerequisites
- DDEV installed and configured
- Node.js 16+ (handled by DDEV)
- Python 3 (for data extraction)

### Migration Steps

1. **Run the setup script:**
   ```bash
   chmod +x setup-migration.sh
   ./setup-migration.sh
   ```

2. **Start the API server:**
   ```bash
   ddev exec "cd api && npm run dev"
   ```

3. **Start the frontend:**
   ```bash
   ddev exec "npm run dev"
   ```

4. **Update Vue.js service layer** (see Frontend Changes section)

## Database Schema Changes

### Key Conversions
- `UUID` → `CHAR(36)` with MySQL 8.0 UUID() function
- `timestamp with time zone` → `TIMESTAMP` (UTC)
- `time without time zone` → `TIME`
- `text` → `TEXT` or `VARCHAR(255)`
- `ENUM` types → MySQL ENUM
- PostgreSQL functions → Removed (handled in API)

### Fixed Issues
- ✅ Supervisor assignment bug in `shift_porter_pool`
- ✅ Foreign key constraints properly configured
- ✅ Indexes added for performance optimization

## API Endpoints

### Core Endpoints
- `GET /api/shifts` - List shifts with filtering
- `POST /api/shifts` - Create new shift (with supervisor auto-assignment)
- `GET /api/staff` - List staff with role filtering
- `GET /api/tasks` - List tasks with shift/porter filtering
- `GET /api/buildings` - List buildings with departments
- `GET /api/departments` - List departments with building info

### Query Interface
The API provides a Supabase-like query interface:

```javascript
// Before (Supabase)
const { data } = await supabase
  .from('shifts')
  .select('*, staff(first_name, last_name)')
  .eq('is_active', true)
  .order('created_at', { ascending: false });

// After (MySQL API)
const response = await fetch('/api/shifts?is_active=true');
const data = await response.json();
```

## Frontend Changes Required

### 1. Update Service Layer
Replace `src/services/supabase.js` with new API service:

```javascript
// src/services/api.js
const API_BASE = import.meta.env.VITE_API_URL || '/api';

export const api = {
  async get(endpoint, params = {}) {
    const url = new URL(`${API_BASE}${endpoint}`);
    Object.keys(params).forEach(key => 
      url.searchParams.append(key, params[key])
    );
    
    const response = await fetch(url);
    if (!response.ok) throw new Error(`API Error: ${response.statusText}`);
    return response.json();
  },
  
  async post(endpoint, data) {
    const response = await fetch(`${API_BASE}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    if (!response.ok) throw new Error(`API Error: ${response.statusText}`);
    return response.json();
  },
  
  // Add put, delete methods as needed
};
```

### 2. Update Store Methods
Example for `shiftsStore.js`:

```javascript
// Before
async fetchShifts() {
  const { data, error } = await supabase
    .from('shifts')
    .select('*, staff(first_name, last_name)')
    .eq('is_active', true);
  
  if (error) throw error;
  return data;
}

// After  
async fetchShifts() {
  return await api.get('/shifts', { is_active: true });
}
```

### 3. Update Environment Variables
```env
# .env
VITE_API_URL=https://hospital-tasks.ddev.site/api
```

## Development Workflow

### DDEV Commands
```bash
# Start environment
ddev start

# Access database
ddev mysql

# View logs
ddev logs -f

# SSH into container
ddev ssh

# Stop environment
ddev stop
```

### Database Operations
```bash
# Reset database
ddev exec "mysql -u root -e 'DROP DATABASE IF EXISTS hospital_tasks; CREATE DATABASE hospital_tasks;'"
ddev exec "mysql -u root hospital_tasks < mysql-schema.sql"
ddev exec "mysql -u root hospital_tasks < mysql-data.sql"

# Or use custom command
ddev db-reset
```

## Production Deployment

### VPS with Plesk
1. **Upload files** to VPS
2. **Install Node.js** via Plesk
3. **Create MySQL database** in Plesk
4. **Import schema and data**
5. **Configure environment variables**
6. **Set up reverse proxy** from Plesk to Node.js API
7. **Build and serve Vue.js** as static files

### Environment Variables for Production
```env
NODE_ENV=production
DB_HOST=localhost
DB_USER=your_db_user
DB_PASSWORD=your_db_password
DB_NAME=hospital_tasks
PORT=3001
```

## Testing

### API Testing
```bash
# Health check
curl https://hospital-tasks.ddev.site/health

# Test endpoints
curl https://hospital-tasks.ddev.site/api/shifts
curl https://hospital-tasks.ddev.site/api/staff?role=supervisor
```

### Database Testing
```sql
-- Verify supervisor fix
SELECT 
  spp.*, 
  s.supervisor_id,
  staff.first_name, 
  staff.last_name 
FROM shift_porter_pool spp
JOIN shifts s ON spp.shift_id = s.id
JOIN staff ON spp.porter_id = staff.id
WHERE spp.is_supervisor = TRUE;
```

## Troubleshooting

### Common Issues
1. **Database connection fails**: Check DDEV is running and database credentials
2. **API returns 500 errors**: Check API logs with `ddev logs -f`
3. **Frontend can't connect**: Verify VITE_API_URL environment variable
4. **Supervisor not showing**: Run the supervisor fix SQL query

### Logs
- **API logs**: `ddev logs -f`
- **Database logs**: `ddev mysql -e "SHOW PROCESSLIST;"`
- **Frontend logs**: Browser developer console

## Next Steps

1. ✅ Complete basic migration setup
2. 🔄 Test all API endpoints thoroughly
3. 🔄 Update Vue.js frontend to use new API
4. 🔄 Implement remaining route handlers (area cover, absences)
5. 🔄 Add authentication if needed
6. 🔄 Performance optimization
7. 🔄 Production deployment testing

## Support

For issues or questions about this migration:
1. Check the troubleshooting section
2. Review DDEV logs
3. Test API endpoints individually
4. Verify database schema and data integrity
