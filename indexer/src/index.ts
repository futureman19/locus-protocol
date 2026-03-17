import pino from 'pino';
import { loadConfig } from './config';
import { initPool, query, withTransaction } from './db/pool';
import { createApp } from './server';
import { JungleBusScanner } from './scanner/junglebus';
import { dispatch, TxContext } from './handlers/index';
import { ParsedTransaction } from './scanner/parser';

async function main() {
  const config = loadConfig();
  const logger = pino({ level: config.logLevel });

  logger.info('Starting Locus Protocol Indexer');

  // Initialize database
  const pool = initPool(config);

  // Verify database connection
  try {
    await pool.query('SELECT 1');
    logger.info('Database connected');
  } catch (err) {
    logger.fatal({ err }, 'Cannot connect to database');
    process.exit(1);
  }

  // Get last synced block
  const { rows } = await query('SELECT last_block_height FROM sync_state WHERE id = 1');
  const lastBlock = rows.length > 0 ? rows[0].last_block_height : config.startBlock;
  logger.info({ lastBlock }, 'Resuming from block');

  // Start REST API
  const app = createApp(config);
  app.listen(config.server.port, config.server.host, () => {
    logger.info({ port: config.server.port, host: config.server.host }, 'REST API listening');
  });

  // Start blockchain scanner
  const scanner = new JungleBusScanner(
    config,
    {
      onTransaction: async (txid, blockHeight, blockHash, blockTime, parsed: ParsedTransaction) => {
        await withTransaction(async (client) => {
          const ctx: TxContext = {
            txid,
            blockHeight,
            blockHash,
            blockTime,
            client,
            logger,
          };
          await dispatch(ctx, parsed);
        });
        logger.debug({ txid, type: parsed.typeName, block: blockHeight }, 'Transaction indexed');
      },

      onBlockDone: async (blockHeight, blockHash) => {
        await query(
          'UPDATE sync_state SET last_block_height = $1, last_block_hash = $2, updated_at = NOW() WHERE id = 1',
          [blockHeight, blockHash]
        );
      },

      onError: (error) => {
        logger.error({ err: error }, 'Scanner error');
      },
    },
    logger,
  );

  await scanner.start(lastBlock);

  // Graceful shutdown
  const shutdown = async () => {
    logger.info('Shutting down...');
    scanner.stop();
    await pool.end();
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
