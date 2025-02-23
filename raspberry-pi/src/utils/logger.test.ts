import winston from 'winston';
import logger, { formatRequestLog, error, warn, info, http, debug } from './logger';

// Mock winston
jest.mock('winston', () => ({
  format: {
    combine: jest.fn(),
    timestamp: jest.fn(),
    printf: jest.fn(),
    colorize: jest.fn(),
    simple: jest.fn(),
  },
  createLogger: jest.fn(() => ({
    error: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
    http: jest.fn(),
    debug: jest.fn(),
  })),
  transports: {
    Console: jest.fn(),
    File: jest.fn(),
  },
}));

describe('Logger', () => {
  const mockLogger = winston.createLogger();

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('formatRequestLog', () => {
    it('should format request log correctly', () => {
      const mockRequest = {
        method: 'GET',
        originalUrl: '/test',
        ip: '127.0.0.1',
      };

      const result = formatRequestLog(mockRequest as any);
      expect(result).toBe('GET /test - 127.0.0.1');
    });
  });

  describe('logging functions', () => {
    it('should call error with correct parameters', () => {
      const message = 'Error message';
      const meta = { details: 'error details' };

      error(message, meta);
      expect(mockLogger.error).toHaveBeenCalledWith(message, meta);
    });

    it('should call warn with correct parameters', () => {
      const message = 'Warning message';
      const meta = { details: 'warning details' };

      warn(message, meta);
      expect(mockLogger.warn).toHaveBeenCalledWith(message, meta);
    });

    it('should call info with correct parameters', () => {
      const message = 'Info message';
      const meta = { details: 'info details' };

      info(message, meta);
      expect(mockLogger.info).toHaveBeenCalledWith(message, meta);
    });

    it('should call http with correct parameters', () => {
      const message = 'HTTP message';
      const meta = { details: 'http details' };

      http(message, meta);
      expect(mockLogger.http).toHaveBeenCalledWith(message, meta);
    });

    it('should call debug with correct parameters', () => {
      const message = 'Debug message';
      const meta = { details: 'debug details' };

      debug(message, meta);
      expect(mockLogger.debug).toHaveBeenCalledWith(message, meta);
    });
  });

  describe('logger configuration', () => {
    it('should create logger with correct configuration', () => {
      expect(winston.createLogger).toHaveBeenCalledWith(
        expect.objectContaining({
          levels: {
            error: 0,
            warn: 1,
            info: 2,
            http: 3,
            debug: 4,
          },
        })
      );
    });

    it('should configure console transport', () => {
      expect(winston.transports.Console).toHaveBeenCalledWith(
        expect.objectContaining({
          format: expect.any(Object),
        })
      );
    });

    it('should configure file transport', () => {
      expect(winston.transports.File).toHaveBeenCalledWith(
        expect.objectContaining({
          filename: expect.any(String),
          maxsize: 5242880,
          maxFiles: 5,
        })
      );
    });
  });

  describe('environment-based configuration', () => {
    const originalEnv = process.env;

    beforeEach(() => {
      jest.resetModules();
      process.env = { ...originalEnv };
    });

    afterAll(() => {
      process.env = originalEnv;
    });

    it('should use debug level in development', () => {
      process.env.NODE_ENV = 'development';
      jest.isolateModules(() => {
        require('./logger');
        expect(winston.createLogger).toHaveBeenCalledWith(
          expect.objectContaining({
            level: 'debug',
          })
        );
      });
    });

    it('should use info level in production', () => {
      process.env.NODE_ENV = 'production';
      jest.isolateModules(() => {
        require('./logger');
        expect(winston.createLogger).toHaveBeenCalledWith(
          expect.objectContaining({
            level: 'info',
          })
        );
      });
    });

    it('should use custom log file path when specified', () => {
      process.env.LOG_FILE = '/custom/path/app.log';
      jest.isolateModules(() => {
        require('./logger');
        expect(winston.transports.File).toHaveBeenCalledWith(
          expect.objectContaining({
            filename: '/custom/path/app.log',
          })
        );
      });
    });
  });
}); 