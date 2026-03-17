import { Pool, PoolClient, QueryResult } from 'pg';
import { Config } from '../config';

let pool: Pool;

export function initPool(config: Config): Pool {
  pool = new Pool({ connectionString: config.database.url });
  return pool;
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
