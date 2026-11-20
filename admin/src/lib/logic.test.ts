import { describe, expect, it } from 'vitest';
import {
  addDays,
  dayRange,
  formatDuration,
  formatVnDateTime,
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
