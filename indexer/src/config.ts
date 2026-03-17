export interface Config {
  database: {
    url: string;
  };
  junglebus: {
    url: string;
    subscriptionId: string;
  };
  network: 'mainnet' | 'testnet' | 'stn';
  server: {
    port: number;
    host: string;
    // SECURITY: CORS whitelist for production
    corsWhitelist?: string[];
  };
  startBlock: number;
  logLevel: string;
}

export function loadConfig(): Config {
  // SECURITY: Parse CORS whitelist from env
  const corsWhitelist = process.env.CORS_WHITELIST
    ? process.env.CORS_WHITELIST.split(',').map(s => s.trim()).filter(Boolean)
    : undefined;

  return {
    database: {
      url: env('DATABASE_URL', 'postgres://locus:locus@localhost:5432/locus_indexer'),
    },
    junglebus: {
      url: env('JUNGLEBUS_URL', 'https://junglebus.gorillapool.io'),
      subscriptionId: env('JUNGLEBUS_SUBSCRIPTION_ID', ''),
    },
    network: env('NETWORK', 'mainnet') as Config['network'],
    server: {
      port: parseInt(env('PORT', '3000'), 10),
      host: env('HOST', '0.0.0.0'),
      corsWhitelist, // SECURITY: Restricted CORS in production
    },
    startBlock: parseInt(env('START_BLOCK', '0'), 10),
    logLevel: env('LOG_LEVEL', 'info'),
  };
}

function env(key: string, fallback: string): string {
  return process.env[key] ?? fallback;
}
