import express from 'express';
import request from 'supertest';
import { createRateLimiter } from './rateLimit';

describe('Rate Limiting Middleware', () => {
  let app: express.Application;

  beforeEach(() => {
    app = express();
  });

  it('should allow requests within the rate limit', async () => {
    const limiter = createRateLimiter(1000, 2); // 2 requests per second
    app.use(limiter);
    app.get('/test', (req, res) => res.json({ message: 'success' }));

    // First request
    const response1 = await request(app).get('/test');
    expect(response1.status).toBe(200);
    expect(response1.body).toEqual({ message: 'success' });

    // Second request
    const response2 = await request(app).get('/test');
    expect(response2.status).toBe(200);
    expect(response2.body).toEqual({ message: 'success' });
  });

  it('should block requests exceeding the rate limit', async () => {
    const limiter = createRateLimiter(1000, 1); // 1 request per second
    app.use(limiter);
    app.get('/test', (req, res) => res.json({ message: 'success' }));

    // First request (allowed)
    const response1 = await request(app).get('/test');
    expect(response1.status).toBe(200);

    // Second request (blocked)
    const response2 = await request(app).get('/test');
    expect(response2.status).toBe(429); // Too Many Requests
    expect(response2.body).toEqual({
      error: 'Too many requests from this IP, please try again later',
    });
  });

  it('should reset rate limit after window expires', async () => {
    const windowMs = 100; // 100ms window
    const limiter = createRateLimiter(windowMs, 1);
    app.use(limiter);
    app.get('/test', (req, res) => res.json({ message: 'success' }));

    // First request (allowed)
    const response1 = await request(app).get('/test');
    expect(response1.status).toBe(200);

    // Second request (blocked)
    const response2 = await request(app).get('/test');
    expect(response2.status).toBe(429);

    // Wait for window to expire
    await new Promise(resolve => setTimeout(resolve, windowMs + 50));

    // Third request (allowed)
    const response3 = await request(app).get('/test');
    expect(response3.status).toBe(200);
  });

  it('should include rate limit headers', async () => {
    const limiter = createRateLimiter(1000, 2);
    app.use(limiter);
    app.get('/test', (req, res) => res.json({ message: 'success' }));

    const response = await request(app).get('/test');
    expect(response.headers['ratelimit-limit']).toBeDefined();
    expect(response.headers['ratelimit-remaining']).toBeDefined();
    expect(response.headers['ratelimit-reset']).toBeDefined();
  });

  it('should use default values when no parameters provided', async () => {
    const limiter = createRateLimiter();
    app.use(limiter);
    app.get('/test', (req, res) => res.json({ message: 'success' }));

    const response = await request(app).get('/test');
    expect(response.status).toBe(200);
    expect(response.headers['ratelimit-limit']).toBe('100');
  });
}); 