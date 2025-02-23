import { Request, Response, NextFunction } from 'express';
import { validateMacAddress, isValidMacAddress } from './validation';

describe('Validation Middleware', () => {
  let mockRequest: Partial<Request>;
  let mockResponse: Partial<Response>;
  let nextFunction: NextFunction;

  beforeEach(() => {
    mockRequest = {};
    mockResponse = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    nextFunction = jest.fn();
  });

  describe('validateMacAddress', () => {
    it('should pass valid MAC address from params', () => {
      mockRequest.params = { macAddress: '00:11:22:33:44:55' };

      validateMacAddress(
        mockRequest as Request,
        mockResponse as Response,
        nextFunction
      );

      expect(nextFunction).toHaveBeenCalled();
      expect(mockResponse.status).not.toHaveBeenCalled();
      expect(mockResponse.json).not.toHaveBeenCalled();
    });

    it('should pass valid MAC address from body', () => {
      mockRequest.body = { macAddress: '00:11:22:33:44:55' };

      validateMacAddress(
        mockRequest as Request,
        mockResponse as Response,
        nextFunction
      );

      expect(nextFunction).toHaveBeenCalled();
      expect(mockResponse.status).not.toHaveBeenCalled();
      expect(mockResponse.json).not.toHaveBeenCalled();
    });

    it('should reject missing MAC address', () => {
      mockRequest.params = {};
      mockRequest.body = {};

      validateMacAddress(
        mockRequest as Request,
        mockResponse as Response,
        nextFunction
      );

      expect(mockResponse.status).toHaveBeenCalledWith(400);
      expect(mockResponse.json).toHaveBeenCalledWith({
        error: 'MAC address is required',
      });
      expect(nextFunction).not.toHaveBeenCalled();
    });

    it('should reject invalid MAC address format', () => {
      mockRequest.params = { macAddress: 'invalid-mac' };

      validateMacAddress(
        mockRequest as Request,
        mockResponse as Response,
        nextFunction
      );

      expect(mockResponse.status).toHaveBeenCalledWith(400);
      expect(mockResponse.json).toHaveBeenCalledWith({
        error: 'Invalid MAC address',
      });
      expect(nextFunction).not.toHaveBeenCalled();
    });
  });

  describe('isValidMacAddress', () => {
    it('should validate correct MAC address formats', () => {
      const validMacs = [
        '00:11:22:33:44:55',
        '00-11-22-33-44-55',
        'AA:BB:CC:DD:EE:FF',
        'aa:bb:cc:dd:ee:ff',
      ];

      validMacs.forEach(mac => {
        expect(isValidMacAddress(mac)).toBe(true);
      });
    });

    it('should reject invalid MAC address formats', () => {
      const invalidMacs = [
        '',
        'invalid',
        '00:11:22:33:44',         // Too short
        '00:11:22:33:44:55:66',   // Too long
        '00:11:22:33:44:GG',      // Invalid characters
        '00:11:22:33:44-55',      // Mixed separators
        '0011.2233.4455',         // Wrong separator
        '00:11:22:33:44:',        // Incomplete
      ];

      invalidMacs.forEach(mac => {
        expect(isValidMacAddress(mac)).toBe(false);
      });
    });
  });
}); 