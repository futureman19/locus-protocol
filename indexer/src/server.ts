import express from 'express';
import cors from 'cors';
import citiesRouter from './routes/cities';
import territoriesRouter from './routes/territories';
import objectsRouter from './routes/objects';
import citizensRouter from './routes/citizens';
import governanceRouter from './routes/governance';
import statusRouter from './routes/status';

export function createApp(): express.Application {
  const app = express();

  app.use(cors());
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
