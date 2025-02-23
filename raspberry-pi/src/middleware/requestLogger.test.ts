import { Request, Response, NextFunction } from 'express';
import { Readable } from 'stream';
import { requestLogger } from './requestLogger';
import { http } from '../utils/logger';

// Mock logger
jest.mock('../utils/logger', () => ({
  http: jest.fn(),
  formatRequestLog: jest.fn((req) => `${req.method} ${req.originalUrl} - ${req.ip}`),
}));

describe('Request Logger Middleware', () => {
  let mockRequest: Partial<Request>;
  let mockResponse: Partial<Response>;
  let nextFunction: NextFunction;
  let mockHeaders: { [key: string]: string };

  beforeEach(() => {
    jest.clearAllMocks();
    mockHeaders = {};
    mockRequest = {
      method: 'GET',
      originalUrl: '/test',
      ip: '127.0.0.1',
      get: jest.fn().mockImplementation((name: string) => {
        if (name === 'set-cookie') return undefined;
        return mockHeaders[name];
      }),
    };
    mockResponse = {
      statusCode: 200,
      on: jest.fn().mockImplementation((event: string, listener: any) => {
        if (event === 'finish') {
          setTimeout(listener, 0);
        }
        return mockResponse as Response;
      }),
    };
    nextFunction = jest.fn();
  });

  it('should log request on start', () => {
    requestLogger(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    expect(http).toHaveBeenCalledWith(
      'GET /test - 127.0.0.1'
    );
  });

  it('should call next middleware', () => {
    requestLogger(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    expect(nextFunction).toHaveBeenCalled();
  });

  it('should log response on finish', (done) => {
    // Set up request headers
    mockHeaders['user-agent'] = 'test-agent';
    mockHeaders['referer'] = 'test-referer';

    requestLogger(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    // Reset the mock to check the second call
    (http as jest.Mock).mockClear();

    // The finish event will be triggered by the mock implementation
    setTimeout(() => {
      expect(http).toHaveBeenCalledWith(
        'GET /test - 127.0.0.1 - 200 - 0ms',
        {
          statusCode: 200,
          duration: expect.any(Number),
          userAgent: 'test-agent',
          referer: 'test-referer',
        }
      );
      done();
    }, 10);
  });

  it('should handle missing request headers', (done) => {
    requestLogger(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    (http as jest.Mock).mockClear();

    setTimeout(() => {
      expect(http).toHaveBeenCalledWith(
        'GET /test - 127.0.0.1 - 200 - 0ms',
        {
          statusCode: 200,
          duration: expect.any(Number),
          userAgent: undefined,
          referer: undefined,
        }
      );
      done();
    }, 10);
  });

  it('should handle error responses', (done) => {
    mockResponse.statusCode = 500;

    requestLogger(
      mockRequest as Request,
      mockResponse as Response,
      nextFunction
    );

    (http as jest.Mock).mockClear();

    setTimeout(() => {
      expect(http).toHaveBeenCalledWith(
        'GET /test - 127.0.0.1 - 500 - 0ms',
        expect.objectContaining({
          statusCode: 500,
        })
      );
      done();
    }, 10);
  });
}); 