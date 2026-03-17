import { Pool, PoolClient, PoolConfig, QueryResult } from 'pg';
import { Config } from '../config';

let pool: Pool;

export function initPool(config: Config): Pool {
  pool = new Pool(databasePoolConfig(config));
  return pool;
}

export function databasePoolConfig(config: Config): PoolConfig {
  return {
    connectionString: config.database.url,
    ssl: config.database.ssl
      ? {
          rejectUnauthorized: config.database.rejectUnauthorized,
        }
      : undefined,
  };
}

export function getPool(): Pool {
  if (!pool) throw new Error('Database pool not initialized');
  return pool;
}

export async function query(text: string, params?: unknown[]): Promise<QueryResult> {
  return getPool().query(text, params);
}

export async function withTransaction<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
