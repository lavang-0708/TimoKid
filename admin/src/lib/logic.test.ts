import { describe, expect, it } from 'vitest';
import {
  addDays,
  dayRange,
  formatDuration,
  buildCharacterView,
  countFullyDoneSets,
  formStatsByStrand,
  formatVnDateTime,
  parseFlag,
  petDaysToNextStage,
  petStageForDays,
  messageStatus,
  relativeVi,
  summarizeStats,
  validateMessage,
  vnDay,
  weakForms,
} from './logic';
import { formLabel } from './labels';
import { jwtFresh } from './http';

describe('ngày theo giờ Việt Nam', () => {
  it('17:00 UTC đã là ngày hôm sau ở Việt Nam', () => {
    expect(vnDay('2026-11-20T16:59:59Z')).toBe('2026-11-20');
    expect(vnDay('2026-11-20T17:00:00Z')).toBe('2026-11-21');
  });
  it('addDays qua ranh giới tháng và năm', () => {
    expect(addDays('2026-11-30', 1)).toBe('2026-12-01');
    expect(addDays('2026-01-01', -1)).toBe('2025-12-31');
  });
  it('dayRange 7 ngày kết thúc hôm nay (giờ VN), cũ -> mới', () => {
    const r = dayRange(7, Date.parse('2026-11-20T18:00:00Z')); // 01:00 ngày 21 giờ VN
    expect(r).toHaveLength(7);
    expect(r[0]).toBe('2026-11-15');
    expect(r[6]).toBe('2026-11-21');
  });
});

describe('summarizeStats', () => {
  const days = dayRange(3, Date.parse('2026-11-21T05:00:00Z'));
  const rows = [
    { day: '2026-11-21', strand: 'logic', questions: 10, correct_first_try: 8, duration_ms: 120000 },
    { day: '2026-11-21', strand: 'arith', questions: 5, correct_first_try: 5, duration_ms: 60000 },
    { day: '2026-11-19', strand: 'logic', questions: '4' as unknown as number, correct_first_try: '1' as unknown as number, duration_ms: '30000' as unknown as number },
    { day: '2026-10-01', strand: 'geo', questions: 99, correct_first_try: 99, duration_ms: 1 }, // ngoài khoảng
  ];
  it('cộng đúng tổng, theo mảng và theo ngày', () => {
    const s = summarizeStats(rows, days);
    expect(s.questions).toBe(19);
    expect(s.correctFirstTry).toBe(14);
    expect(s.accuracy).toBeCloseTo(14 / 19);
    expect(s.durationMs).toBe(210000);
    expect(s.perStrand.find((x) => x.strand === 'logic')?.questions).toBe(14);
    expect(s.perStrand.find((x) => x.strand === 'geo')?.questions).toBe(0);
    expect(s.perDay.map((d) => d.minutes)).toEqual([0.5, 0, 3]);
  });
  it('không có dữ liệu thì tỉ lệ là null', () => {
    expect(summarizeStats([], days).accuracy).toBeNull();
  });
});

describe('weakForms', () => {
  const mk = (form: string, ok: number, bad: number) => [
    ...Array.from({ length: ok }, () => ({ form_id: form, correct_first_try: true })),
    ...Array.from({ length: bad }, () => ({ form_id: form, correct_first_try: false })),
  ];
  it('cần >= 5 lượt và < 60%', () => {
    const w = weakForms([
      ...mk('logic.age', 2, 3), // 40%, 5 lượt -> yếu
      ...mk('arith.quick', 3, 2), // đúng 60% -> không yếu
      ...mk('geo.perim', 0, 4), // chỉ 4 lượt -> không tính
      ...mk('comb.outfit', 1, 9), // 10% -> yếu nhất
    ]);
    expect(w.map((x) => x.formId)).toEqual(['comb.outfit', 'logic.age']);
    expect(w[0]).toMatchObject({ attempts: 10, correctFirstTry: 1 });
  });
});

