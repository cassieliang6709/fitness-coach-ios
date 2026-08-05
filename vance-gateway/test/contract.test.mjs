import assert from 'node:assert/strict';
import test from 'node:test';
import { buildVancePrompt, VANCE_PROMPT_VERSION } from '../coach-prompt.mjs';
import { parseGymVisionResponse, validateGymVisionInput } from '../gym-vision.mjs';
import { parseMemorySummaryResponse, validateMemorySummaryInput, memoryBudget } from '../memory-summary.mjs';

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
      { operation: 'add', category: 'injury', text: '右膝不适，避免跳跃' },
      { operation: 'add', category: 'unknown', text: 'should not persist' },
      { operation: 'add', category: 'injury', text: '右膝不适，避免跳跃' },
    ],
  }));
  assert.equal(result.updates.length, 1);
  assert.equal(result.updates[0].operation, 'add');
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

test('memory summary accepts structured existing memories with ids', () => {
  const result = validateMemorySummaryInput({
    transcript: ['用户：膝盖养好了'],
    existingMemories: [
      { id: 'memory-abc123', category: 'injury', text: '右膝不适' },
      { id: 'memory-def456', category: 'bogus', text: '偏好' },
      '纯文本旧格式',
    ],
  });
  assert.equal(result.existingMemories.length, 3);
  assert.equal(result.existingMemories[0].id, 'memory-abc123');
  assert.equal(result.existingMemories[1].category, null); // unsupported category dropped
  assert.equal(result.existingMemories[2].id, null); // legacy string keeps null id
});

test('update and delete must cite a real existing memory id', () => {
  const existing = [{ id: 'memory-knee01', category: 'injury', text: '右膝不适' }];
  const result = parseMemorySummaryResponse(JSON.stringify({
    updates: [
      { operation: 'update', category: 'injury', text: '膝盖已恢复', targetId: 'memory-knee01' },
      { operation: 'delete', category: 'injury', text: '', targetId: 'memory-knee01' },
      { operation: 'update', category: 'injury', text: '幻觉引用', targetId: 'memory-notreal' },
      { operation: 'delete', category: 'injury', text: '', targetId: null },
    ],
  }), existing);
  // The hallucinated and id-less references are dropped; the two real ones survive.
  assert.equal(result.updates.length, 2);
  assert.equal(result.updates[0].operation, 'update');
  assert.equal(result.updates[0].targetId, 'memory-knee01');
  assert.equal(result.updates[1].operation, 'delete');
});

test('noop and duplicate adds are filtered out', () => {
  const result = parseMemorySummaryResponse(JSON.stringify({
    updates: [
      { operation: 'noop', category: 'preference', text: '今天有点累' },
      { operation: 'add', category: 'preference', text: '喜欢早上训练' },
      { operation: 'add', category: 'preference', text: '喜欢早上训练' },
    ],
  }));
  assert.equal(result.updates.length, 1);
  assert.equal(result.updates[0].operation, 'add');
});

test('memory budget reports pressure over the ceiling', () => {
  const calm = memoryBudget([{ text: 'a' }, { text: 'b' }]);
  assert.equal(calm.count, 2);
  assert.equal(calm.overBudget, false);
  const crowded = memoryBudget(Array.from({ length: 50 }, () => ({ text: 'x'.repeat(60) })));
  assert.equal(crowded.overBudget, true);
});

test('prompt renders layered memories with safety first', () => {
  const prompt = buildVancePrompt({
    style: 'practical',
    state: { phase: 'strength' },
    memoryLayers: {
      injuries: ['右膝不适'],
      preferences: ['喜欢早上训练'],
      facts: ['常去望京健身房'],
    },
  });
  assert.match(prompt, /身体限制\/安全（优先遵守）：右膝不适/);
  assert.match(prompt, /训练偏好：喜欢早上训练/);
  assert.match(prompt, /其他长期事实：常去望京健身房/);
  // Safety layer precedes the preference layer in the rendered prompt.
  assert.ok(prompt.indexOf('身体限制') < prompt.indexOf('训练偏好'));
});

test('prompt stays backward compatible with a flat memories array', () => {
  const prompt = buildVancePrompt({ style: 'practical', state: {}, memories: ['膝盖偶尔不适'] });
  assert.match(prompt, /训练偏好：膝盖偶尔不适/);
});
