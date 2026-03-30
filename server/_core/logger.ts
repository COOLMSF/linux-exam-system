import fs from 'fs';
import path from 'path';

// Get current directory in ES module scope
const __filename = new URL(import.meta.url).pathname;
const __dirname = path.dirname(__filename);

const LOG_DIR = path.join(__dirname, '../../logs');


// Ensure log directory exists
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

/**
 * Simple logger utility for the exam system
 */
export const logger = {
  /**
   * Log an info message
   * @param message The message to log
   * @param context Optional context object
   */
  info(message: string, context?: Record<string, any>) {
    this.log('INFO', message, context);
  },

  /**
   * Log an error message
   * @param message The error message to log
   * @param error Optional error object
   * @param context Optional context object
   */
  error(message: string, error?: any, context?: Record<string, any>) {
    this.log('ERROR', message, { ...context, error: error?.message || String(error) });
  },

  /**
   * Log a debug message
   * @param message The debug message to log
   * @param context Optional context object
   */
  debug(message: string, context?: Record<string, any>) {
    this.log('DEBUG', message, context);
  },

  /**
   * Internal log method
   * @param level Log level
   * @param message Log message
   * @param context Optional context
   */
  log(level: string, message: string, context?: Record<string, any>) {
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      level,
      message,
      context,
    };

    // Log to console
    console.log(`${timestamp} [${level}] ${message}`, context ? JSON.stringify(context) : '');

    // Log to file
    const logFilePath = path.join(LOG_DIR, `${new Date().toISOString().split('T')[0]}.log`);
    fs.appendFileSync(logFilePath, JSON.stringify(logEntry) + '\n');
  },
};
