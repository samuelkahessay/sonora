import pino from 'pino';
import { getCorrelationId } from '../middleware/correlation.js';

const isDevelopment = process.env.NODE_ENV !== 'production';

/**
 * Pino logger configuration
 * - Structured JSON logs in production
 * - Pretty-printed logs in development
 * - Automatic correlation ID injection
 * - Redaction for sensitive fields
 */
const logger = pino({
  level: process.env.LOG_LEVEL || (isDevelopment ? 'debug' : 'info'),

  // Custom serializers for common objects
  serializers: {
    req: (req: any) => ({
      id: req.id,
      method: req.method,
      url: req.url,
      path: req.path,
      headers: {
        host: req.headers?.host,
        'user-agent': req.headers?.['user-agent'],
        'content-type': req.headers?.['content-type'],
        'x-entitlement-pro': req.headers?.['x-entitlement-pro'],
        // Never log Authorization header
      },
      remoteAddress: req.remoteAddress,
      remotePort: req.remotePort,
    }),

    res: (res: any) => ({
      statusCode: res.statusCode,
      headers: {
        'content-type': res.getHeader?.('content-type'),
        'x-correlation-id': res.getHeader?.('x-correlation-id'),
      },
    }),

    err: pino.stdSerializers.err,
  },

  // Redact sensitive fields
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers["x-api-key"]',
      'req.body.transcript', // Don't log full transcripts (PHI/PII)
      'req.body.historicalContext[*].transcript',
      'openai.apiKey',
      'openrouter.apiKey',
      '*.apiKey',
      '*.password',
      '*.token',
      '*.secret',
    ],
    censor: '[REDACTED]',
  },

  // Base fields included in every log
  base: {
    pid: process.pid,
    hostname: process.env.FLY_REGION || process.env.HOSTNAME || 'local',
  },

  // Pretty printing in development
  transport: isDevelopment
    ? {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'SYS:standard',
          ignore: 'pid,hostname',
          singleLine: false,
        },
      }
    : undefined,

  // Format ISO timestamps in production
  timestamp: pino.stdTimeFunctions.isoTime,

  // Add correlation ID to every log
  mixin: () => {
    const correlationId = getCorrelationId();
    return correlationId ? { correlationId } : {};
  },
});

/**
 * Child logger with additional context
 * @param context Additional context to include in all logs from this logger
 */
export function createChildLogger(context: Record<string, any>) {
  return logger.child(context);
}

/**
 * Log with request context
 * Automatically includes correlation ID and request metadata
 */
export function logWithContext(
  level: 'trace' | 'debug' | 'info' | 'warn' | 'error' | 'fatal',
  message: string,
  data?: Record<string, any>
) {
  const correlationId = getCorrelationId();
  logger[level]({ correlationId, ...data }, message);
}

export default logger;
