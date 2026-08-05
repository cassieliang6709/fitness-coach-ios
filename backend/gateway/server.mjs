import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import tls from 'node:tls';
import { buildVancePrompt, VANCE_PROMPT_VERSION } from './coach-prompt.mjs';
import { createKimiGymVisionRequest, parseGymVisionResponse, validateGymVisionInput } from './gym-vision.mjs';
import { RealtimeTelemetry } from './telemetry.mjs';
import { assembleMessage, readFrames, writeFrame } from './websocket-frames.mjs';

loadEnv('.env');

const minimaxKey = process.env.MINIMAX_API_KEY;
const kimiKey = process.env.KIMI_API_KEY;
const sharedSecret = process.env.VANCE_GATEWAY_SHARED_SECRET;
const deepseekProxySecret = process.env.DEEPSEEK_PROXY_SECRET;
const port = Number(process.env.PORT || 8787);
const bindHost = process.env.BIND_HOST || '127.0.0.1';
const upstreamHost = 'api.minimax.chat';
const upstreamPath = '/ws/v1/realtime?model=abab6.5s-chat';
const voices = new Set(['male-qn-jingying', 'Chinese (Mandarin)_News_Anchor']);
const telemetry = new RealtimeTelemetry();

if (!minimaxKey) {
  console.error('MINIMAX_API_KEY is missing. Copy .env.example to .env and configure a local key.');
  process.exit(1);
}
if (!sharedSecret) {
  console.error('VANCE_GATEWAY_SHARED_SECRET is missing. The Gateway does not start unauthenticated.');
  process.exit(1);
}

const server = http.createServer((request, response) => {
  handleRequest(request, response).catch(error => {
    const status = /图片|请求体|JSON|Kimi 返回|仅支持|过大/.test(error.message) ? 400 : 502;
    sendJson(response, status, { error: error.message || 'gateway_error' });
  });
});

server.on('upgrade', (request, socket) => {
  const url = new URL(request.url, `http://${request.headers.host}`);
  if (url.pathname !== '/realtime' || !authorized(request)) {
    socket.write('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n');
    socket.destroy();
    return;
  }
  const clientKey = request.headers['sec-websocket-key'];
  if (typeof clientKey !== 'string') return socket.destroy();
  socket.write([
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: Upgrade',
    `Sec-WebSocket-Accept: ${webSocketAccept(clientKey)}`,
    '',
    '',
  ].join('\r\n'));
  connectRealtime(socket, url.searchParams.get('conversationId'));
});

server.listen(port, bindHost, () => {
  console.log(`Vance Gateway: http://${bindHost}:${port}`);
});

