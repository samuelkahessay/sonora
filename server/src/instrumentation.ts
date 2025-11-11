/**
 * Sentry Instrumentation
 *
 * IMPORTANT: This file must be imported FIRST in server.ts for proper ESM initialization.
 * Sentry requires early initialization to properly instrument all code.
 */

import * as Sentry from '@sentry/node';
import { nodeProfilingIntegration } from '@sentry/profiling-node';
import { getCorrelationId } from './middleware/correlation.js';

/**
 * Initialize Sentry with configuration
 * Only initializes if SENTRY_DSN is provided in environment variables
 */
const dsn = process.env.SENTRY_DSN;

if (dsn) {
  Sentry.init({
    dsn,

    // Environment detection from NODE_ENV
    environment: process.env.NODE_ENV || 'development',

    // Release tracking (use git commit SHA if available)
    release: process.env.GIT_COMMIT || process.env.FLY_APP_NAME
      ? `${process.env.FLY_APP_NAME}@${process.env.GIT_COMMIT || 'unknown'}`
      : undefined,

    // Performance Monitoring - 100% tracing in all environments
    tracesSampleRate: 1.0,

    // Profiling integration for performance insights
    integrations: [
      nodeProfilingIntegration(),
    ],

    // Profile sample rate - 100% of traced transactions
    profilesSampleRate: 1.0,

    // Send default PII (IP addresses, user agent)
    sendDefaultPii: false, // We'll manually control what we send

    // Before sending events, add correlation ID and redact sensitive data
    beforeSend(event, hint) {
      // Add correlation ID as tag for request tracing
      const correlationId = getCorrelationId();
      if (correlationId) {
        event.tags = event.tags || {};
        event.tags.correlation_id = correlationId;

        event.contexts = event.contexts || {};
        event.contexts.correlation = {
          correlation_id: correlationId,
        };
      }

      // Redact sensitive data (matching Pino redaction patterns)
      if (event.request) {
        // Redact authorization headers
        if (event.request.headers) {
          event.request.headers = {
            ...event.request.headers,
            authorization: '[Redacted]',
            'x-api-key': '[Redacted]',
          };
        }

        // Redact sensitive query parameters
        if (event.request.query_string && typeof event.request.query_string === 'string') {
          const redactedParams = ['api_key', 'token', 'apiKey'];
          let queryString = event.request.query_string;
          redactedParams.forEach(param => {
            if (queryString.includes(param)) {
              queryString = queryString.replace(
                new RegExp(`${param}=[^&]*`, 'g'),
                `${param}=[Redacted]`
              );
            }
          });
          event.request.query_string = queryString;
        }
      }

      // Redact sensitive data from extra context
      if (event.extra) {
        const sensitiveKeys = [
          'transcript',
          'audio',
          'audioData',
          'apiKey',
          'api_key',
          'openaiApiKey',
          'OPENAI_API_KEY',
        ];

        sensitiveKeys.forEach(key => {
          if (event.extra && key in event.extra) {
            event.extra[key] = '[Redacted]';
          }
        });
      }

      // Redact from breadcrumbs
      if (event.breadcrumbs) {
        event.breadcrumbs = event.breadcrumbs.map(breadcrumb => {
          if (breadcrumb.data) {
            const redacted = { ...breadcrumb.data };
            ['transcript', 'audio', 'audioData', 'apiKey'].forEach(key => {
              if (key in redacted) {
                redacted[key] = '[Redacted]';
              }
            });
            return { ...breadcrumb, data: redacted };
          }
          return breadcrumb;
        });
      }

      return event;
    },

    // Before sending transactions (performance data)
    beforeSendTransaction(event) {
      // Add correlation ID to transactions
      const correlationId = getCorrelationId();
      if (correlationId) {
        event.tags = event.tags || {};
        event.tags.correlation_id = correlationId;
      }

      return event;
    },
  });

  console.log(`[Sentry] Initialized in ${process.env.NODE_ENV || 'development'} mode with 100% tracing`);
} else {
  console.log('[Sentry] SENTRY_DSN not found, skipping initialization');
}

// Export Sentry for use in error handlers
export { Sentry };
