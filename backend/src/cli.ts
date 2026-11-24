/**
 * Operational commands:
 *   node dist/cli.js migrate          apply pending SQL migrations
 *   node dist/cli.js seed [--reset-stock]   import the catalogue
 *   node dist/cli.js setup            migrate, then seed if the catalogue is empty
 */
import { migrate } from "./db/migrate.js";
import { seedCatalogue, seedIfEmpty } from "./db/seed.js";
import { pool } from "./db/pool.js";
import { logger } from "./lib/logger.js";
import { redis } from "./lib/redis.js";
import { invalidateNamespace } from "./lib/cache.js";

const [command, ...flags] = process.argv.slice(2);

async function main() {
  switch (command) {
    case "migrate":
      await migrate();
      break;
    case "seed":
      await seedCatalogue({ resetStock: flags.includes("--reset-stock") });
      await invalidateNamespace("catalog");
      break;
    case "setup":
      await migrate();
      await seedIfEmpty();
      break;
    default:
      throw new Error(`Unknown command "${command}". Use migrate, seed or setup.`);
  }
}

main()
  .then(() => Promise.all([pool.end(), redis.quit()]))
  .catch(async (err) => {
    logger.error({ err }, `${command} failed`);
    await Promise.allSettled([pool.end(), redis.quit()]);
    process.exit(1);
  });
