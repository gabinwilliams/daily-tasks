import { Request, Response, NextFunction } from 'express';
import { http, formatRequestLog } from '../utils/logger';

export const requestLogger = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Log request
  http(formatRequestLog(req));

  // Get response time
  const start = Date.now();

  // Log response
  res.on('finish', () => {
    const duration = Date.now() - start;
    const { statusCode } = res;
    const level = statusCode >= 400 ? 'error' : 'info';

    http(
      `${formatRequestLog(req)} - ${statusCode} - ${duration}ms`,
      {
        statusCode,
        duration,
        userAgent: req.get('user-agent'),
        referer: req.get('referer'),
      }
    );
  });

  next();
}; 