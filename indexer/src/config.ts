export interface Config {
  database: {
    url: string;
    ssl: boolean;
    rejectUnauthorized: boolean;
  };
  junglebus: {
    url: string;
    subscriptionId: string;
  };
  network: 'mainnet' | 'testnet' | 'stn';
  server: {
    port: number;
    host: string;
  };
  startBlock: number;
  logLevel: string;
}

export function loadConfig(): Config {
  const runtimeSecret = loadJsonEnv('INDEXER_RUNTIME_SECRET_JSON');
  const database = loadDatabaseConfig();

  return {
    database,
    junglebus: {
      url: env('JUNGLEBUS_URL', secretString(runtimeSecret, 'junglebus_url', 'https://junglebus.gorillapool.io')),
      subscriptionId: env('JUNGLEBUS_SUBSCRIPTION_ID', secretString(runtimeSecret, 'junglebus_subscription_id', '')),
    },
    network: env('NETWORK', 'mainnet') as Config['network'],
    server: {
      port: parseInt(env('PORT', '3000'), 10),
      host: env('HOST', '0.0.0.0'),
    },
    startBlock: parseInt(env('START_BLOCK', '0'), 10),
    logLevel: env('LOG_LEVEL', 'info'),
  };
}

function loadDatabaseConfig(): Config['database'] {
  const databaseSecret = loadJsonEnv('DATABASE_SECRET_JSON');
  const ssl = envBoolean('DATABASE_SSL', false);

  return {
    url:
      process.env.DATABASE_URL ??
      buildDatabaseUrl({
        host: env('DATABASE_HOST', secretString(databaseSecret, 'host', 'localhost')),
        port: envNumber('DATABASE_PORT', secretNumber(databaseSecret, 'port', 5432)),
        name: env('DATABASE_NAME', secretString(databaseSecret, 'dbname', 'locus_indexer')),
        user: env('DATABASE_USER', secretString(databaseSecret, 'username', 'locus')),
        password: env('DATABASE_PASSWORD', secretString(databaseSecret, 'password', 'locus')),
      }),
    ssl,
    rejectUnauthorized: envBoolean('DATABASE_SSL_REJECT_UNAUTHORIZED', true),
  };
}

function buildDatabaseUrl(input: {
  host: string;
  port: number;
  name: string;
  user: string;
  password: string;
}): string {
  const auth = `${encodeURIComponent(input.user)}:${encodeURIComponent(input.password)}`;
  const location = `${input.host}:${input.port}`;
  return `postgres://${auth}@${location}/${input.name}`;
}

function env(key: string, fallback: string): string {
  return process.env[key] ?? fallback;
}

function loadJsonEnv(key: string): Record<string, unknown> {
  const raw = process.env[key];

  if (!raw) {
    return {};
  }

  try {
    const parsed = JSON.parse(raw);
    return typeof parsed === 'object' && parsed !== null ? parsed : {};
  } catch (_error) {
    return {};
  }
}

function secretString(source: Record<string, unknown>, key: string, fallback: string): string {
  const value = source[key];
  return typeof value === 'string' ? value : fallback;
}

function secretNumber(source: Record<string, unknown>, key: string, fallback: number): number {
  const value = source[key];

  if (typeof value === 'number') {
    return value;
  }

  if (typeof value === 'string') {
    const parsed = parseInt(value, 10);
    return Number.isNaN(parsed) ? fallback : parsed;
  }

  return fallback;
}

function envNumber(key: string, fallback: number): number {
  const raw = process.env[key];

  if (!raw) {
    return fallback;
  }

  const parsed = parseInt(raw, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function envBoolean(key: string, fallback: boolean): boolean {
  const raw = process.env[key];

  if (raw === undefined) {
    return fallback;
  }

  return ['1', 'true', 'yes', 'on'].includes(raw.toLowerCase());
}
