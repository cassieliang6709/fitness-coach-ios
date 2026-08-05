import fs from 'node:fs';
import path from 'node:path';

/**
 * Small, dependency-free development record. It deliberately never stores raw
 * PCM or photos; only timestamps, event names and the text returned by the
 * speech/model provider are retained for evaluation.
 */
export class RealtimeTelemetry {
  constructor({ directory = process.env.VANCE_LOG_DIR || 'data', enabled = process.env.VANCE_TELEMETRY !== '0' } = {}) {
    this.enabled = enabled;
    this.file = path.join(directory, 'realtime-events.jsonl');
    if (this.enabled) fs.mkdirSync(directory, { recursive: true });
  }

  event({ conversationId, connectionId, name, at = Date.now(), details = {} }) {
    if (!this.enabled) return;
    const record = {
      at: new Date(at).toISOString(),
      conversationId,
      connectionId,
      name,
      ...details,
    };
    fs.appendFile(this.file, `${JSON.stringify(record)}\n`, () => {});
  }
}
