import express from 'express';
import cors from 'cors';
import citiesRouter from './routes/cities';
import territoriesRouter from './routes/territories';
import objectsRouter from './routes/objects';
import citizensRouter from './routes/citizens';
import governanceRouter from './routes/governance';
import statusRouter from './routes/status';
import { Config } from './config';

export function createApp(config: Config): express.Application {
  const app = express();

  // SECURITY: Restrict CORS in production
  const corsOptions = config.server.corsWhitelist
    ? {
        origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
          // Allow requests with no origin (mobile apps, curl, etc)
          if (!origin) return callback(null, true);
          if (config.server.corsWhitelist?.includes(origin)) {
            return callback(null, true);
          }
          console.warn(`CORS blocked request from: ${origin}`);
          callback(new Error('Not allowed by CORS'));
        },
        credentials: true,
      }
    : { origin: true }; // Allow all in dev (no whitelist set)

  app.use(cors(corsOptions));
  app.use(express.json());

  // Health check
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'locus-indexer' });
  });

  // API routes
  app.use('/api/v1/cities', citiesRouter);
  app.use('/api/v1/territories', territoriesRouter);
  app.use('/api/v1/objects', objectsRouter);
  app.use('/api/v1/citizens', citizensRouter);
  app.use('/api/v1/proposals', governanceRouter);
  app.use('/api/v1/status', statusRouter);

  // Transaction lookup (mounted under status router)
  app.use('/api/v1', statusRouter);

  // 404 handler
  app.use((_req, res) => {
    res.status(404).json({ error: 'Not found' });
  });

  // Error handler
  app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}
