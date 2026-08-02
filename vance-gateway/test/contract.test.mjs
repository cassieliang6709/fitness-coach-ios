import assert from 'node:assert/strict';
import test from 'node:test';
import { buildVancePrompt, VANCE_PROMPT_VERSION } from '../coach-prompt.mjs';
import { parseGymVisionResponse, validateGymVisionInput } from '../gym-vision.mjs';
import { parseMemorySummaryResponse, validateMemorySummaryInput } from '../memory-summary.mjs';

test('Vance prompt includes server-owned context and safety contract', () => {
  const prompt = buildVancePrompt({
    style: 'practical',
    state: {
      phase: 'strength',
      exercise: '高脚杯深蹲',
      prescription: '4 × 12',
      availableEquipment: ['哑铃', '坐姿划船机'],
    },
    memories: ['膝盖偶尔不适'],
  });
  assert.equal(VANCE_PROMPT_VERSION, 'v1');
  assert.match(prompt, /高脚杯深蹲/);
  assert.match(prompt, /膝盖偶尔不适/);
  assert.match(prompt, /已确认可用器械：哑铃、坐姿划船机/);
  assert.match(prompt, /疼痛、头晕、胸闷/);
});

test('gym vision exposes only high-confidence equipment', () => {
  const result = parseGymVisionResponse(JSON.stringify({
    sceneSummary: '确认跑步机，另有疑似椭圆机',
    equipment: [
      { name: '跑步机', confidence: 'high', visibleEvidence: '跑带和控制台清晰可见' },
      { name: '椭圆机', confidence: 'medium', visibleEvidence: '只看到局部把手' },
      { name: '模糊器械', confidence: 'low', visibleEvidence: '远景轮廓' },
    ],
    needsConfirmation: [],
  }));
  assert.deepEqual(result.equipment.map(item => item.name), ['跑步机']);
  assert.equal(result.needsConfirmation.length, 1);
  assert.match(result.needsConfirmation[0], /椭圆机/);
});

test('gym vision rejects unsupported image data', () => {
  assert.throws(() => validateGymVisionInput({ imageData: 'https://example.com/gym.jpg' }), /仅支持/);
});

test('memory summary keeps only supported, durable categories with stable ids', () => {
  const result = parseMemorySummaryResponse(JSON.stringify({
    updates: [
      { category: 'injury', text: '右膝不适，避免跳跃' },
      { category: 'unknown', text: 'should not persist' },
      { category: 'injury', text: '右膝不适，避免跳跃' },
    ],
  }));
  assert.equal(result.updates.length, 1);
  assert.equal(result.updates[0].operation, 'upsert');
  assert.match(result.updates[0].id, /^memory-[a-f0-9]{16}$/);
});

test('memory summary bounds untrusted request content', () => {
  const result = validateMemorySummaryInput({
    transcript: Array.from({ length: 20 }, () => '训练反馈'),
    existingMemories: Array.from({ length: 70 }, () => '已有记忆'),
  });
  assert.equal(result.transcript.length, 12);
  assert.equal(result.existingMemories.length, 60);
});