describe('validateMessage', () => {
  const ok = { body: ' Con giỏi lắm ', giftXu: '', giftGem: '', giftItemId: '' };
  it('thư hợp lệ, quà mặc định 0', () => {
    expect(validateMessage(ok)).toEqual({ ok: true, value: { body: 'Con giỏi lắm', gift_xu: 0, gift_gem: 0, gift_item_id: null } });
  });
  it('từ chối thư rỗng và quá 300 ký tự', () => {
    expect(validateMessage({ ...ok, body: '   ' }).ok).toBe(false);
    expect(validateMessage({ ...ok, body: 'a'.repeat(300) }).ok).toBe(true);
    expect(validateMessage({ ...ok, body: 'a'.repeat(301) }).ok).toBe(false);
  });
  it('xu 0-1000, kim cương 0-100, phải là số nguyên', () => {
    expect(validateMessage({ ...ok, giftXu: '1000', giftGem: '100' }).ok).toBe(true);
    expect(validateMessage({ ...ok, giftXu: '1001' }).ok).toBe(false);
    expect(validateMessage({ ...ok, giftGem: '101' }).ok).toBe(false);
    expect(validateMessage({ ...ok, giftXu: '-5' }).ok).toBe(false);
    expect(validateMessage({ ...ok, giftXu: '2.5' }).ok).toBe(false);
  });
  it('mã món đồ được cắt khoảng trắng', () => {
    const r = validateMessage({ ...ok, giftItemId: ' hat_01 ' });
    expect(r.ok && r.value.gift_item_id).toBe('hat_01');
  });
});

describe('định dạng và trạng thái', () => {
  it('trạng thái thư', () => {
    expect(messageStatus({ opened_at: null, claimed_at: null })).toBe('unopened');
    expect(messageStatus({ opened_at: 'x', claimed_at: null })).toBe('opened');
    expect(messageStatus({ opened_at: 'x', claimed_at: 'y' })).toBe('claimed');
  });
  it('thời gian tuyệt đối theo giờ Việt Nam', () => {
    expect(formatVnDateTime('2026-11-20T17:05:00Z')).toBe('00:05 21/11/2026');
  });
  it('thời gian tương đối', () => {
    const now = Date.parse('2026-11-21T12:00:00Z');
    expect(relativeVi('2026-11-21T11:59:30Z', now)).toBe('vừa xong');
    expect(relativeVi('2026-11-21T11:55:00Z', now)).toBe('5 phút trước');
    expect(relativeVi('2026-11-21T09:00:00Z', now)).toBe('3 giờ trước');
    expect(relativeVi('2026-11-19T12:00:00Z', now)).toBe('2 ngày trước');
  });
  it('thời lượng', () => {
    expect(formatDuration(0)).toBe('0 phút');
    expect(formatDuration(65 * 60000)).toBe('1 giờ 05 phút');
  });
  it('nhãn dạng bài, mã lạ giữ nguyên', () => {
    expect(formLabel('logic.age')).toBe('Tuổi');
    expect(formLabel('xyz.unknown')).toBe('xyz.unknown');
  });
});

describe('jwtFresh', () => {
  const mk = (exp: number) => `h.${btoa(JSON.stringify({ exp })).replace(/=/g, '')}.s`;
  it('còn hạn / sắp hết hạn / rác', () => {
    const now = 1_000_000_000_000;
    expect(jwtFresh(mk(now / 1000 + 600), now)).toBe(true);
    expect(jwtFresh(mk(now / 1000 + 30), now)).toBe(false);
    expect(jwtFresh('abc', now)).toBe(false);
    expect(jwtFresh(null, now)).toBe(false);
  });
});

describe('thống kê từng dạng', () => {
  const att = (form_id: string, ok: boolean, n = 1) =>
    Array.from({ length: n }, () => ({ form_id, correct_first_try: ok }));
  const ids = ['logic.age', 'logic.backward', 'logic.cut', 'geo.fence', 'arith.quick'];

  it('liệt kê cả dạng chưa làm, gom theo mảng và đúng thứ tự mảng', () => {
    const r = formStatsByStrand([], ids);
    expect(r.map((s) => s.strand)).toEqual(['logic', 'arith', 'number', 'geo', 'comb']);
    expect(r[0].total).toBe(3);
    expect(r[0].attempted).toBe(0);
    expect(r[0].accuracy).toBeNull();
    expect(r[0].forms.every((f) => f.attempts === 0 && f.accuracy === null && !f.weak)).toBe(true);
  });

  it('dạng yếu trước, rồi đúng thấp trước, chưa làm cuối', () => {
    const a = [
      ...att('logic.age', true, 5), // 100%
      ...att('logic.backward', true, 1), ...att('logic.backward', false, 5), // 1/6 yếu
    ];
    const logic = formStatsByStrand(a, ids)[0];
    expect(logic.forms.map((f) => f.formId)).toEqual(['logic.backward', 'logic.age', 'logic.cut']);
    expect(logic.forms[0]).toMatchObject({ attempts: 6, correctFirstTry: 1, weak: true });
    expect(logic.attempted).toBe(2);
    expect(logic.attempts).toBe(11);
    expect(logic.accuracy).toBeCloseTo(6 / 11);
  });

  it('ít hơn 5 lượt thì chưa gọi là yếu dù đúng 0%', () => {
    const f = formStatsByStrand(att('geo.fence', false, 4), ids)[3].forms.find((x) => x.formId === 'geo.fence')!;
    expect(f.weak).toBe(false);
    expect(f.accuracy).toBe(0);
  });

  it('dạng không có trong danh sách app nhưng có lượt làm vẫn hiện; mã lạ bị bỏ', () => {
    const r = formStatsByStrand([...att('arith.old', true, 2), ...att('zzz.x', true, 2)], ids);
    expect(r[1].forms.map((f) => f.formId)).toContain('arith.old');
    expect(r.flatMap((s) => s.forms).some((f) => f.formId === 'zzz.x')).toBe(false);
  });
});

