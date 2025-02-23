import rateLimit from 'express-rate-limit';

// Default values
const DEFAULT_WINDOW_MS = 15 * 60 * 1000; // 15 minutes
const DEFAULT_MAX_REQUESTS = 100;

export const createRateLimiter = (
  windowMs: number = DEFAULT_WINDOW_MS,
  maxRequests: number = DEFAULT_MAX_REQUESTS
) => {
  return rateLimit({
    windowMs,
    max: maxRequests,
    message: {
      error: 'Too many requests from this IP, please try again later',
    },
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  });
};

// Common rate limiters
export const defaultLimiter = createRateLimiter();

export const strictLimiter = createRateLimiter(
  5 * 60 * 1000, // 5 minutes
  20 // 20 requests
);

export const networkControlLimiter = createRateLimiter(
  60 * 1000, // 1 minute
  10 // 10 requests
); 