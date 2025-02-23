import winston from 'winston';
import { Request } from 'express';

// Log levels
const levels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4,
};

// Log level based on environment
const level = () => {
  const env = process.env.NODE_ENV || 'development';
  const isDevelopment = env === 'development';
  return isDevelopment ? 'debug' : 'info';
};

// Log format
const format = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss:ms' }),
  winston.format.printf(
    (info) => `${info.timestamp} ${info.level}: ${info.message}`
  )
);

// Create the logger
const logger = winston.createLogger({
  level: level(),
  levels,
  format,
  transports: [
    // Write logs to console
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),
    // Write logs to file
    new winston.transports.File({
      filename: process.env.LOG_FILE || 'network-controller.log',
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    }),
  ],
});

// Request logging format
export const formatRequestLog = (req: Request): string => {
  const { method, originalUrl, ip } = req;
  return `${method} ${originalUrl} - ${ip}`;
};

// Export logger functions
export const error = (message: string, meta?: any): void => {
  logger.error(message, meta);
};

export const warn = (message: string, meta?: any): void => {
  logger.warn(message, meta);
};

export const info = (message: string, meta?: any): void => {
  logger.info(message, meta);
};

export const http = (message: string, meta?: any): void => {
  logger.http(message, meta);
};

export const debug = (message: string, meta?: any): void => {
  logger.debug(message, meta);
};

// Export logger instance
export default logger; 