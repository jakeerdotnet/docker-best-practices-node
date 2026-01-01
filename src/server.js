const express = require('express');
const winston = require('winston');
const path = require('path');
const fs = require('fs').promises;

// Configure structured logging
const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'docker-best-practices-app' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ level, message, timestamp, ...meta }) => {
          return `${timestamp} [${level}]: ${message} ${Object.keys(meta).length ? JSON.stringify(meta, null, 2) : ''}`;
        })
      )
    })
  ]
});

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Middleware
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('HTTP Request', {
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip
    });
  });
  next();
});

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Check if we can access basic resources
    await fs.access('/tmp', fs.constants.W_OK);
    
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: NODE_ENV,
      memory: process.memoryUsage(),
      version: require('../package.json').version
    });
  } catch (error) {
    logger.error('Health check failed', { error: error.message });
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Ready check endpoint (for Kubernetes readiness probes)
app.get('/ready', (req, res) => {
  res.status(200).json({
    ready: true,
    timestamp: new Date().toISOString()
  });
});

// API Routes
app.get('/api/info', (req, res) => {
  res.json({
    name: 'Docker Best Practices App',
    version: require('../package.json').version,
    environment: NODE_ENV,
    timestamp: new Date().toISOString()
  });
});

app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to Docker Best Practices App',
    documentation: {
      health: '/health',
      ready: '/ready',
      info: '/api/info'
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method
  });
  res.status(500).json({
    error: 'Internal Server Error',
    message: NODE_ENV === 'development' ? err.message : 'An error occurred'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path
  });
});

// Create server
const server = app.listen(PORT, () => {
  logger.info('Server started', {
    port: PORT,
    environment: NODE_ENV,
    pid: process.pid
  });
});

// Graceful shutdown handling
const shutdown = (signal) => {
  logger.info(`${signal} received, starting graceful shutdown`, {
    pid: process.pid
  });

  // Give server 30 seconds to finish existing connections
  const shutdownTimeout = setTimeout(() => {
    logger.error('Forced shutdown - timeout exceeded');
    process.exit(1);
  }, 30000);

  server.close(() => {
    clearTimeout(shutdownTimeout);
    logger.info('Server closed gracefully');
    process.exit(0);
  });

  // Handle new requests during shutdown
  server.on('request', (req, res) => {
    res.statusCode = 503;
    res.setHeader('Retry-After', '120');
    res.end('Service is shutting down');
  });
};

// Handle termination signals
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception', {
    error: error.message,
    stack: error.stack
  });
  process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection', {
    reason: reason,
    promise: promise
  });
  process.exit(1);
});

module.exports = app;