async function handleRequest(request, response) {
  const url = new URL(request.url, `http://${request.headers.host}`);
  if (url.pathname === '/health' && request.method === 'GET') {
    if (!authorized(request)) return sendJson(response, 401, { error: 'unauthorized' });
    return sendJson(response, 200, {
      ok: true,
      promptVersion: VANCE_PROMPT_VERSION,
      minimaxConfigured: Boolean(minimaxKey),
      kimiConfigured: Boolean(kimiKey),
    });
  }
  if (url.pathname === '/internal/deepseek' && request.method === 'POST') {
    if (!internalAuthorized(request)) return sendJson(response, 401, { error: 'unauthorized' });
    if (!process.env.DEEPSEEK_API_KEY) return sendJson(response, 503, { error: 'deepseek_not_configured' });
    const body = await readJson(request, 512 * 1024);
    const upstream = await fetch('https://api.deepseek.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${process.env.DEEPSEEK_API_KEY}`,
      },
      body: JSON.stringify(body),
    });
    const contentType = upstream.headers.get('content-type') || 'application/json; charset=utf-8';
    response.writeHead(upstream.status, { 'content-type': contentType, 'cache-control': 'no-store' });
    response.end(await upstream.text());
    return;
  }
  if (url.pathname === '/api/gym-vision' && request.method === 'POST') {
    if (!authorized(request)) return sendJson(response, 401, { error: 'unauthorized' });
    if (!kimiKey) return sendJson(response, 503, { error: 'KIMI_API_KEY 未配置' });
    const input = validateGymVisionInput(await readJson(request, 12 * 1024 * 1024));
    const upstream = await fetch('https://api.moonshot.cn/v1/chat/completions', {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${kimiKey}` },
      body: JSON.stringify(createKimiGymVisionRequest({ ...input })),
    });
    if (!upstream.ok) throw new Error(`Kimi 识别暂时不可用（HTTP ${upstream.status}）`);
    const result = parseGymVisionResponse((await upstream.json()).choices?.[0]?.message?.content);
    return sendJson(response, 200, result);
  }
  if (url.pathname === '/api/evaluations/annotation' && request.method === 'POST') {
    if (!authorized(request)) return sendJson(response, 401, { error: 'unauthorized' });
    const annotation = validateAnnotation(await readJson(request, 16 * 1024));
    telemetry.event({
      conversationId: annotation.conversationId,
      connectionId: 'manual-annotation',
      name: 'evaluation.annotation',
      details: { rating: annotation.rating, note: annotation.note },
    });
    return sendJson(response, 202, { accepted: true });
  }
  sendJson(response, 404, { error: 'not_found' });
}

function authorized(request) {
  if (!sharedSecret) return true;
  const header = request.headers.authorization || '';
  const candidate = header.startsWith('Bearer ') ? header.slice(7) : '';
  const expected = Buffer.from(sharedSecret);
  const actual = Buffer.from(candidate);
  return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
}

function internalAuthorized(request) {
  const candidate = request.headers['x-vance-internal-key'];
  if (!deepseekProxySecret || typeof candidate !== 'string') return false;
  const expected = Buffer.from(deepseekProxySecret);
  const actual = Buffer.from(candidate);
  return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
}

function connectRealtime(localSocket, suppliedConversationId) {
  const conversationId = validConversationId(suppliedConversationId) ? suppliedConversationId : crypto.randomUUID();
  const state = {
    localSocket,
    upstream: null,
    upstreamReady: false,
    queued: [],
    closed: false,
    audioChunks: 0,
    conversationId,
    connectionId: crypto.randomUUID(),
    turn: null,
    localFragments: { opcode: null, chunks: [] },
    upstreamFragments: { opcode: null, chunks: [] },
  };
  record(state, 'connection.open');
  let localBuffer = Buffer.alloc(0);
  localSocket.on('data', chunk => {
    try {
      localBuffer = Buffer.concat([localBuffer, chunk]);
      const parsed = readFrames(localBuffer, true);
      localBuffer = parsed.rest;
      for (const rawFrame of parsed.frames) {
        const frame = assembleMessage(rawFrame, state.localFragments);
        if (!frame) continue;
        if (frame.opcode === 0x8) return close(state);
        if (frame.opcode === 0x9) localSocket.write(writeFrame(frame.payload, 0xA, false));
        if (frame.opcode === 0x1 || frame.opcode === 0x2) forwardClientFrame(state, frame);
      }
    } catch {
      sendSocketError(state, '无效的 WebSocket 帧');
      close(state);
    }
  });
  localSocket.on('error', () => close(state));
  localSocket.on('close', () => close(state));
  connectUpstream(state);
}

function connectUpstream(state) {
  const upstream = tls.connect({ host: upstreamHost, port: 443, servername: upstreamHost });
  state.upstream = upstream;
  let handshake = Buffer.alloc(0);
  let upstreamBuffer = Buffer.alloc(0);
  upstream.once('secureConnect', () => {
    const key = crypto.randomBytes(16).toString('base64');
    upstream.write([
      `GET ${upstreamPath} HTTP/1.1`,
      `Host: ${upstreamHost}`,
      'Upgrade: websocket',
      'Connection: Upgrade',
      `Sec-WebSocket-Key: ${key}`,
      'Sec-WebSocket-Version: 13',
      `Authorization: Bearer ${minimaxKey}`,
      '',
      '',
    ].join('\r\n'));
  });
  upstream.on('data', chunk => {
    if (!state.upstreamReady) {
      handshake = Buffer.concat([handshake, chunk]);
      const boundary = handshake.indexOf('\r\n\r\n');
      if (boundary === -1) return;
      const header = handshake.subarray(0, boundary).toString('utf8');
      const rest = handshake.subarray(boundary + 4);
      if (!header.startsWith('HTTP/1.1 101')) {
        sendSocketError(state, `MiniMax 连接失败：${header.split('\r\n')[0]}`);
        return close(state);
      }
      state.upstreamReady = true;
      for (const frame of state.queued) upstream.write(writeFrame(frame.payload, frame.opcode, true));
      state.queued.length = 0;
      if (!rest.length) return;
      chunk = rest;
    }
    upstreamBuffer = Buffer.concat([upstreamBuffer, chunk]);
    const parsed = readFrames(upstreamBuffer, false);
    upstreamBuffer = parsed.rest;
    for (const rawFrame of parsed.frames) {
      const frame = assembleMessage(rawFrame, state.upstreamFragments);
      if (!frame) continue;
      if (frame.opcode === 0x8) return close(state);
      if (frame.opcode === 0x9) upstream.write(writeFrame(frame.payload, 0xA, true));
      if (frame.opcode === 0x1 || frame.opcode === 0x2) forwardUpstreamFrame(state, frame);
    }
  });
  upstream.on('error', error => { sendSocketError(state, `MiniMax 网络异常：${error.message}`); close(state); });
  upstream.on('close', () => close(state));
}

function forwardClientFrame(state, frame) {
  if (state.closed) return;
  let event = null;
  if (frame.opcode === 0x1) {
    try { event = JSON.parse(frame.payload.toString('utf8')); } catch { return sendSocketError(state, '无效的 WebSocket JSON 事件'); }
  }
  if (event?.type === 'client.vad') {
    record(state, 'client.vad', { state: event.state, rmsDb: finiteNumber(event.rmsDb) });
    return;
  }
  if (event?.type === 'vance.session.configure') {
    const session = event.session && typeof event.session === 'object' ? event.session : {};
    frame = { opcode: 0x1, payload: Buffer.from(JSON.stringify({
      type: 'session.update',
      session: {
        modalities: ['text', 'audio'],
        instructions: buildVancePrompt({ style: session.style, state: session.state, memories: session.memories }),
        voice: voices.has(session.voiceId) ? session.voiceId : 'male-qn-jingying',
        input_audio_format: 'pcm16',
        output_audio_format: 'pcm16',
        temperature: 0.6,
      },
    })) };
  } else if (event?.type === 'input_audio_buffer.append') {
    if (typeof event.audio !== 'string' || !event.audio.length) return;
    state.audioChunks += 1;
    if (state.audioChunks === 1) record(state, 'input_audio_buffer.first_append');
  } else if (event?.type === 'input_audio_buffer.commit') {
    if (!state.audioChunks) return sendSocketError(state, '未检测到有效语音，请按住至少半秒后再松开。');
    state.audioChunks = 0;
    state.turn = { committedAt: Date.now(), firstTextAt: null, firstAudioAt: null };
    record(state, 'input_audio_buffer.commit');
  } else if (event?.type === 'input_audio_buffer.clear') {
    state.audioChunks = 0;
  }
  if (state.upstreamReady) state.upstream.write(writeFrame(frame.payload, frame.opcode, true));
  else state.queued.push(frame);
}

function close(state) {
  if (state.closed) return;
  state.closed = true;
  record(state, 'connection.close');
  state.upstream?.destroy();
  state.localSocket.destroy();
}

function sendSocketError(state, message) {
  record(state, 'error', { message });
  if (!state.localSocket.destroyed) state.localSocket.write(writeFrame(Buffer.from(JSON.stringify({ type: 'error', error: { message } })), 0x1, false));
}

function forwardUpstreamFrame(state, frame) {
  if (frame.opcode === 0x1) {
    try { recordUpstreamEvent(state, JSON.parse(frame.payload.toString('utf8'))); } catch { /* upstream frame still passes through */ }
  }
  state.localSocket.write(writeFrame(frame.payload, frame.opcode, false));
}

function recordUpstreamEvent(state, event) {
  const type = event?.type;
  if (!type) return;
  const turn = state.turn;
  const now = Date.now();
  if (type === 'response.text.delta' && !turn?.firstTextAt) {
    turn.firstTextAt = now;
    record(state, 'response.first_text', { latencyMs: now - turn.committedAt });
  }
  if (type === 'response.audio.delta' && !turn?.firstAudioAt) {
    turn.firstAudioAt = now;
    record(state, 'response.first_audio', { latencyMs: now - turn.committedAt });
  }
  if (type === 'conversation.item.input_audio_transcription.completed') {
    record(state, 'transcript.user', { text: compactText(event.transcript) });
  }
  if (type === 'response.audio_transcript.done' || type === 'response.text.done') {
    record(state, 'transcript.assistant', { text: compactText(event.transcript ?? event.text) });
  }
  if (type === 'response.done') {
    record(state, 'response.done', {
      latencyMs: turn?.committedAt ? now - turn.committedAt : undefined,
      firstTextLatencyMs: turn?.firstTextAt && turn.committedAt ? turn.firstTextAt - turn.committedAt : undefined,
      firstAudioLatencyMs: turn?.firstAudioAt && turn.committedAt ? turn.firstAudioAt - turn.committedAt : undefined,
    });
    state.turn = null;
  }
}

function record(state, name, details = {}) {
  telemetry.event({ conversationId: state.conversationId, connectionId: state.connectionId, name, details });
}

function validConversationId(value) {
  return typeof value === 'string' && value.length > 0 && value.length <= 128 && /^[A-Za-z0-9._-]+$/.test(value);
}

function compactText(value) {
  return typeof value === 'string' ? value.slice(0, 2_000) : undefined;
}

function finiteNumber(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function validateAnnotation(body) {
  if (!validConversationId(body?.conversationId)) throw new Error('conversationId 无效');
  const rating = typeof body.rating === 'string' ? body.rating.slice(0, 40) : '';
  if (!rating) throw new Error('rating 必填');
  const note = typeof body.note === 'string' ? body.note.replace(/\s+/g, ' ').trim().slice(0, 2_000) : '';
  return { conversationId: body.conversationId, rating, note };
}

function sendJson(response, status, body) {
  response.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
  response.end(JSON.stringify(body));
}

function readJson(request, maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let received = 0;
    request.on('data', chunk => {
      received += chunk.length;
      if (received > maxBytes) return reject(new Error('请求体过大'));
      chunks.push(chunk);
    });
    request.on('error', reject);
    request.on('end', () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')); } catch { reject(new Error('无效 JSON')); }
    });
  });
}

function loadEnv(filename) {
  if (!fs.existsSync(filename)) return;
  try {
    for (const line of fs.readFileSync(filename, 'utf8').split(/\r?\n/)) {
      const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (match && !process.env[match[1]]) process.env[match[1]] = match[2].replace(/^['"]|['"]$/g, '');
    }
  } catch { /* .env is optional in deployment */ }
}

function webSocketAccept(key) {
  return crypto.createHash('sha1').update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`).digest('base64');
}
