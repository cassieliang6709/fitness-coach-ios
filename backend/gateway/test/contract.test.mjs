import assert from 'node:assert/strict';
import test from 'node:test';
import { buildVancePrompt, VANCE_PROMPT_VERSION } from '../coach-prompt.mjs';
import { assembleMessage, readFrames, writeFrame } from '../websocket-frames.mjs';

test('Vance prompt includes server-owned context and safety contract', () => {
  const prompt = buildVancePrompt({
    style: 'practical',
    state: { phase: 'strength', exercise: '高脚杯深蹲', prescription: '4 × 12' },
    memories: ['膝盖偶尔不适'],
  });
  assert.equal(VANCE_PROMPT_VERSION, 'v1');
  assert.match(prompt, /高脚杯深蹲/);
  assert.match(prompt, /膝盖偶尔不适/);
  assert.match(prompt, /疼痛、头晕、胸闷/);
});

test('websocket continuation frames are reassembled before JSON parsing', () => {
  const fragments = { opcode: null, chunks: [] };
  assert.equal(assembleMessage({ fin: false, opcode: 0x1, payload: Buffer.from('{"type":') }, fragments), null);

  const ping = assembleMessage({ fin: true, opcode: 0x9, payload: Buffer.from('ping') }, fragments);
  assert.equal(ping.opcode, 0x9);

  const message = assembleMessage({ fin: true, opcode: 0x0, payload: Buffer.from('"input_audio_buffer.commit"}') }, fragments);
  assert.equal(message.opcode, 0x1);
  assert.deepEqual(JSON.parse(message.payload.toString('utf8')), { type: 'input_audio_buffer.commit' });
  assert.deepEqual(fragments, { opcode: null, chunks: [] });
});

test('frame codec preserves FIN, mask and payload', () => {
  const encoded = writeFrame(Buffer.from('voice'), 0x1, true);
  const decoded = readFrames(encoded, true);
  assert.equal(decoded.frames.length, 1);
  assert.equal(decoded.frames[0].fin, true);
  assert.equal(decoded.frames[0].opcode, 0x1);
  assert.equal(decoded.frames[0].payload.toString('utf8'), 'voice');
  assert.equal(decoded.rest.length, 0);
});

test('frame codec rejects an unmasked client frame', () => {
  const serverFrame = writeFrame(Buffer.from('voice'), 0x1, false);
  assert.throws(() => readFrames(serverFrame, true), /Unexpected WebSocket mask/);
});
