import request from 'supertest';
import express from 'express';
import jwt from 'jsonwebtoken';
import { exec, ExecException } from 'child_process';

// Mock child_process.exec
jest.mock('child_process', () => ({
  exec: jest.fn((
    command: string,
    options: any,
    callback?: (error: ExecException | null, stdout: string, stderr: string) => void
  ) => {
    if (callback) {
      callback(null, '', '');
    }
    return undefined as any;
  }),
}));

// Mock environment variables
const JWT_SECRET = 'test-secret';
process.env.JWT_SECRET = JWT_SECRET;
process.env.NETWORK_INTERFACE = 'eth0';

// Import app after environment variables are set
const app = require('./index').default;

describe('Network Controller API', () => {
  const mockExec = exec as jest.MockedFunction<typeof exec>;
  const validMacAddress = '00:11:22:33:44:55';
  const validToken = jwt.sign({ role: 'parent' }, JWT_SECRET);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Authentication', () => {
    it('should reject requests without token', async () => {
      const response = await request(app)
        .post('/network/allow')
        .send({ macAddress: validMacAddress });

      expect(response.status).toBe(401);
      expect(response.body.error).toBe('Authentication required');
    });

    it('should reject requests with invalid token', async () => {
      const response = await request(app)
        .post('/network/allow')
        .set('Authorization', 'Bearer invalid-token')
        .send({ macAddress: validMacAddress });

      expect(response.status).toBe(403);
      expect(response.body.error).toBe('Invalid token');
    });

    it('should reject requests from non-parent users', async () => {
      const kidToken = jwt.sign({ role: 'kid' }, JWT_SECRET);
      const response = await request(app)
        .post('/network/allow')
        .set('Authorization', `Bearer ${kidToken}`)
        .send({ macAddress: validMacAddress });

      expect(response.status).toBe(403);
      expect(response.body.error).toBe('Only parents can control network access');
    });
  });

  describe('POST /network/allow', () => {
    it('should allow device access', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(null, '', '');
        }
        return undefined as any;
      });

      const response = await request(app)
        .post('/network/allow')
        .set('Authorization', `Bearer ${validToken}`)
        .send({ macAddress: validMacAddress });

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        message: 'Device access allowed',
        macAddress: validMacAddress,
      });
      expect(mockExec).toHaveBeenCalledWith(
        expect.stringContaining(`sudo iptables -A FORWARD -i eth0 -m mac --mac-source ${validMacAddress}`),
        expect.any(Object),
        expect.any(Function)
      );
    });

    it('should reject invalid MAC addresses', async () => {
      const response = await request(app)
        .post('/network/allow')
        .set('Authorization', `Bearer ${validToken}`)
        .send({ macAddress: 'invalid-mac' });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Invalid MAC address');
    });

    it('should handle iptables errors', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(new Error('iptables error') as ExecException, '', '');
        }
        return undefined as any;
      });

      const response = await request(app)
        .post('/network/allow')
        .set('Authorization', `Bearer ${validToken}`)
        .send({ macAddress: validMacAddress });

      expect(response.status).toBe(500);
      expect(response.body.error).toBe('Failed to allow device access');
    });
  });

  describe('POST /network/block', () => {
    it('should block device access', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(null, '', '');
        }
        return undefined as any;
      });

      const response = await request(app)
        .post('/network/block')
        .set('Authorization', `Bearer ${validToken}`)
        .send({ macAddress: validMacAddress });

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        message: 'Device access blocked',
        macAddress: validMacAddress,
      });
      expect(mockExec).toHaveBeenCalledWith(
        expect.stringContaining(`sudo iptables -D FORWARD -i eth0 -m mac --mac-source ${validMacAddress}`),
        expect.any(Object),
        expect.any(Function)
      );
    });

    it('should reject invalid MAC addresses', async () => {
      const response = await request(app)
        .post('/network/block')
        .set('Authorization', `Bearer ${validToken}`)
        .send({ macAddress: 'invalid-mac' });

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Invalid MAC address');
    });

    it('should handle iptables errors', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(new Error('iptables error') as ExecException, '', '');
        }
        return undefined as any;
      });

      const response = await request(app)
        .post('/network/block')
        .set('Authorization', `Bearer ${validToken}`)
        .send({ macAddress: validMacAddress });

      expect(response.status).toBe(500);
      expect(response.body.error).toBe('Failed to block device access');
    });
  });

  describe('GET /network/status/:macAddress', () => {
    it('should return device status when allowed', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(null, 'ACCEPT  all  --  anywhere  anywhere  MAC 00:11:22:33:44:55', '');
        }
        return undefined as any;
      });

      const response = await request(app)
        .get(`/network/status/${validMacAddress}`)
        .set('Authorization', `Bearer ${validToken}`);

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        macAddress: validMacAddress,
        isAllowed: true,
      });
    });

    it('should return device status when blocked', async () => {
      mockExec.mockImplementation((command, options, callback) => {
        if (callback) {
          callback(null, '', '');
        }
        return undefined as any;
      });

      const response = await request(app)
        .get(`/network/status/${validMacAddress}`)
        .set('Authorization', `Bearer ${validToken}`);

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        macAddress: validMacAddress,
        isAllowed: false,
      });
    });

    it('should reject invalid MAC addresses', async () => {
      const response = await request(app)
        .get('/network/status/invalid-mac')
        .set('Authorization', `Bearer ${validToken}`);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Invalid MAC address');
    });
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body).toEqual({ status: 'ok' });
    });
  });
}); 