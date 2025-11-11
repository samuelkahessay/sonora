import { Request, Response, NextFunction } from 'express';
import { AsyncLocalStorage } from 'async_hooks';
import { randomUUID } from 'crypto';

/**
 * AsyncLocalStorage for correlation ID
 * Provides thread-safe access to the current request's correlation ID
 */
const correlationStorage = new AsyncLocalStorage<string>();

/**
 * Get the current correlation ID from AsyncLocalStorage
 * @returns The correlation ID or undefined if not in request context
 */
export function getCorrelationId(): string | undefined {
  return correlationStorage.getStore();
}

/**
 * Middleware to generate and attach correlation IDs to requests
 * - Reads from x-correlation-id header (if client provides it)
 * - Generates new UUID if not provided
 * - Stores in AsyncLocalStorage for thread-safe access
 * - Adds to response headers for client debugging
 */
export function correlationMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  // Use client-provided correlation ID or generate new one
  const correlationId =
    (req.headers['x-correlation-id'] as string) ||
    (req.headers['x-request-id'] as string) ||
    randomUUID();

  // Store in AsyncLocalStorage for access anywhere in the request lifecycle
  correlationStorage.run(correlationId, () => {
    // Add to response headers so clients can track their requests
    res.setHeader('X-Correlation-ID', correlationId);
    res.setHeader('X-Request-ID', correlationId);

    // Attach to request object for convenience
    (req as any).correlationId = correlationId;

    next();
  });
}

/**
 * Type augmentation for Express Request
 */
declare global {
  namespace Express {
    interface Request {
      correlationId?: string;
    }
  }
}
