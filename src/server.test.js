const request = require('supertest');
const app = require('../src/server');

describe('Application Health Endpoints', () => {
  describe('GET /health', () => {
    it('should return 200 OK for health check', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);
      
      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
    });
  });

  describe('GET /ready', () => {
    it('should return 200 OK for readiness check', async () => {
      const response = await request(app)
        .get('/ready')
        .expect(200);
      
      expect(response.body).toHaveProperty('ready', true);
    });
  });

  describe('GET /api/info', () => {
    it('should return application info', async () => {
      const response = await request(app)
        .get('/api/info')
        .expect(200);
      
      expect(response.body).toHaveProperty('name');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('environment');
    });
  });

  describe('GET /', () => {
    it('should return welcome message', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);
      
      expect(response.body).toHaveProperty('message');
      expect(response.body).toHaveProperty('documentation');
    });
  });

  describe('404 Error Handling', () => {
    it('should return 404 for non-existent routes', async () => {
      const response = await request(app)
        .get('/nonexistent')
        .expect(404);
      
      expect(response.body).toHaveProperty('error', 'Not Found');
    });
  });
});
