/**
 * Pino-Sentry Bridge
 *
 * Custom Pino transport that sends logs as Sentry breadcrumbs
 * This provides context when errors occur in Sentry
 */

import { Sentry } from '../instrumentation.js';
import type { SeverityLevel } from '@sentry/node';

/**
 * Map Pino log levels to Sentry severity levels
 */
function mapPinoLevelToSentry(level: number): SeverityLevel {
  // Pino levels: trace=10, debug=20, info=30, warn=40, error=50, fatal=60
  if (level >= 60) return 'fatal';
  if (level >= 50) return 'error';
  if (level >= 40) return 'warning';
  if (level >= 30) return 'info';
  if (level >= 20) return 'debug';
  return 'debug';
}

/**
 * Add a Pino log as a Sentry breadcrumb
 * @param logObj The Pino log object
 */
export function addLogAsBreadcrumb(logObj: any): void {
  // Skip if Sentry is not initialized
  if (!process.env.SENTRY_DSN) {
    return;
  }

  try {
    // Only send info and above to Sentry (filter out debug/trace)
    if (logObj.level < 30) {
      return;
    }

    // Extract relevant data from log object
    const { level, msg, time, correlationId, error, ...data } = logObj;

    // Remove internal Pino fields
    const cleanData: Record<string, any> = {};
    for (const [key, value] of Object.entries(data)) {
      // Skip internal Pino fields
      if (['pid', 'hostname', 'v'].includes(key)) {
        continue;
      }
      cleanData[key] = value;
    }

    // Add breadcrumb to Sentry
    Sentry.addBreadcrumb({
      type: error ? 'error' : 'default',
      category: 'log',
      level: mapPinoLevelToSentry(level),
      message: msg || 'Log entry',
      data: {
        ...cleanData,
        ...(correlationId && { correlation_id: correlationId }),
        timestamp: time ? new Date(time).toISOString() : undefined,
      },
    });

    // If this is an error log, also capture it as an exception
    if (error && level >= 50) {
      const errorObj = error instanceof Error ? error : new Error(String(error));
      Sentry.captureException(errorObj, {
        level: mapPinoLevelToSentry(level),
        tags: {
          source: 'pino',
          ...(correlationId && { correlation_id: correlationId }),
        },
        extra: cleanData,
      });
    }
  } catch (err) {
    // Silently fail - don't break logging if Sentry has issues
    console.error('Failed to add Sentry breadcrumb:', err);
  }
}

/**
 * Hook to integrate with Pino logger
 * Call this function for each log to send it to Sentry
 */
export function createSentryHook() {
  return (logObj: any, level: number) => {
    addLogAsBreadcrumb(logObj);
  };
}
