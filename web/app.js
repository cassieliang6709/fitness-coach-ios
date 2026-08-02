/* AI 健身教练 — 陪练模块, web demo.
 *
 * A faithful port of the SwiftUI app: same routes, same design tokens, same
 * copy and numbers (Models/MockData.swift), same phase machine
 * (State/WorkoutSession.swift) and the same scripted coach
 * (State/CoachThread.swift). Mock data only, no backend.
 */
(function () {
  'use strict';

  // ---------------------------------------------------------------- Format

  const Format = {
    /** 12 -> "12 kg", 12.5 -> "12.5 kg" */
    kg(value) {
      const rounded = Math.round(value);
      const number = Math.abs(value - rounded) < 0.05 ? String(rounded) : value.toFixed(1);
      return `${number} kg`;
    },
    /** 45 -> "00:45" */
    clock(seconds) {
      const m = String(Math.floor(seconds / 60)).padStart(2, '0');
      const s = String(seconds % 60).padStart(2, '0');
      return `${m}:${s}`;
    },
  };

  // ----------------------------------------------------------------- Icons

  const ICONS = {
    'chevron-left':
      '<path d="M15 4.5 7.5 12 15 19.5" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',
    star:
      '<path d="M12 3.6l2.5 5.1 5.6.8-4 3.9 1 5.6-5.1-2.7-5 2.7 1-5.6-4.1-3.9 5.6-.8z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
    'star-fill':
      '<path d="M12 3.6l2.5 5.1 5.6.8-4 3.9 1 5.6-5.1-2.7-5 2.7 1-5.6-4.1-3.9 5.6-.8z" fill="currentColor"/>',
    checkmark:
      '<path d="M5 12.8l4.2 4.2L19 6.6" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>',
    'check-circle-fill':
      '<circle cx="12" cy="12" r="10" fill="currentColor"/><path d="M7.4 12.4l3.1 3.1 6-6.2" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    circle: '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.8"/>',
    'circle-half':
      '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M12 3a9 9 0 0 0 0 18z" fill="currentColor"/>',
    'circle-dotted':
      '<circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-dasharray="1.6 3.6"/>',
    timer:
      '<circle cx="12" cy="13.5" r="7.5" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M12 9.5v4h3M9.5 2.6h5" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
    'mic-fill':
      '<rect x="9" y="2.5" width="6" height="11" rx="3" fill="currentColor"/><path d="M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v3.2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    ellipsis:
      '<g fill="currentColor"><circle cx="5.5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="18.5" cy="12" r="1.8"/></g>',
    waveform:
      '<g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 11v2M7 8v8M11 4.5v15M15 8v8M19 10.5v3"/></g>',
    keyboard:
      '<rect x="2.5" y="6" width="19" height="12" rx="2.6" fill="none" stroke="currentColor" stroke-width="1.8"/><g fill="currentColor"><circle cx="6.5" cy="10" r="1"/><circle cx="10" cy="10" r="1"/><circle cx="13.5" cy="10" r="1"/><circle cx="17" cy="10" r="1"/></g><path d="M7.5 14.4h9" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
    xmark:
      '<path d="M6 6l12 12M18 6L6 18" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
    'arrow-up':
      '<path d="M12 19V5.6M6 11.4L12 5.4l6 6" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
    'flag-checkered':
      '<path d="M5 21V3.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M5 4.5h14v8H5z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><g fill="currentColor"><rect x="5" y="4.5" width="4.6" height="4" /><rect x="14.2" y="4.5" width="4.8" height="4"/><rect x="9.6" y="8.5" width="4.6" height="4"/></g>',
    'dumbbell-fill':
      '<g fill="currentColor"><rect x="1" y="8.6" width="2.6" height="6.8" rx="1.2"/><rect x="4.2" y="5.8" width="3.6" height="12.4" rx="1.6"/><rect x="7.6" y="10.2" width="8.8" height="3.6" rx="1.6"/><rect x="16.2" y="5.8" width="3.6" height="12.4" rx="1.6"/><rect x="20.4" y="8.6" width="2.6" height="6.8" rx="1.2"/></g>',
    dumbbell:
      '<g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M6.4 8v8M9.4 6.6v10.8M14.6 6.6v10.8M17.6 8v8M9.4 12h5.2M3.6 10.4v3.2M20.4 10.4v3.2"/></g>',
    run:
      '<circle cx="15" cy="4.4" r="2.3" fill="currentColor"/><g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.4 21.2l2.4-5.4 3-2.2-1.2-4.8"/><path d="M13.6 13.6l2 2.8 2.8 2.6"/><path d="M8.4 12.2l4.6-2.6 4 1.4"/><path d="M4.6 15.4h3.2"/></g>',
    strength:
      '<circle cx="12" cy="4.2" r="2.2" fill="currentColor"/><g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 7.2v5.4M8.4 21l1.6-5.4M15.6 21L14 15.6M6.6 11.2h10.8"/><path d="M3.6 9.4v3.6M20.4 9.4v3.6"/></g>',
    'strength-func':
      '<circle cx="8.6" cy="4.6" r="2.2" fill="currentColor"/><g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8.6 7.6v5M6.2 21l2.4-5.6 3.4-1.4"/><path d="M12.4 14l1.6 3.4 2.8 2.2"/><path d="M8.6 10.2l4.4 1 3.6-2.6"/><path d="M18.6 6.2v4"/></g>',
    rower:
      '<circle cx="7.4" cy="5" r="2.2" fill="currentColor"/><g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.6h9.6l4.4-3.6"/><path d="M7.4 8v4.4l3.6 2.4"/><path d="M9.4 10.6l6 1.6 3.6-3.4"/></g>',
    cooldown:
      '<circle cx="10.4" cy="4.6" r="2.2" fill="currentColor"/><g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.4 7.6v4.6l-4.6 3.2"/><path d="M10.4 12.2l5 2 3.2 4.4"/><path d="M4 20.4h6.4"/></g>',
    flame:
      '<path d="M12 2.4c1.1 3.6-1.6 4.6-1.6 7.2A2.5 2.5 0 0 0 13 12c1.1 0 1.9-.7 2.3-1.5 1.6 1.4 2.7 3.5 2.7 5.3a6 6 0 0 1-12 0c0-4.4 3.6-6.6 6-13.4z" fill="currentColor"/>',
    'walk-motion':
      '<circle cx="12" cy="4.2" r="2.2" fill="currentColor"/><g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 7.2v4.6l-2.4 3.4L8.4 21"/><path d="M12 11.8l2.8 2.6.8 6.6"/><path d="M9 9.6l6 1.4"/></g><g fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" opacity=".5"><path d="M3.4 8.4h2.4M2.4 12h2.6M3.4 15.6h2.4"/></g>',
    sliders:
      '<g fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><path d="M3 7h18M3 12h18M3 17h18"/></g><g fill="currentColor"><circle cx="8" cy="7" r="2.4"/><circle cx="15.5" cy="12" r="2.4"/><circle cx="10" cy="17" r="2.4"/></g>',
    mappin:
      '<path d="M12 2.6c3.4 0 6 2.6 6 6 0 4.2-6 12.8-6 12.8S6 12.8 6 8.6c0-3.4 2.6-6 6-6z" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/><circle cx="12" cy="8.6" r="2.3" fill="currentColor"/>',
    sparkle:
      '<path d="M12 2.6l1.8 5.4 5.6 1.9-5.6 1.9L12 17.2l-1.8-5.4-5.6-1.9 5.6-1.9z" fill="currentColor"/>',
    'music-note':
      '<path d="M9 18V5.4l9-2v12" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/><g fill="currentColor"><ellipse cx="6.6" cy="18.2" rx="2.8" ry="2.3"/><ellipse cx="15.6" cy="15.4" rx="2.8" ry="2.3"/></g>',
    'drop-fill':
      '<path d="M12 2.8c3.6 4.4 6 7.4 6 10.4a6 6 0 0 1-12 0c0-3 2.4-6 6-10.4z" fill="currentColor"/>',
    'chat-bubbles':
      '<g fill="currentColor"><path d="M2.6 6.4c0-1.6 1.3-2.8 2.9-2.8h7.2c1.6 0 2.9 1.2 2.9 2.8v3.8c0 1.6-1.3 2.8-2.9 2.8H8l-3.6 2.6v-2.7c-1.1-.4-1.8-1.4-1.8-2.7z"/><path d="M17.6 8.2h.9c1.6 0 2.9 1.2 2.9 2.8v3.8c0 1.3-.7 2.3-1.8 2.7v2.7L16 17.6h-4.4c-1.1 0-2-.5-2.5-1.3h4.1c2.4 0 4.4-1.9 4.4-4.3z"/></g>',
    brain:
      '<path d="M15.4 2.6c2.8 0 5 2.1 5 4.8 0 1-.3 2-.9 2.8.6.8.9 1.7.9 2.7 0 2.7-2.2 4.8-5 4.8-.6 0-1.2-.1-1.7-.3v3.9h-2.4v-4.9c-.5.2-1 .3-1.6.3-2.8 0-5-2.1-5-4.8 0-1 .3-1.9.9-2.7-.6-.8-.9-1.8-.9-2.8 0-2.7 2.2-4.8 5-4.8 1 0 2 .3 2.8.8.8-.5 1.8-.8 2.9-.8z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
    'seal-check':
      '<path d="M12 2.2l2.3 1.7 2.8-.4 1.1 2.6 2.6 1.1-.4 2.8L22.1 12l-1.7 2.3.4 2.8-2.6 1.1-1.1 2.6-2.8-.4L12 21.8l-2.3-1.4-2.8.4-1.1-2.6-2.6-1.1.4-2.8L2.2 12l1.4-2.3-.4-2.8 2.6-1.1 1.1-2.6 2.8.4z" fill="currentColor"/><path d="M8 12.2l2.8 2.8L16 9.4" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    seal:
      '<path d="M12 2.2l2.3 1.7 2.8-.4 1.1 2.6 2.6 1.1-.4 2.8L22.1 12l-1.7 2.3.4 2.8-2.6 1.1-1.1 2.6-2.8-.4L12 21.8l-2.3-1.4-2.8.4-1.1-2.6-2.6-1.1.4-2.8L2.2 12l1.4-2.3-.4-2.8 2.6-1.1 1.1-2.6 2.8.4z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>',
    checklist:
      '<g fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6.4l1.8 1.8L8 4.8M3 16.4l1.8 1.8L8 14.8M11 6.6h10M11 17.4h10"/></g>',
    house:
      '<path d="M3.4 10.6L12 3.4l8.6 7.2v9a1 1 0 0 1-1 1h-5v-6h-5.2v6h-5a1 1 0 0 1-1-1z" fill="currentColor"/>',
    tree:
      '<path d="M12 2.6l5.4 7.2h-2.8l4.4 5.8H4.9l4.5-5.8H6.6z" fill="currentColor"/><rect x="10.6" y="15" width="2.8" height="6.4" rx="1" fill="currentColor"/>',
    flexibility:
      '<circle cx="7.4" cy="4.6" r="2.2" fill="currentColor"/><g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7.4 7.6v4.2l3.2 2.6 2 5.2"/><path d="M10.6 14.4l-4.4 1.4-2 4.6"/><path d="M8.4 10.4l5.6-1.6 4 2.6"/></g>',
    'arms-open':
      '<circle cx="12" cy="4.2" r="2.2" fill="currentColor"/><g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 7.2v6M8.6 21l1.6-6M15.4 21l-1.6-6"/><path d="M12 9.2L6.4 6.6M12 9.2l5.6-2.6"/></g>',
    'hand-raised':
      '<path d="M8 12.4V5.6a1.5 1.5 0 0 1 3 0v5.2m0-5.8a1.5 1.5 0 0 1 3 0v5.8m0-4.4a1.5 1.5 0 0 1 3 0v8.2c0 3.4-2.4 5.8-5.6 5.8-2 0-3.6-.9-4.7-2.6L5 14.6a1.5 1.5 0 0 1 2.6-1.5z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
    square:
      '<rect x="3.6" y="3.6" width="16.8" height="16.8" rx="4.2" fill="none" stroke="currentColor" stroke-width="1.8"/>',
    'check-square':
      '<rect x="3" y="3" width="18" height="18" rx="4.6" fill="currentColor"/><path d="M7.6 12.2l3 3 5.8-6" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    list:
      '<g fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><path d="M8.4 6.4h12M8.4 12h12M8.4 17.6h12"/></g><g fill="currentColor"><circle cx="4" cy="6.4" r="1.5"/><circle cx="4" cy="12" r="1.5"/><circle cx="4" cy="17.6" r="1.5"/></g>',
    grid:
      '<g fill="none" stroke="currentColor" stroke-width="1.9"><rect x="3.4" y="3.4" width="7" height="7" rx="2.2"/><rect x="13.6" y="3.4" width="7" height="7" rx="2.2"/><rect x="3.4" y="13.6" width="7" height="7" rx="2.2"/><rect x="13.6" y="13.6" width="7" height="7" rx="2.2"/></g>',
    stop: '<rect x="6" y="6" width="12" height="12" rx="2.6" fill="currentColor"/>',
  };

  function icon(name, size = 16, cls = '') {
    return `<svg class="icon ${cls}" viewBox="0 0 24 24" width="${size}" height="${size}" aria-hidden="true">${ICONS[name] || ''}</svg>`;
  }

  // ---------------------------------------------------------------- Mascot

  /* Vector stand-in for the coach IP, translated from Components/Mascot.swift.
   * The native app swaps in the real artwork when the image sets are filled;
   * the proportions here are the same ones the fallback draws. */
  const MASCOT_ACCENT = {
    celebration: { icon: 'sparkle', size: 16, x: 36, y: -28, color: 'var(--primary)' },
    dumbbell: { icon: 'dumbbell-fill', size: 18, x: -36, y: 10, color: 'var(--mascot-ink)' },
    jogging: { icon: 'drop-fill', size: 11, x: 36, y: -14, color: '#7FB8E8' },
    listening: { icon: 'music-note', size: 14, x: 35, y: -24, color: 'var(--primary)' },
  };

  function mascot(pose = 'idle', size = 24) {
    // Detail is added progressively: below these sizes the extra shapes just
    // read as smudges. The belt bag needs more room than the rest — it sits
    // right where the pose accent lands, so the two merge if drawn too small.
    const detail = size >= 48;
    const belt = size >= 72;
    const accent = size >= 40 ? MASCOT_ACCENT[pose] : null;
    const ink = 'var(--mascot-ink)';
    const parts = [];

    if (detail) {
      parts.push(
        `<g stroke="${ink}" stroke-opacity=".7" stroke-width="2.8" fill="#fff">
           <ellipse cx="-14.5" cy="44" rx="9.5" ry="5.5"/><ellipse cx="14.5" cy="44" rx="9.5" ry="5.5"/>
         </g>`
      );
    }

    parts.push(
      `<ellipse cx="0" cy="10" rx="38" ry="37" fill="#fff" stroke="${ink}" stroke-opacity=".7" stroke-width="3.5"/>`
    );

    if (belt) {
      parts.push(
        `<g fill="${ink}">
           <rect x="-31" y="24.7" width="62" height="6.5" rx="1" transform="rotate(-10 0 28)"/>
           <rect x="-15" y="23.5" width="24" height="13" rx="3.5"/>
         </g>`
      );
    }

    if (detail) {
      parts.push(
        `<g fill="var(--primary)" fill-opacity=".22">
           <ellipse cx="-19" cy="10" rx="5" ry="2.75"/><ellipse cx="19" cy="10" rx="5" ry="2.75"/>
         </g>`
      );
    }

    parts.push(
      `<g fill="${ink}">
         <ellipse cx="-11.25" cy="2" rx="3.75" ry="4.75"/><ellipse cx="11.25" cy="2" rx="3.75" ry="4.75"/>
         <ellipse cx="0" cy="13" rx="2.75" ry="1.9" fill-opacity=".8"/>
       </g>`
    );

    // Cap: top half of a circle, brim swept to one side, button on the crown.
    parts.push(
      `<g fill="var(--primary)">
         <path d="M-36 -6 A36 36 0 0 1 36 -6 Z"/>
         <rect x="6" y="-12.5" width="42" height="9" rx="4.5"/>
         <rect x="-3.5" y="-40" width="7" height="8" rx="3.5" fill="#fff" fill-opacity=".85"/>
       </g>`
    );

    let accentSvg = '';
    if (accent) {
      const s = accent.size;
      accentSvg = `<g transform="translate(${accent.x} ${accent.y})" color="${accent.color}">
          <svg x="${-s / 2}" y="${-s / 2}" width="${s}" height="${s}" viewBox="0 0 24 24">${ICONS[accent.icon]}</svg>
        </g>`;
    }

    return `<svg class="mascot" width="${size}" height="${size}" viewBox="-50 -50 100 100" aria-hidden="true">${parts.join('')}${accentSvg}</svg>`;
  }

  // ------------------------------------------------------------- Mock data

  const AI_STYLES = [
    { id: 'gentle', label: '温和', tooltip: '更多安抚和状态确认' },
    { id: 'encouraging', label: '鼓励', tooltip: '更多正向反馈' },
    { id: 'practical', label: '务实', tooltip: '直接告诉你下一步怎么做' },
  ];

  /* What the user tells us during the welcome flow. Every answer becomes an AI
   * memory, so the coach's first session already knows the goal, the venue and
   * the bad knee — onboarding is where the memory table starts, not a survey
   * that gets filed away. Mirrors Models/Profile.swift. */
  const GOALS = [
    { id: 'fatLoss', label: '减脂', detail: '力量打底，配稳定有氧', symbol: 'flame', weeklyTarget: 5 },
    { id: 'muscle', label: '增肌', detail: '大重量，组间休息更长', symbol: 'dumbbell-fill', weeklyTarget: 4 },
    { id: 'shape', label: '塑形', detail: '中等重量，多次数', symbol: 'strength-func', weeklyTarget: 4 },
    { id: 'endurance', label: '体能', detail: '循环训练，心肺为主', symbol: 'run', weeklyTarget: 3 },
  ];

  const VENUES = [
    { id: 'gym', label: '健身房', detail: '器械齐全，动作不设限', symbol: 'mappin' },
    { id: 'home', label: '家里', detail: '哑铃、弹力带、自重', symbol: 'house' },
    { id: 'outdoor', label: '户外', detail: '跑步、爬坡、自重', symbol: 'tree' },
  ];

  const CONDITIONS = [
    { id: 'knee', label: '膝盖', detail: '避免跳跃，深蹲降重量', symbol: 'walk-motion' },
    { id: 'lowBack', label: '腰', detail: '避免硬拉与大重量弯腰', symbol: 'flexibility' },
    { id: 'shoulder', label: '肩', detail: '避免过顶推举', symbol: 'arms-open' },
    { id: 'wrist', label: '手腕', detail: '改用固定器械或护腕', symbol: 'hand-raised' },
  ];

  const byId = (list, id) => list.find((item) => item.id === id);

  /** The memories the welcome flow seeds. Ids are stable, so re-running
   * onboarding updates the chips instead of duplicating them. */
  function seedMemories(profile) {
    const goal = byId(GOALS, profile.goal);
    const venue = byId(VENUES, profile.venue);
    return [
      { id: 'mem-goal', category: 'preference', text: `训练目标：${goal.label}` },
      { id: 'mem-venue', category: 'venue', text: `常在${venue.label}训练` },
      ...profile.conditions.map((id) => {
        const condition = byId(CONDITIONS, id);
        return {
          id: `mem-${id}`,
          category: 'injury',
          text: `${condition.label}不适：${condition.detail}`,
        };
      }),
    ];
  }

  const SECTION_KIND = {
    warmup: { title: '热身', symbol: 'flame' },
    strength: { title: '力量', symbol: 'dumbbell-fill' },
    cardio: { title: '有氧', symbol: 'run' },
  };

  const MEMORY_SYMBOL = {
    injury: 'walk-motion',
    preference: 'sliders',
    venue: 'mappin',
    equipment: 'dumbbell',
  };

  function volumeLabel(ex) {
    return ex.sideBased ? `${ex.sets} × ${ex.reps} / 侧` : `${ex.sets} × ${ex.reps}`;
  }

  function weightLabel(ex) {
    return ex.weight == null ? null : `建议重量 ${Format.kg(ex.weight)}`;
  }

  const MockData = {
    welcomeHighlights: [
      {
        id: 'coach',
        symbol: 'chat-bubbles',
        title: '训练时能说话',
        body: '哪里不舒服、太重了、想换动作，说一句就改。',
      },
      {
        id: 'memory',
        symbol: 'brain',
        title: '记得住你',
        body: '伤病、场地、习惯只说一次，下次自动生效。',
      },
      {
        id: 'honest',
        symbol: 'seal-check',
        title: '只记你真做过的',
        body: '复盘按实际完成的组数统计，不替你打勾。',
      },
    ],

    /** Title / subtitle for each question in the welcome flow. */
    welcomeSteps: [
      { title: '先认识一下', subtitle: '我是你的 AI 陪练。训练时你说话，我改计划。' },
      { title: '你想练成什么样？', subtitle: '决定动作的重量、次数和有氧比例。' },
      { title: '平时在哪训练？', subtitle: '决定我给你安排哪些器械。' },
      { title: '身体有需要避开的地方吗？', subtitle: '可多选。这条会一直生效，优先级高于计划。' },
      { title: '希望我用什么语气？', subtitle: '随时可以在「我的计划」里改。' },
    ],

    styleSampleLines: {
      gentle: '慢一点，膝盖朝脚尖方向，髋部向后坐。',
      encouraging: '这个动作你上次做得很稳，髋部向后坐。',
      practical: '膝盖朝脚尖方向，髋部向后坐。',
    },

    memories: [
      { id: 'mem-knee', category: 'injury', text: '右膝不适，避免跳跃', active: true },
      { id: 'mem-venue', category: 'venue', text: '乐刻健身房', active: true },
    ],

    legDayExercises: [
      { id: 'goblet-squat', name: '高脚杯深蹲', sets: 4, reps: '12', weight: 12, alternative: '箱式深蹲' },
      { id: 'glute-bridge', name: '臀桥', sets: 4, reps: '15', weight: null },
      { id: 'step-up', name: '台阶上步', sets: 3, reps: '10', weight: null, sideBased: true },
      { id: 'leg-press', name: '坐姿腿推', sets: 3, reps: '12', weight: null },
      { id: 'leg-curl', name: '坐姿腿弯举', sets: 3, reps: '12', weight: null },
      { id: 'calf-raise', name: '小腿提踵', sets: 3, reps: '15', weight: null },
    ],

    otherPlans: [
      { id: 'chest-shoulder', title: '胸肩 + 有氧', tags: ['力量 45 分钟', '有氧 20 分钟'], symbol: 'strength-func' },
      { id: 'back', title: '背部 + 有氧', tags: ['力量 50 分钟', '有氧 20 分钟'], symbol: 'rower' },
      { id: 'recovery', title: '低冲击恢复日', tags: ['拉伸', '核心', '低强度有氧'], symbol: 'cooldown' },
    ],

    strengthVenue: '乐刻健身房 · 哑铃区',
    restDuration: 45,

    cardioName: '跑步机快走',
    cardioPrescription: '6.0 km/h · 20 分钟',
    cardioTargetMinutes: 30,

    // Home conversation — the coach before training starts.
    homeOpening: [
      {
        core: '今天安排的是练腿日：力量 60 分钟，有氧 20–30 分钟。',
        gentleLead: '不着急，',
        encouragingLead: '上次练得不错，',
      },
    ],

    homeScript: [
      {
        id: 'home-what',
        userText: '今天练什么？',
        replies: [
          {
            core: '高脚杯深蹲、臀桥、台阶上步等 6 个动作，最后跑步机快走 20 分钟。',
            gentleLead: '先看一眼，',
            encouragingLead: '都是你练过的动作，',
          },
        ],
      },
      {
        id: 'home-knee',
        userText: '膝盖有点不舒服',
        replies: [
          {
            core: '那深蹲今天从 10 kg 起，台阶上步先做 2 组。疼就立刻说。',
            gentleLead: '先别硬撑，',
            encouragingLead: '提前说出来最好，',
          },
        ],
      },
      {
        id: 'home-short',
        userText: '今天时间不多',
        replies: [
          {
            core: '那就只做深蹲、臀桥、腿推，有氧压到 15 分钟，40 分钟能结束。',
            gentleLead: '少练也是练，',
            encouragingLead: '能来就已经赢了一半，',
          },
        ],
      },
      {
        id: 'home-last',
        userText: '上次练得怎么样？',
        replies: [
          {
            core: '上次全部完成，深蹲停在 12 kg。今天可以试试 14 kg。',
            gentleLead: '按感觉来，',
            encouragingLead: '上次很稳，',
          },
        ],
      },
    ],

    strengthOpening: [{ core: '准备好了吗？', gentleLead: '不着急，', encouragingLead: '状态看起来不错，' }],

    strengthScript: [
      {
        id: 'start',
        userText: '开始',
        replies: [{ core: '膝盖朝脚尖方向，髋部向后坐。', gentleLead: '慢一点，', encouragingLead: '这个动作你上次做得很稳，' }],
      },
      {
        id: 'knee',
        userText: '膝盖有点紧。',
        replies: [{ core: '下一组降到 10 kg。仍然不适就改箱式深蹲。', gentleLead: '收到，', encouragingLead: '反馈得很及时，' }],
        effect: { type: 'reduceWeight', value: 10 },
      },
      { id: 'set3', userText: '这组还行。', replies: [{ core: '保持这个重量，下放数 2 秒。', encouragingLead: '很好，' }] },
      { id: 'set4', userText: '最后一组开始。', replies: [{ core: '最后一组，站起时呼气。', gentleLead: '稳住就好，' }] },
    ],

    cardioOpening: [
      { core: '现在进入有氧阶段。' },
      { core: '保持 6.0 km/h，能说话但略微喘。', gentleLead: '按自己的节奏来，', encouragingLead: '力量部分完成得不错，' },
    ],

    cardioScript: [
      {
        id: 'cardio-knee',
        userText: '膝盖有点不舒服。',
        replies: [{ core: '把坡度调到 0。如果仍然不适，就改为椭圆机。', gentleLead: '先别硬撑，', encouragingLead: '说出来就对了，' }],
        effect: { type: 'flattenIncline' },
      },
      { id: 'cardio-pace', userText: '现在好一些了。', replies: [{ core: '保持到 30 分钟，最后 3 分钟降到 4.5 km/h。' }] },
    ],

    kneeMemoryUpdate: '右膝今天轻微紧张。下次台阶上步先调整为 2 组，并在深蹲前增加膝关节热身。',
    neutralMemoryUpdate: '今天全程无不适反馈。下次高脚杯深蹲可以尝试加到 14 kg。',
  };

  MockData.legDayPlan = {
    id: 'leg-day',
    title: '练腿日计划',
    tags: ['力量 60 分钟', '有氧 20–30 分钟'],
    symbol: 'strength',
    sections: [
      { id: 'warmup', kind: 'warmup', duration: '8 分钟', subtitle: '动态拉伸 + 臀腿激活', exercises: [] },
      { id: 'strength', kind: 'strength', duration: '60 分钟', exercises: MockData.legDayExercises },
      { id: 'cardio', kind: 'cardio', duration: '20–30 分钟', subtitle: '跑步机快走', exercises: [] },
    ],
    memoryNote: { title: '膝盖记忆', body: '避免跳跃。深蹲不适时降低重量，或替换为箱式深蹲。' },
  };

  /** Style-specific lead-in, so the tone selector changes what the coach says. */
  function renderLine(line, style) {
    if (style === 'gentle' && line.gentleLead) return line.gentleLead + line.core;
    if (style === 'encouraging' && line.encouragingLead) return line.encouragingLead + line.core;
    return line.core;
  }

  // ----------------------------------------------------------------- Store

  /* Stands in for SwiftData: the profile, the memory chips and the finished
   * sessions all survive a reload. A first-time visitor gets no profile, which
   * is what routes them into the welcome flow. */
  const Store = {
    key: 'fitnesscoach.v2',

    read() {
      try {
        const raw = localStorage.getItem(this.key);
        if (raw) return JSON.parse(raw);
      } catch (_) {
        /* private mode — fall through to defaults */
      }
      return { profile: null, memories: [], sessions: [] };
    },

    write(state) {
      try {
        localStorage.setItem(this.key, JSON.stringify(state));
      } catch (_) {
        /* ignore */
      }
    },

    get profile() {
      return this.read().profile;
    },

    get hasProfile() {
      return !!this.read().profile;
    },

    get weeklyTarget() {
      const profile = this.profile;
      return profile ? byId(GOALS, profile.goal).weeklyTarget : 4;
    },

    activeMemories() {
      return this.read().memories.filter((m) => m.active !== false);
    },

    sessions() {
      // Newest first, matching the @Query sort on the plan tab.
      return this.read().sessions.slice().sort((a, b) => b.startedAt - a.startedAt);
    },

    upsertMemory(memory) {
      const state = this.read();
      const index = state.memories.findIndex((m) => m.id === memory.id);
      if (index >= 0) state.memories[index] = Object.assign({}, state.memories[index], memory);
      else state.memories.push(Object.assign({ active: true }, memory));
      this.write(state);
    },

    /** The welcome answers become the profile, the chips and the tone at once. */
    completeOnboarding(profile) {
      const state = this.read();
      state.profile = profile;
      for (const memory of seedMemories(profile)) {
        const index = state.memories.findIndex((m) => m.id === memory.id);
        if (index >= 0) state.memories[index] = Object.assign({}, state.memories[index], memory);
        else state.memories.push(Object.assign({ active: true }, memory));
      }
      this.write(state);
    },

    finishSession(record) {
      const state = this.read();
      state.sessions.push(record);
      this.write(state);
    },
  };

  /* Everything the plan tab reports about the user's history, derived from the
   * finished sessions in storage. Nothing here is a mock number — an empty
   * store produces an honest set of zeros. Mirrors Models/TrainingStats.swift. */
  const WEEKDAY_LABELS = ['一', '二', '三', '四', '五', '六', '日'];

  /** 0 = Monday … 6 = Sunday, independent of locale. */
  function weekdayIndex(date) {
    return (date.getDay() + 6) % 7;
  }

  function startOfDay(date) {
    const copy = new Date(date);
    copy.setHours(0, 0, 0, 0);
    return copy.getTime();
  }

  function trainingStats(sessions, weeklyTarget, now = new Date()) {
    const monday = new Date(now);
    monday.setHours(0, 0, 0, 0);
    monday.setDate(monday.getDate() - weekdayIndex(now));
    const weekStart = monday.getTime();
    const weekEnd = weekStart + 7 * 86400000;

    const thisWeek = sessions.filter((s) => s.startedAt >= weekStart && s.startedAt < weekEnd);
    const days = new Set(sessions.map((s) => startOfDay(new Date(s.startedAt))));

    // A rest day today does not break the streak yet — it only breaks once
    // yesterday is also empty.
    let cursor = startOfDay(now);
    if (!days.has(cursor)) cursor -= 86400000;
    let streakDays = 0;
    while (days.has(cursor)) {
      streakDays += 1;
      cursor -= 86400000;
    }

    const weeklyDone = thisWeek.length;
    const remaining = Math.max(0, weeklyTarget - weeklyDone);

    return {
      weeklyDone,
      weeklyTarget,
      completedWeekdays: new Set(thisWeek.map((s) => weekdayIndex(new Date(s.startedAt)))),
      streakDays,
      totalSessions: sessions.length,
      totalMinutes: sessions.reduce((sum, s) => sum + s.durationMinutes, 0),
      weeklyProgress: weeklyTarget > 0 ? Math.min(1, weeklyDone / weeklyTarget) : 0,
      // Praises a finished week rather than showing "还差 0 次".
      weeklyHeadline: remaining === 0 ? '本周目标已经完成了' : `本周还差 ${remaining} 次训练`,
      get tiles() {
        return [
          { value: `${this.streakDays} 天`, label: '连续打卡' },
          { value: `${this.totalSessions} 次`, label: '累计训练' },
          { value: `${this.totalMinutes} 分钟`, label: '累计时长' },
        ];
      },
    };
  }

  // ------------------------------------------------------------ CoachThread

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  /** One coaching conversation. Strength and cardio each own an instance. */
  class CoachThread {
    constructor(opening, script, onEffect, notify) {
      this.opening = opening;
      this.script = script;
      this.onEffect = onEffect;
      this.notify = notify;

      this.messages = [];
      this.isTyping = false;
      this.voiceState = 'idle'; // idle | listening | processing | speaking
      this.inputMode = 'voice';
      this.style = 'practical';

      this.usedTurns = new Set();
      this.busyWork = false;
      this.cancelled = false;
      this.seq = 0;
    }

    get isBusy() {
      return this.voiceState !== 'idle' || this.isTyping;
    }

    get voiceLabel() {
      return { listening: '在听', processing: '处理中', speaking: '回应中' }[this.voiceState] || null;
    }

    /** Hint next to the text field so the demo stays walkable. */
    get suggestedUserText() {
      const next = this.nextTurn;
      return next ? next.userText : null;
    }

    /** Scripted turns the user hasn't spent yet — the home suggestion chips. */
    get remainingSuggestions() {
      return this.script.filter((turn) => !this.usedTurns.has(turn.id)).map((turn) => turn.userText);
    }

    get nextTurn() {
      return this.script.find((turn) => !this.usedTurns.has(turn.id)) || null;
    }

    startIfNeeded() {
      if (this.messages.length || this.busyWork) return;
      this.run(async () => {
        await this.deliver(this.opening);
      });
    }

    /** Coach speaks unprompted — used when the session moves to a new movement. */
    announce(line) {
      const previous = this.pending || Promise.resolve();
      this.pending = previous.then(() => this.deliver([line]));
    }

    beginVoiceTurn() {
      if (this.isBusy || this.busyWork) return;
      this.cancelled = false;
      this.voiceState = 'listening';
      this.notify();

      this.run(async () => {
        const token = ++this.seq;
        await sleep(2000);
        if (this.cancelled || token !== this.seq) return;
        this.voiceState = 'processing';
        this.notify();
        await sleep(600);
        if (this.cancelled || token !== this.seq) return;

        const turn = this.consumeTurn();
        if (!turn) {
          this.voiceState = 'idle';
          this.notify();
          return;
        }
        this.append('user', turn.userText);
        this.voiceState = 'speaking';
        this.notify();
        this.apply(turn.effect);
        await this.deliver(turn.replies);
        this.voiceState = 'idle';
        this.notify();
      });
    }

    cancelVoiceTurn() {
      this.cancelled = true;
      this.seq += 1;
      this.voiceState = 'idle';
      this.isTyping = false;
      this.busyWork = false;
      this.notify();
    }

    send(text) {
      const trimmed = text.trim();
      if (!trimmed || this.isBusy || this.busyWork) return;
      this.append('user', trimmed);

      const turn = this.consumeTurn(trimmed);
      this.apply(turn && turn.effect);
      this.run(async () => {
        await this.deliver((turn && turn.replies) || [{ core: '收到。按当前配置继续。' }]);
      });
    }

    // -- internals

    run(work) {
      this.busyWork = true;
      this.pending = Promise.resolve(this.pending)
        .then(work)
        .finally(() => {
          this.busyWork = false;
        });
    }

    /* Tapping a suggestion chip should get the reply it promises, not just the
     * next line in the script — so an exact match wins over the cursor. */
    consumeTurn(text) {
      const match =
        (text && this.script.find((turn) => turn.userText === text && !this.usedTurns.has(turn.id))) ||
        this.nextTurn;
      if (!match) return null;
      this.usedTurns.add(match.id);
      return match;
    }

    apply(effect) {
      if (effect) this.onEffect(effect);
    }

    async deliver(lines) {
      for (const line of lines) {
        this.isTyping = true;
        this.notify();
        await sleep(900);
        if (this.cancelled) {
          this.isTyping = false;
          this.notify();
          return;
        }
        this.isTyping = false;
        this.append('assistant', renderLine(line, this.style));
        await sleep(250);
      }
    }

    append(role, content) {
      this.messages.push({ id: `m${Date.now()}-${Math.random().toString(36).slice(2, 7)}`, role, content });
      this.notify();
    }
  }

  // ---------------------------------------------------------------- Session

  /* Single source of truth for one training session — the phase machine from
   * State/WorkoutSession.swift. Progress is tracked per exercise *and* per set,
   * so the review reports only what was actually logged. */
  const session = {
    plan: MockData.legDayPlan,
    aiStyle: 'practical',
    phase: 'planning',

    exerciseIndex: 0,
    currentSet: 1,
    weightOverrides: {},
    swappedExercises: {},
    completedSets: [],
    restRemaining: 0,

    cardioSeconds: 0,
    cardioTarget: MockData.cardioTargetMinutes,

    kneeReported: false,
    adjustmentCount: 0,

    startedAt: Date.now(),
    restTimer: null,
    cardioTimer: null,

    /** True once a session is actually under way — a deep link straight to the
     * review must not write a phantom 0% record. */
    recording: false,

    init() {
      const profile = Store.profile;
      this.aiStyle = (profile && profile.style) || 'practical';
      this.makeThreads();
    },

    notify() {
      if (currentScreen && currentScreen.update) currentScreen.update();
    },

    makeThreads() {
      const notify = () => this.notify();
      this.strength = new CoachThread(
        MockData.strengthOpening,
        MockData.strengthScript,
        (effect) => this.handle(effect),
        notify
      );
      this.cardio = new CoachThread(
        MockData.cardioOpening,
        MockData.cardioScript,
        (effect) => this.handle(effect),
        notify
      );
      this.daily = new CoachThread(
        MockData.homeOpening,
        MockData.homeScript,
        (effect) => this.handle(effect),
        notify
      );
      this.daily.inputMode = 'text';
      this.setStyle(this.aiStyle);
    },

    setStyle(style) {
      this.aiStyle = style;
      this.strength.style = style;
      this.cardio.style = style;
      this.daily.style = style;
      this.notify();
    },

    // -- derived

    get exercises() {
      return this.plan.sections.find((s) => s.kind === 'strength').exercises;
    },

    get currentExercise() {
      return this.exercises[Math.min(this.exerciseIndex, this.exercises.length - 1)];
    },

    get currentExerciseName() {
      return this.swappedExercises[this.currentExercise.id] || this.currentExercise.name;
    },

    get currentWeight() {
      const override = this.weightOverrides[this.currentExercise.id];
      return override != null ? override : this.currentExercise.weight;
    },

    get plannedSetCount() {
      return this.exercises.reduce((total, ex) => total + ex.sets, 0);
    },

    get completedSetsForCurrentExercise() {
      return this.completedSets.filter((s) => s.exerciseID === this.currentExercise.id).length;
    },

    get strengthMetrics() {
      const load = this.currentWeight != null ? Format.kg(this.currentWeight) : '自重';
      const ex = this.currentExercise;
      const reps = ex.sideBased ? `${ex.reps} 次 / 侧` : `${ex.reps} 次`;
      return `${load} · ${reps}`;
    },

    get setProgressLabel() {
      return `第 ${this.currentSet} / ${this.currentExercise.sets} 组`;
    },

    get exerciseProgressLabel() {
      return `动作 ${Math.min(this.exerciseIndex + 1, this.exercises.length)} / ${this.exercises.length}`;
    },

    get cardioElapsedMinutes() {
      return Math.floor(this.cardioSeconds / 60);
    },

    get cardioProgressLabel() {
      return `已完成 ${this.cardioElapsedMinutes} / ${this.cardioTarget} 分钟`;
    },

    get cardioProgress() {
      return Math.min(1, this.cardioSeconds / (this.cardioTarget * 60));
    },

    get isResting() {
      return this.phase === 'strengthRest';
    },

    /** Real elapsed time, not a constant. */
    get durationMinutes() {
      return Math.max(1, Math.floor((Date.now() - this.startedAt) / 60000));
    },

    /** Real completion: logged sets over planned sets. */
    get completionPercent() {
      if (!this.plannedSetCount) return 0;
      return Math.round((this.completedSets.length / this.plannedSetCount) * 100);
    },

    get memoryUpdateText() {
      return this.kneeReported ? MockData.kneeMemoryUpdate : MockData.neutralMemoryUpdate;
    },

    get reviewMetrics() {
      return [
        { value: `${this.durationMinutes} 分钟`, label: '训练时长' },
        { value: `${this.completionPercent}%`, label: '完成度' },
        { value: `${this.adjustmentCount} 次`, label: '计划调整' },
      ];
    },

    /* Reports logged sets, and marks anything untouched as unfinished instead
     * of quietly ticking it off. */
    get strengthOutcomes() {
      return this.exercises.map((ex) => {
        const logged = this.completedSets.filter((s) => s.exerciseID === ex.id);
        const last = logged[logged.length - 1];
        return {
          id: ex.id,
          name: ex.name,
          doneSets: logged.length,
          plannedSets: ex.sets,
          reps: ex.reps,
          sideBased: !!ex.sideBased,
          weight: last ? last.weight : ex.weight,
          unit: '组',
        };
      });
    },

    get cardioOutcome() {
      return {
        id: 'cardio',
        name: MockData.cardioName,
        doneSets: this.cardioElapsedMinutes,
        plannedSets: this.cardioTarget,
        reps: '',
        sideBased: false,
        weight: null,
        unit: '分钟',
      };
    },

    // -- strength flow

    enterStrength() {
      if (this.phase === 'planning') {
        this.phase = 'strengthActive';
        this.startedAt = Date.now();
        this.recording = true;
      }
      this.strength.startIfNeeded();
      this.notify();
    },

    completeCurrentSet() {
      if (this.phase !== 'strengthActive') return;

      const exercise = this.currentExercise;
      this.completedSets.push({
        exerciseID: exercise.id,
        exerciseName: exercise.name,
        setNumber: this.currentSet,
        weight: this.currentWeight,
      });

      const wasLastSet = this.currentSet >= exercise.sets;
      const wasLastExercise = this.exerciseIndex >= this.exercises.length - 1;

      if (wasLastSet && wasLastExercise) {
        this.phase = 'strengthComplete';
      } else {
        this.phase = 'strengthRest';
        this.startRest();
      }
      this.notify();
    },

    startRest() {
      clearInterval(this.restTimer);
      this.restRemaining = MockData.restDuration;
      this.restTimer = setInterval(() => {
        this.restRemaining -= 1;
        if (this.restRemaining <= 0) {
          clearInterval(this.restTimer);
          this.restTimer = null;
          this.finishRest();
        }
        this.notify();
      }, 1000);
    },

    skipRest() {
      clearInterval(this.restTimer);
      this.restTimer = null;
      this.finishRest();
      this.notify();
    },

    finishRest() {
      if (this.phase !== 'strengthRest') return;
      this.restRemaining = 0;

      if (this.currentSet >= this.currentExercise.sets) {
        this.exerciseIndex += 1;
        this.currentSet = 1;
        this.announceCurrentExercise();
      } else {
        this.currentSet += 1;
      }
      this.phase = 'strengthActive';
    },

    /** The coach calls the next movement so the user is never guessing. */
    announceCurrentExercise() {
      const exercise = this.currentExercise;
      const override = this.weightOverrides[exercise.id];
      const load = override != null ? override : exercise.weight;
      const loadText = load != null ? `，${Format.kg(load)}` : '';
      this.strength.announce({
        core: `下一个：${exercise.name}，${volumeLabel(exercise)}${loadText}。`,
        gentleLead: '慢慢来，',
        encouragingLead: '节奏很好，',
      });
    },

    // -- cardio flow

    enterCardio() {
      clearInterval(this.restTimer);
      this.restTimer = null;
      if (this.phase !== 'cardioComplete') this.phase = 'cardioActive';
      this.cardio.startIfNeeded();
      this.startCardioTicker();
      this.notify();
    },

    /* Wall-clock, one second at a time. The "完成有氧" control exists for demos
     * precisely because this is real. */
    startCardioTicker() {
      if (this.cardioTimer) return;
      this.cardioTimer = setInterval(() => {
        this.cardioSeconds += 1;
        if (this.cardioSeconds >= this.cardioTarget * 60) {
          clearInterval(this.cardioTimer);
          this.cardioTimer = null;
          if (this.phase === 'cardioActive') this.phase = 'cardioComplete';
        }
        this.notify();
      }, 1000);
    },

    completeCardio() {
      clearInterval(this.cardioTimer);
      this.cardioTimer = null;
      this.cardioSeconds = this.cardioTarget * 60;
      this.phase = 'cardioComplete';
      this.notify();
    },

    // -- review

    enterReview() {
      if (this.phase === 'review') return;
      clearInterval(this.cardioTimer);
      clearInterval(this.restTimer);
      this.cardioTimer = null;
      this.restTimer = null;
      this.phase = 'review';
      this.persistOutcome();
      this.notify();
    },

    /** Closes the session and writes back what the coach learned. */
    persistOutcome() {
      if (this.recording) {
        this.recording = false;
        Store.finishSession({
          id: `s-${this.startedAt}`,
          planTitle: this.plan.title,
          startedAt: this.startedAt,
          durationMinutes: this.durationMinutes,
          completionPercent: this.completionPercent,
        });
      }

      if (!this.kneeReported) return;
      Store.upsertMemory({ id: 'mem-knee', category: 'injury', text: '右膝不适，避免跳跃' });
      Store.upsertMemory({ id: 'mem-knee-followup', category: 'injury', text: '台阶上步先做 2 组' });
    },

    reset() {
      clearInterval(this.restTimer);
      clearInterval(this.cardioTimer);
      this.restTimer = null;
      this.cardioTimer = null;
      this.phase = 'planning';
      this.exerciseIndex = 0;
      this.currentSet = 1;
      this.weightOverrides = {};
      this.swappedExercises = {};
      this.completedSets = [];
      this.restRemaining = 0;
      this.cardioSeconds = 0;
      this.kneeReported = false;
      this.adjustmentCount = 0;
      this.recording = false;
      this.startedAt = Date.now();
      this.makeThreads();
    },

    handle(effect) {
      if (effect.type === 'reduceWeight') {
        // A rewritten prescription — this is what the review counts.
        this.weightOverrides[this.currentExercise.id] = effect.value;
        this.kneeReported = true;
        this.adjustmentCount += 1;
      } else if (effect.type === 'flattenIncline') {
        // A machine setting, not a plan rewrite.
        this.kneeReported = true;
      }
      this.notify();
    },
  };

  // ------------------------------------------------------------- DOM helper

  function el(html) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    return template.content.firstElementChild;
  }

  // ------------------------------------------------------------ Components

  function headerLarge(title, trailing = '', subtitle = null) {
    return `<div class="header header--large">
      <div style="min-width:0">
        <div class="header-title">${title}</div>
        ${subtitle ? `<div class="header-subtitle">${subtitle}</div>` : ''}
      </div>
      <div class="header-trailing" style="margin-left:auto">${trailing}</div>
    </div>`;
  }

  function headerNav(title, { back = true, trailing = '' } = {}) {
    return `<div class="header header--nav">
      ${back ? `<button class="icon-btn" data-back aria-label="返回">${icon('chevron-left', 18)}</button>` : '<div style="width:44px"></div>'}
      <div class="header-title">${title}</div>
      <div class="header-trailing">${trailing}</div>
    </div>`;
  }

  function chip(memory) {
    return `<span class="chip">${icon(MEMORY_SYMBOL[memory.category] || 'dumbbell', 12)}${memory.text}</span>`;
  }

  function memoryNote(title, message, showsMascot = false) {
    return `<div class="memory-note">
      <div style="flex:1">
        <h3>${title}</h3>
        <p>${message}</p>
      </div>
      ${showsMascot ? mascot('point', 44) : ''}
    </div>`;
  }

  function planCard(plan, { featured = false, selected = false } = {}) {
    const size = featured ? 64 : 52;
    const preview = featured
      ? `<div class="plan-preview">${plan.sections
          .find((s) => s.kind === 'strength')
          .exercises.map(
            (ex) => `<div class="plan-preview-row"><span>${ex.name}</span><span class="mono">${volumeLabel(ex)}</span></div>`
          )
          .join('')}</div>`
      : '';

    return `<div class="card ${selected ? 'selected' : ''}" style="padding:${featured ? 16 : 14}px">
      <div class="plan-card-head">
        <div class="plan-thumb" style="width:${size}px;height:${size}px">${icon(plan.symbol, size * 0.42)}</div>
        <div style="min-width:0">
          <div class="plan-card-title">${plan.title}</div>
          ${featured ? '' : `<div class="plan-card-tags">${plan.tags.join(' · ')}</div>`}
        </div>
        ${selected ? `<span class="plan-card-check">${icon('check-circle-fill', 20)}</span>` : ''}
      </div>
      ${preview}
    </div>`;
  }

  function planSectionCard(section) {
    const meta = SECTION_KIND[section.kind];
    const list = section.exercises.length
      ? `<div class="exercise-list">${section.exercises
          .map((ex, i) => {
            const weight = weightLabel(ex);
            return `<div class="exercise-row">
              <div class="exercise-index">${i + 1}</div>
              <div style="min-width:0">
                <div class="exercise-name">${ex.name}</div>
                ${weight ? `<div class="exercise-weight">${weight}</div>` : ''}
              </div>
              <div class="exercise-volume mono">${volumeLabel(ex)}</div>
            </div>`;
          })
          .join('')}</div>`
      : '';

    return `<div class="card">
      <div class="section-head">${icon(meta.symbol, 14)}<span class="section-title">${meta.title}</span><span class="section-duration">${section.duration}</span></div>
      ${section.subtitle ? `<div class="section-subtitle">${section.subtitle}</div>` : ''}
      ${list}
    </div>`;
  }

  function primaryButton(title) {
    return `<button class="primary-btn">${title}</button>`;
  }

  function bottomBar(inner) {
    return `<div class="bottom-bar">${inner}</div>`;
  }

  /** Everything about "what am I doing right now" lives in this one card. */
  function taskCard({ title, metrics, progressLabel, secondaryLabel, progress, venue, pose }) {
    return `<div class="task-card-wrap">
      <div class="card task-card">
        <div class="task-card-top">
          <div style="min-width:0;flex:1">
            ${secondaryLabel ? `<div class="task-secondary" data-secondary>${secondaryLabel}</div>` : ''}
            <div class="task-title" data-title>${title}</div>
            <div class="task-metrics mono" data-metrics>${metrics}</div>
          </div>
          <span data-mascot>${mascot(pose, 56)}</span>
        </div>
        <div class="task-progress-row">
          <span class="task-progress-label mono" data-progress-label>${progressLabel}</span>
          ${venue ? `<span class="task-venue">${venue}</span>` : ''}
        </div>
        ${progress != null ? `<div class="progress-track"><div class="progress-fill" data-progress style="width:${progress * 100}%"></div></div>` : ''}
        <div class="accessory" data-accessory></div>
      </div>
    </div>`;
  }

  function confirmEndDialog(onEnd) {
    const host = document.getElementById('sheet-host');
    const backdrop = el(`<div class="sheet-backdrop">
      <div class="sheet">
        <div class="sheet-group">
          <div class="sheet-title">结束本次训练？</div>
          <button class="sheet-action" data-end>结束并查看复盘</button>
        </div>
        <button class="sheet-cancel" data-cancel>继续训练</button>
      </div>
    </div>`);

    const close = () => host.replaceChildren();
    backdrop.querySelector('[data-end]').addEventListener('click', () => {
      close();
      onEnd();
    });
    backdrop.querySelector('[data-cancel]').addEventListener('click', close);
    backdrop.addEventListener('click', (event) => {
      if (event.target === backdrop) close();
    });
    host.replaceChildren(backdrop);
  }

  // --------------------------------------------------------------- ChatView

  /* Appends only what's new so bubbles don't re-animate on every state tick. */
  function chatView(thread) {
    const root = el('<div class="chat"><div class="chat-inner"></div></div>');
    const inner = root.firstElementChild;
    const rendered = new Map();
    let typingEl = null;

    function update() {
      for (const message of thread.messages) {
        const existing = rendered.get(message.id);
        if (existing) {
          const bubble = existing.querySelector('.bubble');
          if (bubble.textContent !== message.content) bubble.textContent = message.content;
          continue;
        }
        const node = el(`<div class="bubble-row ${message.role}">
          ${message.role === 'assistant' ? mascot('listening', 34) : ''}
          <div class="bubble"></div>
        </div>`);
        node.querySelector('.bubble').textContent = message.content;
        rendered.set(message.id, node);
        inner.appendChild(node);
      }

      if (thread.isTyping && !typingEl) {
        typingEl = el(`<div class="bubble-row assistant">${mascot('listening', 34)}<div class="typing"><i></i><i></i><i></i></div></div>`);
        inner.appendChild(typingEl);
      } else if (!thread.isTyping && typingEl) {
        typingEl.remove();
        typingEl = null;
      } else if (typingEl) {
        inner.appendChild(typingEl); // keep the indicator last
      }

      root.scrollTo({ top: root.scrollHeight, behavior: 'smooth' });
    }

    return { el: root, update };
  }

  // ----------------------------------------------------------- Input bar

  /* keyboard/voice switch · mic · end workout */
  function inputBar(thread, onEnd) {
    const root = el('<div class="input-bar"></div>');
    let mode = null;
    let draft = '';
    let field = null;

    function build() {
      mode = thread.inputMode;
      const switcher = `<button class="icon-btn tint-secondary" data-switch aria-label="${
        mode === 'voice' ? '切换到文字输入' : '切换到语音输入'
      }">${icon(mode === 'voice' ? 'keyboard' : 'waveform', 16)}</button>`;
      const endBtn = `<button class="icon-btn tint-secondary" data-end aria-label="结束训练">${icon('xmark', 16)}</button>`;

      const row =
        mode === 'voice'
          ? `<div class="input-row voice">
               ${switcher}
               <button class="mic-btn" data-mic aria-label="开始语音">
                 <span class="mic-ring r1"></span><span class="mic-ring r2"></span>
                 <span class="mic-core" data-mic-icon>${icon('mic-fill', 24)}</span>
               </button>
               ${endBtn}
             </div>`
          : `<div class="input-row">
               ${switcher}
               <div class="text-field">
                 <input type="text" data-input placeholder="${thread.suggestedUserText || '说点什么…'}">
                 <button class="send-btn" data-send aria-label="发送">${icon('arrow-up', 13)}</button>
               </div>
               ${endBtn}
             </div>`;

      root.innerHTML = `<div data-voice-state></div>${row}`;

      root.querySelector('[data-switch]').addEventListener('click', () => {
        thread.inputMode = thread.inputMode === 'voice' ? 'text' : 'voice';
        build();
        update();
        if (thread.inputMode === 'text' && field) field.focus();
      });
      root.querySelector('[data-end]').addEventListener('click', onEnd);

      const mic = root.querySelector('[data-mic]');
      if (mic) {
        mic.addEventListener('click', () => {
          if (thread.voiceState === 'idle') thread.beginVoiceTurn();
          else thread.cancelVoiceTurn();
        });
      }

      field = root.querySelector('[data-input]');
      if (field) {
        field.value = draft;
        field.addEventListener('input', () => {
          draft = field.value;
          update();
        });
        field.addEventListener('keydown', (event) => {
          if (event.key === 'Enter') submit();
        });
        root.querySelector('[data-send]').addEventListener('click', submit);
      }
    }

    function submit() {
      const text = draft.trim();
      if (!text || thread.isBusy || thread.busyWork) return;
      thread.send(text);
      draft = '';
      if (field) field.value = '';
      update();
    }

    function update() {
      if (mode !== thread.inputMode) build();

      const label = thread.voiceLabel;
      const slot = root.querySelector('[data-voice-state]');
      slot.innerHTML = label ? `<div class="voice-state">${label}</div>` : '';

      const mic = root.querySelector('[data-mic]');
      if (mic) {
        mic.classList.toggle('listening', thread.voiceState === 'listening');
        mic.classList.toggle('busy', thread.voiceState !== 'idle');
        const symbol = { idle: 'mic-fill', listening: 'mic-fill', processing: 'ellipsis', speaking: 'waveform' }[
          thread.voiceState
        ];
        root.querySelector('[data-mic-icon]').innerHTML = icon(symbol, 24);
      }

      if (field) {
        field.placeholder = thread.suggestedUserText || '说点什么…';
        root.querySelector('[data-send]').disabled = !draft.trim() || thread.isBusy;
      }
    }

    build();
    return { el: root, update };
  }

  // ---------------------------------------------------------------- Screens

  /* One answer in the welcome flow. Same card language as the plan library —
   * icon tile, title, one line of consequence — so onboarding doesn't look
   * like a different app. */
  function optionCard(option, selected, multiple = false) {
    const mark = multiple
      ? selected
        ? 'check-square'
        : 'square'
      : selected
        ? 'check-circle-fill'
        : 'circle';

    return `<button class="option-card card ${selected ? 'selected' : ''}" data-option="${option.id}">
      <span class="option-tile ${selected ? 'on' : ''}">${icon(option.symbol, 18)}</span>
      <span class="option-copy">
        <span class="option-title">${option.title || option.label}</span>
        ${option.detail ? `<span class="option-detail">${option.detail}</span>` : ''}
      </span>
      <span class="option-mark ${selected ? 'on' : ''}">${icon(mark, 20)}</span>
    </button>`;
  }

  /* Segments, not dots — the user should see how much is left, and it's short. */
  function stepIndicator(current, total) {
    return `<div class="step-indicator">${Array.from(
      { length: total },
      (_, i) => `<span class="${i <= current ? 'on' : ''}"></span>`
    ).join('')}</div>`;
  }

  function styleSelector(selected) {
    return `<div class="style-selector">
      <div class="style-head"><h3>AI 风格</h3><div data-tooltip></div></div>
      <div class="style-options">
        ${AI_STYLES.map(
          (s) => `<button class="style-option ${selected === s.id ? 'on' : ''}" data-style="${s.id}">${s.label}</button>`
        ).join('')}
      </div>
    </div>`;
  }

  /** Wires a style selector: selection plus the tap-only tooltip. */
  function bindStyleSelector(root, onPick) {
    const slot = root.querySelector('[data-tooltip]');
    let timer = null;
    root.querySelectorAll('[data-style]').forEach((button) => {
      button.addEventListener('click', () => {
        const style = AI_STYLES.find((s) => s.id === button.dataset.style);
        root.querySelectorAll('[data-style]').forEach((b) => b.classList.toggle('on', b === button));
        slot.innerHTML = `<div class="style-tooltip">${style.tooltip}</div>`;
        clearTimeout(timer);
        timer = setTimeout(() => slot.replaceChildren(), 2500);
        onPick(style.id);
      });
    });
  }

  /* /welcome — the first thing a new user sees.
   *
   * Five steps, and every answer after the first becomes an AI memory. The
   * point is not to collect a profile: it's that the coach's opening line in
   * the very first session already reflects the bad knee and the venue the
   * user just named, so "AI 记得你" is true before training starts. */
  function welcomeScreen() {
    const lastStep = 4;
    let step = 0;
    const draft = { goal: 'fatLoss', venue: 'gym', conditions: [], style: 'practical' };

    const root = el(`<div class="screen fade-in">
      <div data-header></div>
      <div class="shell-body">
        <div class="scroll"><div class="scroll-inner" data-content></div></div>
      </div>
      ${bottomBar(primaryButton('继续'))}
    </div>`);

    const headerSlot = root.querySelector('[data-header]');
    const contentSlot = root.querySelector('[data-content]');
    const cta = root.querySelector('.primary-btn');

    function stepContent() {
      if (step === 0) {
        return `<div class="welcome-hero">${mascot('wave', 132)}</div>
          ${MockData.welcomeHighlights
            .map(
              (h) => `<div class="highlight">
                <span class="highlight-icon">${icon(h.symbol, 16)}</span>
                <span>
                  <span class="highlight-title">${h.title}</span>
                  <span class="highlight-body">${h.body}</span>
                </span>
              </div>`
            )
            .join('')}`;
      }
      if (step === 1) return GOALS.map((g) => optionCard(g, draft.goal === g.id)).join('');
      if (step === 2) return VENUES.map((v) => optionCard(v, draft.venue === v.id)).join('');
      if (step === 3) {
        return (
          CONDITIONS.map((c) => optionCard(c, draft.conditions.includes(c.id), true)).join('') +
          optionCard(
            { id: 'none', symbol: 'seal', label: '都没有', detail: '之后训练时说一句，我也会记住。' },
            draft.conditions.length === 0,
            true
          )
        );
      }
      return `${styleSelector(draft.style)}
        <div class="bubble-row assistant" style="margin-top:2px">
          ${mascot('listening', 34)}<div class="bubble" data-sample>${MockData.styleSampleLines[draft.style]}</div>
        </div>
        <div data-seed style="margin-top:2px">${memoryNote('我会记住', seedMemories(draft).map((m) => m.text).join('；'), true)}</div>`;
    }

    function render() {
      const copy = MockData.welcomeSteps[step];
      headerSlot.innerHTML =
        headerLarge(
          copy.title,
          step > 0
            ? `<button class="icon-btn" data-prev aria-label="上一步">${icon('chevron-left', 18)}</button>`
            : '',
          copy.subtitle
        ) + stepIndicator(step, lastStep + 1);

      contentSlot.innerHTML = stepContent();
      contentSlot.classList.remove('step-in');
      void contentSlot.offsetWidth; // restart the fade on every step
      contentSlot.classList.add('step-in');
      cta.textContent = step === lastStep ? '开始使用' : '继续';

      const prev = headerSlot.querySelector('[data-prev]');
      if (prev) prev.addEventListener('click', () => { step -= 1; render(); });

      contentSlot.querySelectorAll('[data-option]').forEach((card) => {
        card.addEventListener('click', () => {
          const id = card.dataset.option;
          if (step === 1) draft.goal = id;
          else if (step === 2) draft.venue = id;
          else if (id === 'none') draft.conditions = [];
          else {
            const at = draft.conditions.indexOf(id);
            if (at >= 0) draft.conditions.splice(at, 1);
            else draft.conditions.push(id);
          }
          render();
        });
      });

      if (step === lastStep) {
        bindStyleSelector(contentSlot, (style) => {
          draft.style = style;
          contentSlot.querySelector('[data-sample]').textContent = MockData.styleSampleLines[style];
        });
      }
    }

    cta.addEventListener('click', () => {
      if (step < lastStep) {
        step += 1;
        render();
        return;
      }
      // The answers become the profile, the memory chips and the coach's tone
      // in one step — nothing is left for the user to set up afterwards.
      Store.completeOnboarding(draft);
      session.setStyle(draft.style);
      nav.popToRoot();
    });

    render();
    return { el: root };
  }

  /* /home — the app's root after onboarding.
   *
   * Two capsule tabs over one page, not two separate screens: 「对话」is where
   * you talk to the coach before training, 「我的计划」is today's plan plus what
   * you have actually finished. The header and the tab bar stay put across the
   * switch so it reads as one place. */
  function homeScreen() {
    let tab = 'chat';
    const thread = session.daily;

    const greeting = (() => {
      const hour = new Date().getHours();
      if (hour >= 5 && hour < 11) return '早上好';
      if (hour >= 11 && hour < 14) return '中午好';
      if (hour >= 14 && hour < 18) return '下午好';
      return '晚上好';
    })();

    const root = el(`<div class="screen fade-in">
      <div data-header></div>
      <div class="shell-body" data-body></div>
      <div class="home-bottom">
        <div data-action></div>
        <div class="tab-bar">
          ${['chat', 'plan']
            .map(
              (id) => `<button class="tab ${id === 'chat' ? 'on' : ''}" data-tab="${id}">
                ${icon(id === 'chat' ? 'chat-bubbles' : 'checklist', 13)}
                <span>${id === 'chat' ? '对话' : '我的计划'}</span>
              </button>`
            )
            .join('')}
        </div>
      </div>
    </div>`);

    const headerSlot = root.querySelector('[data-header]');
    const bodySlot = root.querySelector('[data-body]');
    const actionSlot = root.querySelector('[data-action]');

    const chat = chatView(thread);
    let bar = null;

    function renderHeader() {
      headerSlot.innerHTML = headerLarge(
        greeting,
        mascot(tab === 'chat' ? 'listening' : 'idle', 56),
        tab === 'chat' ? '今天想练点什么？说一句就行。' : '今天的安排和你的记录'
      );
    }

    // -- chat tab

    function mountChat() {
      bodySlot.replaceChildren(chat.el);
      const row = el('<div class="suggestion-row" data-suggestions></div>');
      bodySlot.appendChild(row);

      bar = homeInputBar(thread);
      actionSlot.replaceChildren(bar.el);
      updateChat();
    }

    /* Tappable openers. They disappear as they're used, so the row shrinks to
     * nothing instead of nagging with the same three chips forever. */
    function updateChat() {
      chat.update();
      const row = bodySlot.querySelector('[data-suggestions]');
      if (!row) return;
      const suggestions = thread.remainingSuggestions;
      if (row.dataset.rendered !== suggestions.join('|')) {
        row.dataset.rendered = suggestions.join('|');
        row.innerHTML = suggestions
          .map((text) => `<button class="suggestion">${text}</button>`)
          .join('');
        row.querySelectorAll('.suggestion').forEach((chipEl, i) => {
          chipEl.addEventListener('click', () => thread.send(suggestions[i]));
        });
      }
      if (bar) bar.update();
    }

    // -- plan tab

    function mountPlan() {
      const stats = trainingStats(Store.sessions(), Store.weeklyTarget);
      const memories = Store.activeMemories();
      const sessions = Store.sessions();

      bodySlot.replaceChildren(
        el(`<div class="scroll"><div class="scroll-inner">
          ${todayCard()}
          ${weekStripe(stats)}
          <div class="metric-row">
            ${stats.tiles
              .map((m) => `<div class="metric"><div class="metric-value mono">${m.value}</div><div class="metric-label">${m.label}</div></div>`)
              .join('')}
          </div>
          <div class="plan-section">
            ${sectionTitle('AI 记住的事', `${memories.length} 条`)}
            ${
              memories.length
                ? `<div class="chip-row">${memories.map(chip).join('')}</div>`
                : '<div class="empty-note">还没有记录。训练时说一句，我就记住了。</div>'
            }
          </div>
          ${
            sessions.length
              ? `<div class="plan-section">
                  ${sectionTitle('最近训练', stats.weeklyHeadline)}
                  <div class="history">${sessions.slice(0, 3).map(historyRow).join('')}</div>
                </div>`
              : ''
          }
          ${styleSelector(session.aiStyle)}
        </div></div>`)
      );

      bindStyleSelector(bodySlot, (style) => session.setStyle(style));

      bodySlot.querySelector('[data-full-plan]').addEventListener('click', () => nav.push('legDay'));
      bodySlot.querySelector('[data-other-plans]').addEventListener('click', () => nav.push('plans'));

      actionSlot.replaceChildren(el(bottomBar(primaryButton('开始今天的训练'))));
      actionSlot.querySelector('.primary-btn').addEventListener('click', () => {
        session.enterStrength();
        nav.push('strength');
      });
    }

    function todayCard() {
      return `<div class="card selected">
        <div class="plan-card-head">
          <div class="plan-thumb" style="width:56px;height:56px">${icon(session.plan.symbol, 24)}</div>
          <div style="min-width:0">
            <div class="today-label">今天</div>
            <div class="plan-card-title">${session.plan.title}</div>
            <div class="plan-card-tags">${session.plan.tags.join(' · ')}</div>
          </div>
        </div>
        <div class="today-sections">
          ${session.plan.sections
            .map(
              (s) => `<div class="today-row">
                ${icon(SECTION_KIND[s.kind].symbol, 13)}
                <span>${SECTION_KIND[s.kind].title}</span>
                <span class="mono">${s.duration}</span>
              </div>`
            )
            .join('')}
        </div>
        <div class="today-actions">
          <button class="ghost-btn" data-full-plan>${icon('list', 13)}查看完整计划</button>
          <button class="ghost-btn quiet" data-other-plans>${icon('grid', 13)}换个计划</button>
        </div>
      </div>`;
    }

    function sectionTitle(title, detail) {
      return `<div class="section-label"><span>${title}</span><span class="detail">${detail}</span></div>`;
    }

    function historyRow(record) {
      const complete = record.completionPercent >= 100;
      const date = new Date(record.startedAt);
      return `<div class="history-row">
        <span class="status ${complete ? 'done' : 'partial'}">${icon(complete ? 'check-circle-fill' : 'circle-half', 15)}</span>
        <span style="min-width:0">
          <span class="history-title">${record.planTitle}</span>
          <span class="history-date">${date.getMonth() + 1}/${date.getDate()}</span>
        </span>
        <span class="history-detail mono">${record.durationMinutes} 分钟 · ${record.completionPercent}%</span>
      </div>`;
    }

    /* This week at a glance: seven dots, Monday first, filled for the days that
     * actually have a finished session. Today is ringed even when it's empty. */
    function weekStripe(stats) {
      const today = weekdayIndex(new Date());
      return `<div class="card">
        <div class="week-head">
          <span class="section-title">本周训练</span>
          <span class="week-count mono">${stats.weeklyDone} / ${stats.weeklyTarget} 次</span>
        </div>
        <div class="week-days">
          ${WEEKDAY_LABELS.map((label, i) => {
            const done = stats.completedWeekdays.has(i);
            return `<div class="week-day">
              <span class="${i === today ? 'is-today' : ''}">${label}</span>
              <span class="day-dot ${done ? 'done' : ''} ${i === today && !done ? 'ring' : ''}">${done ? icon('checkmark', 12) : ''}</span>
            </div>`;
          }).join('')}
        </div>
        <div class="progress-track"><div class="progress-fill" style="width:${stats.weeklyProgress * 100}%"></div></div>
      </div>`;
    }

    function switchTo(next) {
      if (tab === next) return;
      tab = next;
      root.querySelectorAll('[data-tab]').forEach((b) => b.classList.toggle('on', b.dataset.tab === tab));
      renderHeader();
      if (tab === 'chat') mountChat();
      else mountPlan();
    }

    root.querySelectorAll('[data-tab]').forEach((button) => {
      button.addEventListener('click', () => switchTo(button.dataset.tab));
    });

    renderHeader();
    mountChat();

    return {
      el: root,
      update: () => {
        if (tab === 'chat') updateChat();
      },
      onEnter: () => thread.startIfNeeded(),
    };
  }

  /* Compact input for the home tab. Deliberately not the workout input bar —
   * there is no session to end here, and the gym-sized mic would crowd out the
   * tab bar. */
  function homeInputBar(thread) {
    const root = el(`<div class="home-input">
      <div class="text-field">
        <input type="text" data-input placeholder="和教练说点什么…">
        <button class="send-btn" data-send aria-label="发送">${icon('arrow-up', 13)}</button>
      </div>
      <button class="icon-btn mic-inline" data-mic aria-label="开始语音">${icon('mic-fill', 16)}</button>
    </div>`);

    const field = root.querySelector('[data-input]');
    const send = root.querySelector('[data-send]');
    const mic = root.querySelector('[data-mic]');

    function submit() {
      const text = field.value.trim();
      if (!text || thread.isBusy || thread.busyWork) return;
      thread.send(text);
      field.value = '';
      update();
    }

    function update() {
      send.disabled = !field.value.trim() || thread.isBusy;
      const idle = thread.voiceState === 'idle';
      mic.classList.toggle('recording', !idle);
      mic.innerHTML = icon(idle ? 'mic-fill' : 'stop', 16);
    }

    field.addEventListener('input', update);
    field.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') submit();
    });
    send.addEventListener('click', submit);
    mic.addEventListener('click', () => {
      if (thread.voiceState === 'idle') thread.beginVoiceTurn();
      else thread.cancelVoiceTurn();
    });

    update();
    return { el: root, update };
  }

  function planLibraryScreen() {
    const root = el(`<div class="screen fade-in">
      ${headerLarge('训练计划库')}
      <div class="shell-body">
        <div class="scroll"><div class="scroll-inner">
          <div class="chip-row">${Store.activeMemories().map(chip).join('')}</div>
          ${planCard(session.plan, { featured: true, selected: true })}
          ${MockData.otherPlans.map((plan) => planCard(plan)).join('')}
        </div></div>
      </div>
      ${bottomBar(primaryButton('查看计划'))}
    </div>`);

    root.querySelector('.primary-btn').addEventListener('click', () => nav.push('legDay'));
    return { el: root };
  }

  function legDayScreen() {
    let starred = false;

    const root = el(`<div class="screen fade-in">
      ${headerNav(session.plan.title, {
        trailing: `<button class="icon-btn tint-secondary" data-star aria-label="收藏">${icon('star', 16)}</button>`,
      })}
      <div class="shell-body">
        <div class="scroll"><div class="scroll-inner">
          ${session.plan.sections.map(planSectionCard).join('')}
          ${memoryNote(session.plan.memoryNote.title, session.plan.memoryNote.body)}
          ${styleSelector(session.aiStyle)}
        </div></div>
      </div>
      ${bottomBar(primaryButton('开始陪练'))}
    </div>`);

    const star = root.querySelector('[data-star]');
    star.addEventListener('click', () => {
      starred = !starred;
      star.innerHTML = icon(starred ? 'star-fill' : 'star', 16);
      star.classList.toggle('tint-primary', starred);
      star.classList.toggle('tint-secondary', !starred);
    });

    bindStyleSelector(root, (style) => session.setStyle(style));

    root.querySelector('.primary-btn').addEventListener('click', () => {
      session.enterStrength();
      nav.push('strength');
    });

    return { el: root };
  }

  function coachScreen(kind) {
    const isStrength = kind === 'strength';
    const thread = isStrength ? session.strength : session.cardio;
    const completePhase = isStrength ? 'strengthComplete' : 'cardioComplete';

    const root = el(`<div class="screen fade-in">
      ${headerNav(isStrength ? '力量陪练' : '有氧陪练')}
      <div class="shell-body">
        ${
          isStrength
            ? taskCard({
                title: session.currentExerciseName,
                metrics: session.strengthMetrics,
                progressLabel: session.setProgressLabel,
                secondaryLabel: session.exerciseProgressLabel,
                venue: MockData.strengthVenue,
                pose: 'dumbbell',
              })
            : taskCard({
                title: MockData.cardioName,
                metrics: MockData.cardioPrescription,
                progressLabel: session.cardioProgressLabel,
                progress: session.cardioProgress,
                pose: 'jogging',
              })
        }
        <div data-chat style="flex:1;display:flex;min-height:0"></div>
      </div>
      <div data-bottom></div>
    </div>`);

    root.querySelector('[data-back]').addEventListener('click', () => nav.back());

    const chat = chatView(thread);
    root.querySelector('[data-chat]').appendChild(chat.el);

    const bottomSlot = root.querySelector('[data-bottom]');
    const bar = inputBar(thread, () =>
      confirmEndDialog(() => {
        // Sets are already logged, so ending early goes to the review and
        // reports the partial session rather than discarding it.
        session.enterReview();
        nav.replaceLast('review');
      })
    );
    let bottomMode = null;

    const accessorySlot = root.querySelector('[data-accessory]');
    let accessoryMode = null;

    function renderAccessory() {
      if (!isStrength) {
        if (accessoryMode === 'cardio-done' || session.phase === 'cardioComplete') {
          if (accessoryMode !== 'cardio-done') {
            accessoryMode = 'cardio-done';
            accessorySlot.replaceChildren();
          }
          return;
        }
        if (accessoryMode !== 'cardio') {
          accessoryMode = 'cardio';
          accessorySlot.innerHTML = `<button class="ghost-btn" data-finish style="margin-left:auto">${icon('flag-checkered', 13)}完成有氧</button>`;
          accessorySlot.querySelector('[data-finish]').addEventListener('click', () => session.completeCardio());
        }
        return;
      }

      const mode = session.isResting ? 'rest' : 'sets';
      if (mode !== accessoryMode) {
        accessoryMode = mode;
        if (mode === 'rest') {
          accessorySlot.innerHTML = `<div class="rest-timer">
            ${icon('timer', 13)}<span class="rest-label">休息</span>
            <span class="rest-clock mono" data-clock></span>
            <button class="rest-skip" data-skip>跳过</button>
          </div>`;
          accessorySlot.querySelector('[data-skip]').addEventListener('click', () => session.skipRest());
        } else {
          accessorySlot.innerHTML = `<div class="set-dots" data-dots></div><div data-set-action style="margin-left:auto"></div>`;
        }
      }

      if (mode === 'rest') {
        accessorySlot.querySelector('[data-clock]').textContent = Format.clock(session.restRemaining);
        return;
      }

      const total = session.currentExercise.sets;
      const done = session.completedSetsForCurrentExercise;
      const dots = accessorySlot.querySelector('[data-dots]');
      if (dots.children.length !== total) {
        dots.innerHTML = Array.from({ length: total }, () => `<span class="set-dot">${icon('checkmark', 8)}</span>`).join('');
      }
      Array.from(dots.children).forEach((dot, i) => dot.classList.toggle('done', i < done));

      const action = accessorySlot.querySelector('[data-set-action]');
      const actionMode = session.phase === 'strengthActive' ? 'active' : 'done';
      if (action.dataset.mode !== actionMode) {
        action.dataset.mode = actionMode;
        if (actionMode === 'active') {
          action.innerHTML = `<button class="ghost-btn" data-set>${icon('checkmark', 13)}完成这组</button>`;
          action.querySelector('[data-set]').addEventListener('click', () => session.completeCurrentSet());
        } else {
          action.innerHTML = `<span class="accessory-done">${icon('check-circle-fill', 14)}力量完成</span>`;
        }
      }
    }

    function renderBottom() {
      const mode = session.phase === completePhase ? 'cta' : 'input';
      if (mode === bottomMode) {
        if (mode === 'input') bar.update();
        return;
      }
      bottomMode = mode;

      if (mode === 'cta') {
        const cta = el(
          bottomBar(primaryButton(isStrength ? '力量部分完成，进入有氧' : '有氧完成，查看复盘'))
        );
        cta.querySelector('.primary-btn').addEventListener('click', () => {
          if (isStrength) {
            session.enterCardio();
            nav.replaceLast('cardio');
          } else {
            session.enterReview();
            nav.replaceLast('review');
          }
        });
        bottomSlot.replaceChildren(cta);
      } else {
        bottomSlot.replaceChildren(bar.el);
        bar.update();
      }
    }

    function update() {
      if (isStrength) {
        root.querySelector('[data-title]').textContent = session.currentExerciseName;
        root.querySelector('[data-metrics]').textContent = session.strengthMetrics;
        root.querySelector('[data-progress-label]').textContent = session.setProgressLabel;
        root.querySelector('[data-secondary]').textContent = session.exerciseProgressLabel;
        root.querySelector('[data-mascot]').innerHTML = mascot(session.isResting ? 'drink' : 'dumbbell', 56);
      } else {
        root.querySelector('[data-progress-label]').textContent = session.cardioProgressLabel;
        root.querySelector('[data-progress]').style.width = `${session.cardioProgress * 100}%`;
        root.querySelector('[data-mascot]').innerHTML = mascot(
          session.phase === 'cardioComplete' ? 'thumbs-up' : 'jogging',
          56
        );
      }
      renderAccessory();
      renderBottom();
      chat.update();
    }

    return {
      el: root,
      update,
      onEnter: () => (isStrength ? session.enterStrength() : session.enterCardio()),
    };
  }

  /* Reports logged work only. An exercise the user never reached shows as
   * unfinished rather than getting a green tick. */
  function reviewSummary(title, symbol, outcomes) {
    const allComplete = outcomes.every((o) => o.doneSets >= o.plannedSets);
    const rows = outcomes
      .map((o) => {
        const complete = o.doneSets >= o.plannedSets;
        const untouched = o.doneSets === 0;
        const statusIcon = complete ? 'check-circle-fill' : untouched ? 'circle' : 'circle-half';
        const statusClass = complete ? 'done' : untouched ? 'empty' : 'partial';
        const detail =
          o.unit === '分钟'
            ? `${o.doneSets} / ${o.plannedSets} 分钟`
            : `${o.doneSets} / ${o.plannedSets} 组 · ${o.reps} 次${o.sideBased ? ' / 侧' : ''}`;
        return `<div class="review-row ${untouched ? 'untouched' : ''}">
          <span class="status ${statusClass}">${icon(statusIcon, 14)}</span>
          <span class="name">${o.name}</span>
          <span class="detail mono">${detail}</span>
        </div>`;
      })
      .join('');

    return `<div class="card">
      <div class="section-head">
        ${icon(symbol, 14)}<span class="section-title">${title}</span>
        <span class="status ${allComplete ? 'done' : 'pending'}">${icon(allComplete ? 'check-circle-fill' : 'circle-dotted', 18)}</span>
      </div>
      <div class="review-rows">${rows}</div>
    </div>`;
  }

  function reviewScreen() {
    const complete = session.completionPercent >= 100;

    const root = el(`<div class="screen fade-in">
      ${headerLarge(complete ? '今天完成了' : '今天练到这里', mascot(complete ? 'celebration' : 'idle', 64))}
      <div class="shell-body">
        <div class="scroll"><div class="scroll-inner">
          ${reviewSummary(session.plan.title, 'dumbbell-fill', session.strengthOutcomes)}
          ${reviewSummary('有氧', 'run', [session.cardioOutcome])}
          ${memoryNote('AI 记忆更新', session.memoryUpdateText, true)}
          <div class="metric-row">
            ${session.reviewMetrics
              .map((m) => `<div class="metric"><div class="metric-value mono">${m.value}</div><div class="metric-label">${m.label}</div></div>`)
              .join('')}
          </div>
        </div></div>
      </div>
      ${bottomBar(primaryButton('完成'))}
    </div>`);

    root.querySelector('.primary-btn').addEventListener('click', () => {
      session.reset();
      nav.popToRoot();
    });

    return { el: root, onEnter: () => session.enterReview() };
  }

  // ----------------------------------------------------------------- Router

  const SCREENS = {
    welcome: welcomeScreen,
    home: homeScreen,
    plans: planLibraryScreen,
    legDay: legDayScreen,
    strength: () => coachScreen('strength'),
    cardio: () => coachScreen('cardio'),
    review: reviewScreen,
  };

  const PATHS = {
    welcome: '/welcome',
    home: '/home',
    plans: '/plans',
    legDay: '/plans/leg-day',
    strength: '/workout/strength',
    cardio: '/workout/cardio',
    review: '/workout/review',
  };

  let currentScreen = null;

  /** A stored profile means onboarding is done; without one, /welcome is root. */
  function rootRoute() {
    return Store.hasProfile ? 'home' : 'welcome';
  }

  const nav = {
    stack: ['home'],

    get route() {
      return this.stack[this.stack.length - 1];
    },

    push(route) {
      this.stack.push(route);
      this.render();
    },

    /* Replace the coaching page rather than stacking them, so "back" from
     * cardio never lands on a finished strength session. */
    replaceLast(route) {
      if (!this.stack.length) this.stack.push(route);
      else this.stack[this.stack.length - 1] = route;
      this.render();
    },

    back() {
      if (this.stack.length > 1) this.stack.pop();
      this.render();
    },

    popToRoot() {
      this.stack = [rootRoute()];
      this.render();
    },

    render() {
      const host = document.getElementById('screen');
      const screen = SCREENS[this.route]();

      host.replaceChildren(screen.el);
      currentScreen = screen;
      if (screen.update) screen.update();
      if (screen.onEnter) screen.onEnter();

      location.hash = `#${PATHS[this.route]}`;
      document.getElementById('sheet-host').replaceChildren();
    },
  };

  // Deep-link straight to a screen, mirroring the app's DEBUG `-route` flag.
  function initialStack() {
    // Onboarding always wins: there is no plan to look at without a profile.
    if (!Store.hasProfile) return ['welcome'];

    const path = location.hash.replace(/^#/, '');
    const route = Object.keys(PATHS).find((key) => PATHS[key] === path);
    if (!route || route === 'home' || route === 'welcome') return ['home'];
    if (route === 'plans' || route === 'legDay') return ['home', route];
    return ['home', 'legDay', route];
  }

  /* Editing the hash — or using browser back/forward — navigates. Our own
   * `location.hash` writes land on the route we're already showing, so they
   * fall through the guard instead of re-rendering. */
  window.addEventListener('hashchange', () => {
    const stack = initialStack();
    if (stack[stack.length - 1] === nav.route) return;
    nav.stack = stack;
    nav.render();
  });

  session.init();
  nav.stack = initialStack();
  nav.render();
})();
