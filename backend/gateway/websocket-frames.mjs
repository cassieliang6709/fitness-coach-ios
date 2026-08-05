import crypto from 'node:crypto';

export function readFrames(buffer, masked) {
  const frames = [];
  let offset = 0;
  while (offset + 2 <= buffer.length) {
    const first = buffer[offset];
    const second = buffer[offset + 1];
    const isMasked = Boolean(second & 0x80);
    let size = second & 0x7f;
    let cursor = offset + 2;
    if (size === 126) {
      if (cursor + 2 > buffer.length) break;
      size = buffer.readUInt16BE(cursor);
      cursor += 2;
    } else if (size === 127) {
      if (cursor + 8 > buffer.length) break;
      const bigint = buffer.readBigUInt64BE(cursor);
      if (bigint > BigInt(Number.MAX_SAFE_INTEGER)) throw new Error('WebSocket frame too large');
      size = Number(bigint);
      cursor += 8;
    }
    if (isMasked !== masked) throw new Error('Unexpected WebSocket mask');
    const mask = isMasked ? buffer.subarray(cursor, cursor + 4) : null;
    if (isMasked) {
      if (cursor + 4 > buffer.length) break;
      cursor += 4;
    }
    if (cursor + size > buffer.length) break;
    const payload = Buffer.from(buffer.subarray(cursor, cursor + size));
    if (mask) {
      for (let index = 0; index < payload.length; index += 1) {
        payload[index] ^= mask[index % 4];
      }
    }
    frames.push({ fin: Boolean(first & 0x80), opcode: first & 0x0f, payload });
    offset = cursor + size;
  }
  return { frames, rest: buffer.subarray(offset) };
}

/// Reassembles RFC 6455 continuation frames before JSON parsing or forwarding.
/// Direct local sockets often deliver one FIN text frame, while reverse proxies
/// are free to fragment the same message into text + continuation frames.
export function assembleMessage(frame, fragments) {
  // Control frames are never part of a fragmented data message and may appear
  // between its fragments.
  if (frame.opcode >= 0x8) return frame;

  if (frame.opcode === 0x0) {
    if (fragments.opcode === null) throw new Error('Unexpected WebSocket continuation');
    fragments.chunks.push(frame.payload);
    if (!frame.fin) return null;
    const message = {
      fin: true,
      opcode: fragments.opcode,
      payload: Buffer.concat(fragments.chunks),
    };
    fragments.opcode = null;
    fragments.chunks = [];
    return message;
  }

  if (frame.opcode === 0x1 || frame.opcode === 0x2) {
    if (fragments.opcode !== null) throw new Error('Nested WebSocket fragments');
    if (frame.fin) return frame;
    fragments.opcode = frame.opcode;
    fragments.chunks = [frame.payload];
    return null;
  }

  return frame;
}

export function writeFrame(payload, opcode, masked) {
  const body = Buffer.isBuffer(payload) ? payload : Buffer.from(payload);
  let headerSize = 2;
  if (body.length >= 126 && body.length <= 0xffff) headerSize += 2;
  else if (body.length > 0xffff) headerSize += 8;
  const mask = masked ? crypto.randomBytes(4) : null;
  const frame = Buffer.alloc(headerSize + (mask ? 4 : 0) + body.length);
  frame[0] = 0x80 | opcode;
  let cursor = 2;
  if (body.length < 126) frame[1] = (masked ? 0x80 : 0) | body.length;
  else if (body.length <= 0xffff) {
    frame[1] = (masked ? 0x80 : 0) | 126;
    frame.writeUInt16BE(body.length, cursor);
    cursor += 2;
  } else {
    frame[1] = (masked ? 0x80 : 0) | 127;
    frame.writeBigUInt64BE(BigInt(body.length), cursor);
    cursor += 8;
  }
  if (mask) {
    Buffer.from(mask).copy(frame, cursor);
    cursor += 4;
    for (let index = 0; index < body.length; index += 1) {
      frame[cursor + index] = body[index] ^ mask[index % 4];
    }
  } else {
    body.copy(frame, cursor);
  }
  return frame;
}
