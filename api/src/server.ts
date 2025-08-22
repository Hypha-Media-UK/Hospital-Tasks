import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';

// Import routes
import staffRoutes from './routes/staff';
import buildingRoutes from './routes/buildings';
import departmentRoutes from './routes/departments';
import taskTypeRoutes from './routes/taskTypes-new'; // Using DRY CRUD factory
import taskItemRoutes from './routes/taskItems';
import taskRoutes from './routes/tasks';
import shiftRoutes from './routes/shifts';
import absenceRoutes from './routes/absences';
import supportServiceRoutes from './routes/supportServices';
import settingRoutes from './routes/settings';
import areaCoverRoutes from './routes/areaCover';

// Load environment variables
dotenv.config();

// Initialize Prisma Client
export const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
});

// Create Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(compression());
app.use(morgan(process.env.NODE_ENV === 'development' ? 'dev' : 'combined'));

// CORS configuration
const corsOrigins = process.env.CORS_ORIGINS?.split(',') || ['http://localhost:5173', 'http://localhost:5174'];
app.use(cors({
  origin: corsOrigins,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key'],
}));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
  });
});

// API Routes
app.use('/api/staff', staffRoutes);
app.use('/api/buildings', buildingRoutes);
app.use('/api/departments', departmentRoutes);
app.use('/api/task-types', taskTypeRoutes); // Now using DRY CRUD factory
app.use('/api/task-items', taskItemRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/shifts', shiftRoutes);
app.use('/api/absences', absenceRoutes);
app.use('/api/support-services', supportServiceRoutes);
app.use('/api/settings', settingRoutes);
app.use('/api/area-cover', areaCoverRoutes);

// 404 handler
app.use('*', notFoundHandler);

// Global error handler
app.use(errorHandler);

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('Received SIGINT, shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('Received SIGTERM, shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Handle server errors
server.on('error', (error: any) => {
  if (error.syscall !== 'listen') {
    throw error;
  }

  switch (error.code) {
    case 'EACCES':
      console.error(`Port ${PORT} requires elevated privileges`);
      process.exit(1);
      break;
    case 'EADDRINUSE':
      console.error(`Port ${PORT} is already in use`);
      process.exit(1);
      break;
    default:
      throw error;
  }
});

export default app;
