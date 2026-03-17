import EventSource from 'eventsource';
import { Config } from '../config';
import { parseHexScript, ParsedTransaction } from './parser';
import { Logger } from 'pino';

export interface JungleBusTransaction {
  id: string;             // txid
  block_hash: string;
  block_height: number;
  block_time: number;     // unix timestamp
  transaction: string;    // raw tx hex (optional, depends on subscription)
  outputs?: string[];     // hex-encoded output scripts
}

export interface ScannerCallbacks {
  onTransaction: (txid: string, blockHeight: number, blockHash: string, blockTime: number, parsed: ParsedTransaction) => Promise<void>;
  onBlockDone: (blockHeight: number, blockHash: string) => Promise<void>;
  onError: (error: Error) => void;
}

export class JungleBusScanner {
  private es: EventSource | null = null;
  private running = false;

  constructor(
    private config: Config,
    private callbacks: ScannerCallbacks,
    private logger: Logger,
  ) {}

  /**
   * Start streaming from JungleBus using Server-Sent Events.
   * JungleBus SSE endpoint filters by OP_RETURN prefix.
   */
  async start(fromBlock: number): Promise<void> {
    this.running = true;

    // JungleBus subscription endpoint with LOCUS filter
    const subId = this.config.junglebus.subscriptionId;
    if (!subId) {
      this.logger.warn('No JUNGLEBUS_SUBSCRIPTION_ID configured — scanner will not start');
      this.logger.info('Create a subscription at junglebus.gorillapool.io filtering for "LOCUS" OP_RETURN prefix');
      return;
    }

    const url = `${this.config.junglebus.url}/v1/subscription/stream/${subId}?from_block=${fromBlock}`;
    this.logger.info({ url, fromBlock }, 'Connecting to JungleBus');

    this.es = new EventSource(url);

    this.es.addEventListener('transaction', async (event: MessageEvent) => {
      try {
        const tx: JungleBusTransaction = JSON.parse(event.data);
        await this.handleTransaction(tx);
      } catch (err) {
        this.callbacks.onError(err as Error);
      }
    });

    this.es.addEventListener('block_done', async (event: MessageEvent) => {
      try {
        const data = JSON.parse(event.data);
        await this.callbacks.onBlockDone(data.block_height, data.block_hash);
        this.logger.debug({ block: data.block_height }, 'Block processed');
      } catch (err) {
        this.callbacks.onError(err as Error);
      }
    });

    this.es.addEventListener('error', (event: MessageEvent) => {
      if (!this.running) return;
      this.logger.error({ event }, 'JungleBus connection error');
      // EventSource auto-reconnects
    });

    this.es.addEventListener('control', (event: MessageEvent) => {
      const data = JSON.parse(event.data);
      if (data.status === 'complete') {
        this.logger.info('JungleBus historical sync complete, watching for new blocks');
      }
    });
  }

  stop(): void {
    this.running = false;
    if (this.es) {
      this.es.close();
      this.es = null;
    }
    this.logger.info('Scanner stopped');
  }

  private async handleTransaction(tx: JungleBusTransaction): Promise<void> {
    // JungleBus provides transaction outputs — try to parse each for LOCUS prefix
    // If outputs are provided directly, use them
    if (tx.outputs && tx.outputs.length > 0) {
      for (const outputHex of tx.outputs) {
        const parsed = parseHexScript(outputHex);
        if (parsed) {
          await this.callbacks.onTransaction(
            tx.id,
            tx.block_height,
            tx.block_hash,
            tx.block_time,
            parsed,
          );
          return;
        }
      }
    }

    // Fallback: if raw transaction hex is provided, extract OP_RETURN outputs
    if (tx.transaction) {
      const parsed = this.extractFromRawTx(tx.transaction);
      if (parsed) {
        await this.callbacks.onTransaction(
          tx.id,
          tx.block_height,
          tx.block_hash,
          tx.block_time,
          parsed,
        );
      }
    }
  }

  /**
   * Simple extraction of OP_RETURN scripts from raw transaction hex.
   * Scans for OP_RETURN (0x6a) followed by LOCUS prefix.
   */
  private extractFromRawTx(rawHex: string): ParsedTransaction | null {
    const buf = Buffer.from(rawHex, 'hex');
    const locusBytes = Buffer.from('LOCUS', 'utf8');

    // Scan for "LOCUS" in the raw tx — rough but effective for OP_RETURN extraction
    for (let i = 0; i < buf.length - locusBytes.length; i++) {
      if (buf.subarray(i, i + locusBytes.length).equals(locusBytes)) {
        // Walk back to find OP_RETURN
        for (let j = i - 1; j >= Math.max(0, i - 10); j--) {
          if (buf[j] === 0x6a) {
            const scriptBuf = buf.subarray(j);
            const parsed = parseHexScript(scriptBuf.toString('hex'));
            if (parsed) return parsed;
          }
        }
      }
    }
    return null;
  }
}
