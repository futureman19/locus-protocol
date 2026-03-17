import { readFileSync } from 'fs';
import { join } from 'path';
import { Pool } from 'pg';
import { loadConfig } from '../config';
import { databasePoolConfig } from './pool';

async function migrate() {
  const config = loadConfig();
  const pool = new Pool(databasePoolConfig(config));

  try {
    // Create migrations tracking table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    // Read migration files
    const migrationsDir = resolveMigrationsDir();
    const migrationFile = '001_initial.sql';

    const { rows } = await pool.query(
      'SELECT version FROM schema_migrations WHERE version = $1',
      [migrationFile]
    );

    if (rows.length === 0) {
      console.log(`Applying migration: ${migrationFile}`);
      const sql = readFileSync(join(migrationsDir, migrationFile), 'utf8');
      await pool.query(sql);
      await pool.query(
        'INSERT INTO schema_migrations (version) VALUES ($1)',
        [migrationFile]
      );
      console.log(`Migration applied: ${migrationFile}`);
    } else {
      console.log(`Migration already applied: ${migrationFile}`);
    }

    console.log('Migrations complete.');
  } finally {
    await pool.end();
  }
}

function resolveMigrationsDir(): string {
  const candidates = [
    join(__dirname, 'migrations'),
    join(process.cwd(), 'dist', 'db', 'migrations'),
    join(process.cwd(), 'src', 'db', 'migrations'),
  ];

  for (const candidate of candidates) {
    try {
      readFileSync(join(candidate, '001_initial.sql'), 'utf8');
      return candidate;
    } catch (_error) {
      continue;
    }
  }

  throw new Error('Unable to locate SQL migration directory');
}

migrate().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
