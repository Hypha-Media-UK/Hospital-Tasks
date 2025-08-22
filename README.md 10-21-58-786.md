

npm run dev
cd api && npm run dev
# Hospital Task Management System

A comprehensive hospital porter task management system built with Vue.js 3, Node.js/Express, and MySQL.

## 🏗️ Architecture

- **Frontend**: Vue.js 3 + Vite + Pinia (State Management)
- **Backend**: Node.js + Express + TypeScript
- **Database**: MySQL 8.0 with Prisma ORM
- **Development**: Docker Compose (database only)

## 🚀 Local Development Setup

### Prerequisites

- Node.js 18+ 
- Docker and Docker Compose
- Git

### 1. Clone Repository

```bash
git clone https://github.com/Hypha-Media-UK/Hospital-Tasks.git
cd Hospital-Tasks
```

### 2. Start Database

```bash
# Start MySQL database with Docker Compose
docker-compose up -d

# Verify database is running
docker ps
```

### 3. Setup Backend API

```bash
# Navigate to API directory
cd api

# Install dependencies
npm install

# Generate Prisma client
npm run prisma:generate

# Push database schema (creates tables)
npm run prisma:push

# Start development server
npm run dev
```

The API server will start on `http://localhost:3000`

### 4. Setup Frontend

```bash
# In a new terminal, navigate to project root
cd /path/to/Hospital-Tasks

# Install dependencies
npm install

# Start development server
npm run dev
```

The frontend will start on `http://localhost:5173`

### 5. Verify Setup

- **API Health Check**: `curl http://localhost:3000/health`
- **Frontend**: Open `http://localhost:5173` in browser
- **Database**: Should show empty tables initially

### 6. Import Sample Data (Optional)

If you have existing data to import:

```bash
# Import SQL dump into database
docker exec -i hospital-tasks-db mysql -u root -proot hospital_tasks < your_backup.sql
```

## 🌐 Production Deployment

### Server Requirements

- Ubuntu 20.04+ or similar Linux distribution
- Node.js 18+
- MySQL 8.0
- Nginx
- PM2 (for process management)
- SSL certificate (recommended)

### 1. Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install MySQL
sudo apt install mysql-server -y
sudo mysql_secure_installation

# Install Nginx
sudo apt install nginx -y

# Install PM2 globally
sudo npm install -g pm2
```

### 2. Database Setup

```bash
# Login to MySQL as root
sudo mysql -u root -p

# Create database and user
CREATE DATABASE hospital_tasks;
CREATE USER 'hospital_user'@'localhost' IDENTIFIED BY 'secure_password_here';
GRANT ALL PRIVILEGES ON hospital_tasks.* TO 'hospital_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 3. Deploy Application

```bash
# Clone repository to server
git clone https://github.com/Hypha-Media-UK/Hospital-Tasks.git
cd Hospital-Tasks

# Setup backend
cd api
npm install
npm run build

# Create production environment file
cp .env.example .env
```

Edit `api/.env` for production:
```bash
# Production Database
DATABASE_URL="mysql://hospital_user:secure_password_here@localhost:3306/hospital_tasks"

# Server Configuration
PORT=3000
NODE_ENV=production

# CORS Origins (your domain)
CORS_ORIGINS=https://yourdomain.com

# Security (generate secure keys)
JWT_SECRET=your-super-secure-jwt-key-here
API_KEY=your-secure-api-key-here
```

```bash
# Setup database schema
npm run prisma:generate
npm run prisma:push

# Import your data (if you have a backup)
mysql -u hospital_user -p hospital_tasks < your_backup.sql

# Start API with PM2
pm2 start dist/server.js --name "hospital-api"
pm2 save
pm2 startup
```

### 4. Build Frontend

```bash
# Navigate to project root
cd /path/to/Hospital-Tasks

# Install dependencies
npm install

# Create production environment file
cp .env.example .env
```

Edit `.env` for production:
```bash
# Production API URL
VITE_API_BASE_URL=https://yourdomain.com/api
```

```bash
# Build for production
npm run build

# Copy built files to web server directory
sudo cp -r dist/* /var/www/html/
```

### 5. Configure Nginx

Create `/etc/nginx/sites-available/hospital-tasks`:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;
    
    # SSL Configuration (use Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # Frontend static files
    location / {
        root /var/www/html;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # API proxy
    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/hospital-tasks /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 6. SSL Certificate (Let's Encrypt)

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Get SSL certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Auto-renewal (already set up by certbot)
sudo certbot renew --dry-run
```

### 7. Firewall Configuration

```bash
# Configure UFW firewall
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

## 🔧 Maintenance

### Local Development

```bash
# Start everything
docker-compose up -d
cd api && npm run dev &
npm run dev

# Stop everything
docker-compose down
# Kill Node processes or use Ctrl+C
```

### Production

```bash
# View API logs
pm2 logs hospital-api

# Restart API
pm2 restart hospital-api

# Update application
git pull
cd api && npm run build
pm2 restart hospital-api

# Frontend updates
npm run build
sudo cp -r dist/* /var/www/html/
```

### Database Backup

```bash
# Local backup
docker exec hospital-tasks-db mysqldump -u root -proot hospital_tasks > backup.sql

# Production backup
mysqldump -u hospital_user -p hospital_tasks > backup_$(date +%Y%m%d).sql
```

## 📁 Project Structure

```
Hospital-Tasks/
├── api/                    # Backend API
│   ├── src/
│   │   ├── server.ts      # Main server file
│   │   └── routes/        # API routes
│   ├── prisma/
│   │   └── schema.prisma  # Database schema
│   └── package.json
├── src/                   # Frontend Vue.js app
│   ├── components/        # Vue components
│   ├── stores/           # Pinia stores
│   ├── views/            # Page components
│   └── services/         # API services
├── docker-compose.yml    # Local database setup
└── package.json         # Frontend dependencies
```

## 🆘 Troubleshooting

### Common Issues

1. **API Connection Failed**
   - Check if API server is running: `curl http://localhost:3000/health`
   - Verify database connection in API logs
   - Check environment variables

2. **Database Connection Issues**
   - Ensure MySQL is running: `docker ps` (local) or `sudo systemctl status mysql` (production)
   - Verify DATABASE_URL in `api/.env`
   - Check firewall settings

3. **Frontend Build Issues**
   - Clear node_modules: `rm -rf node_modules && npm install`
   - Check VITE_API_BASE_URL in `.env`

4. **Production Deployment Issues**
   - Check Nginx configuration: `sudo nginx -t`
   - View Nginx logs: `sudo tail -f /var/log/nginx/error.log`
   - Check PM2 status: `pm2 status`

### Support

For issues or questions, please check the project repository or contact the development team.