describe('pet lớn dần', () => {
  it('mốc giai đoạn 0-2 / 3-7 / từ 8', () => {
    expect([0, 2].map(petStageForDays)).toEqual(['newborn', 'newborn']);
    expect([3, 7].map(petStageForDays)).toEqual(['teen', 'teen']);
    expect([8, 30].map(petStageForDays)).toEqual(['adult', 'adult']);
  });
  it('số ngày tới giai đoạn sau', () => {
    expect(petDaysToNextStage(0)).toBe(3);
    expect(petDaysToNextStage(2)).toBe(1);
    expect(petDaysToNextStage(3)).toBe(5);
    expect(petDaysToNextStage(7)).toBe(1);
    expect(petDaysToNextStage(8)).toBeNull();
  });
  it('chỉ tính đề có đủ 5 chặng đều done (chuỗi JSON hoặc mảng)', () => {
    const done = ['done', 'done', 'done', 'done', 'done'];
    expect(
      countFullyDoneSets([
        { stage_status: done },
        { stage_status: JSON.stringify(done) },
        { stage_status: ['done', 'done', 'done', 'done', 'todo'] },
        { stage_status: ['done', 'done', 'done', 'done'] },
        { stage_status: 'hỏng' },
      ]),
    ).toBe(2);
  });
});

describe('hồ sơ nhân vật', () => {
  it('chưa có dòng nào -> null (app chưa đồng bộ)', () => {
    expect(buildCharacterView({}, 0)).toBeNull();
    expect(buildCharacterView({ kid_glasses: undefined }, 5)).toBeNull();
  });
  it('đọc hồ sơ dạng chuỗi JSON, phụ kiện, cờ chuỗi và pet', () => {
    const v = buildCharacterView(
      {
        character_profile: JSON.stringify({ gender: 'boy', name: ' Bé A ', dress: 'boy_outfit_03' }),
        kid_head_accessory: 'bow',
        kid_glasses: 'true',
        kid_white_shoes: 'false',
        kid_backpack: true,
        selected_egg: 'cat',
        egg_hatched: 'true',
      },
      4,
    )!;
    expect(v).toMatchObject({
      name: 'Bé A', gender: 'boy', outfitNumber: 3, head: 'bow',
      glasses: true, whiteShoes: false, backpack: true,
      species: 'cat', hatched: true, stage: 'teen', daysToNext: 4,
    });
  });
  it('dress null hoặc lạ -> bộ 1; giá trị lạ -> mặc định an toàn', () => {
    const v = buildCharacterView(
      { character_profile: { gender: 'x', dress: null }, kid_head_accessory: 'none', selected_egg: 'dragon' },
      0,
    )!;
    expect(v).toMatchObject({ gender: 'girl', outfitNumber: 1, head: null, species: null, stage: null });
    expect(buildCharacterView({ character_profile: { dress: 'girl_top_09' } }, 0)!.outfitNumber).toBe(1);
  });
  it('chưa nở -> giai đoạn trứng; trưởng thành -> không còn ngày tới', () => {
    expect(buildCharacterView({ selected_egg: 'dog' }, 9)).toMatchObject({ stage: 'egg', daysToNext: null });
    expect(buildCharacterView({ selected_egg: 'dog', egg_hatched: 'true' }, 9)).toMatchObject({ stage: 'adult', daysToNext: null });
  });
  it('parseFlag', () => {
    expect([parseFlag('true'), parseFlag(true), parseFlag('false'), parseFlag(undefined), parseFlag(null)]).toEqual([true, true, false, false, false]);
  });
});
