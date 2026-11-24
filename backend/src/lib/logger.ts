import { pino } from "pino";
import { config } from "../config.js";

/** Shared structured logger. Secrets in headers are never written to logs. */
export const logger = pino({
  level: config.LOG_LEVEL,
  redact: {
    paths: [
      "req.headers.authorization",
      "req.headers.cookie",
      'req.headers["stripe-signature"]',
      'req.headers["mock-signature"]',
      "*.client_secret",
      "*.card",
    ],
    censor: "[redacted]",
  },
});
