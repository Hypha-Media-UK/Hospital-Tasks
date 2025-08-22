import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { prettyJSON } from 'hono/pretty-json';

// Import routes
import { staffRoutes } from './routes/staff.js';
import { buildingRoutes } from './routes/buildings.js';
import { departmentRoutes } from './routes/departments.js';
import { taskTypeRoutes } from './routes/task-types.js';
import { taskItemRoutes } from './routes/task-items.js';
import { supportServiceRoutes } from './routes/support-services.js';

// Create main app
const app = new Hono();

// Middleware
app.use('*', logger());
app.use('*', prettyJSON());
app.use('*', cors({
  origin: ['http://localhost:5173', 'http://localhost:3000'],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

// Health check
app.get('/', (c) => {
  return c.json({
    name: 'Hospital Tasks API V2',
    version: '1.0.0',
    status: 'healthy',
    timestamp: new Date().toISOString(),
  });
});

// API routes
app.route('/api/staff', staffRoutes);
app.route('/api/buildings', buildingRoutes);
app.route('/api/departments', departmentRoutes);
app.route('/api/task-types', taskTypeRoutes);
app.route('/api/task-items', taskItemRoutes);
app.route('/api/support-services', supportServiceRoutes);

// 404 handler
app.notFound((c) => {
  return c.json({ error: 'Not Found', message: 'Route not found' }, 404);
});

// Error handler
app.onError((err, c) => {
  console.error('Unhandled error:', err);
  return c.json(
    { 
      error: 'Internal Server Error', 
      message: 'An unexpected error occurred',
      ...(process.env.NODE_ENV === 'development' && { details: err.message })
    }, 
    500
  );
});

// Start server
const port = Number(process.env.PORT) || 3001;

console.log(`🚀 Hospital Tasks API V2 starting on port ${port}`);
console.log(`📊 Health check: http://localhost:${port}/`);
console.log(`🔗 API endpoints: http://localhost:${port}/api/`);

export default {
  port,
  fetch: app.fetch,
};
