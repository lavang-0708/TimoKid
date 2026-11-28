// Thống kê mới (ví không tính xu thử, đấu trường, đề tự soạn, hồ sơ bé) và các loader dùng fetch giả.
import { describe, expect, it } from 'vitest';
import { loadBalances, loadExtras, updateChild } from './data';
import { NeonHttp } from './http';
import {
  messageStatusText,
  sumBalances,
  summarizeArena,
  summarizeCustomUsage,
  validateChildEdit,
} from './logic';
import { GIFT_ITEMS, giftItemName } from './items';
import { petSpeciesName } from './labels';

function jwt(): string {
  const b = (o: unknown) => btoa(JSON.stringify(o)).replace(/=/g, '');
  return `${b({ alg: 'none' })}.${b({ exp: 4102444800 })}.s`;
}

/** NeonHttp với fetch giả: `routes` khớp theo chuỗi con của đường dẫn Data API. */
function fake(routes: Record<string, { status?: number; json: unknown }>) {
  const calls: { url: string; method: string; body: unknown }[] = [];
  const fetchImpl = (async (url: string, init: RequestInit = {}) => {
    if (url.endsWith('/token')) return new Response(JSON.stringify({ token: jwt() }), { status: 200 });
    calls.push({ url, method: init.method ?? 'GET', body: init.body ? JSON.parse(String(init.body)) : undefined });
    const key = Object.keys(routes).find((k) => url.includes(k));
    const r = key ? routes[key] : { status: 200, json: [] };
    return new Response(JSON.stringify(r.json), { status: r.status ?? 200 });
  }) as typeof fetch;
  return { http: new NeonHttp({ fetchImpl, authUrl: 'https://auth.test/auth', apiUrl: 'https://api.test/rest/v1' }), calls };
}

describe('sumBalances: bỏ xu/kim cương của bản thử', () => {
  it('chỉ cộng dòng thật', () => {
    const rows = [
      { currency: 'xu', amount: 10000, reason: 'test_grant' },
      { currency: 'gem', amount: 10000, reason: 'test_grant' },
      { currency: 'xu', amount: 10000, reason: 'test_topup' },
      { currency: 'xu', amount: 25, reason: 'answer' },
      { currency: 'xu', amount: '5', reason: 'mail_gift' },
      { currency: 'gem', amount: 3, reason: 'daily_complete' },
      { currency: 'xu', amount: -10, reason: 'shop' },
    ];
    expect(sumBalances(rows)).toEqual({ xu: 20, gem: 3 });
  });
  it('tiêu xu thử làm tổng âm thì hiện 0', () => {
    expect(sumBalances([{ currency: 'xu', amount: -300, reason: 'shop' }])).toEqual({ xu: 0, gem: 0 });
  });
  it('loadBalances yêu cầu server loại sẵn các lý do thử và vẫn lọc phía trình duyệt', async () => {
    const { http, calls } = fake({
      wallet_ledger: {
        json: [
          { currency: 'xu', amount: 10000, reason: 'test_grant' },
          { currency: 'xu', amount: 12, reason: 'answer' },
        ],
      },
    });
    expect(await loadBalances(http, 'kid1')).toEqual({ xu: 12, gem: 0 });
    expect(decodeURIComponent(calls[0].url)).toContain('reason=not.in.(test_grant,test_topup,test_cleanup)');
  });
});

describe('summarizeArena', () => {
  it('đếm huy chương theo vòng, điểm cao nhất, kim cương', () => {
    const s = summarizeArena([
      { mode: 'heat', medal: 'gold', score: 90, gems_awarded: 2 },
      { mode: 'heat', medal: 'participant', score: '40', gems_awarded: 0 },
      { mode: 'final', medal: 'silver', score: 120, gems_awarded: 5 },
    ]);
    expect(s.heats).toBe(2);
    expect(s.finals).toBe(1);
    expect(s.medals.heat).toEqual({ gold: 1, silver: 0, bronze: 0, participant: 1 });
    expect(s.medals.final.silver).toBe(1);
    expect(s.bestScore).toBe(120);
    expect(s.gems).toBe(7);
  });
  it('rỗng', () => {
    const s = summarizeArena([]);
    expect(s.bestScore).toBeNull();
    expect(s.heats + s.finals).toBe(0);
  });
});

describe('summarizeCustomUsage', () => {
  it('chỉ tính form_id bắt đầu bằng custom:', () => {
    const u = summarizeCustomUsage([
      { form_id: 'custom:a', correct_first_try: true },
      { form_id: 'custom:a', correct_first_try: false },
      { form_id: 'custom:b', correct_first_try: true },
      { form_id: 'logic.age', correct_first_try: true },
    ]);
    expect(u).toEqual({ attempts: 3, correctFirstTry: 2, distinctQuestions: 2 });
  });
});

describe('loadExtras', () => {
  it('bảng chưa có trên server (404): trả null thay vì lỗi', async () => {
    const { http } = fake({
      'pets?': { status: 404, json: { code: 'PGRST205', message: 'no table' } },
      'arena_attempts?': { status: 404, json: { code: 'PGRST205', message: 'no table' } },
      'custom_questions?': { status: 404, json: { code: 'PGRST205', message: 'no table' } },
      'skill_progress?': { json: [{ key: 'a' }, { key: 'b' }, { key: 'a' }] },
      'attempts?': { json: [{ form_id: 'custom:x', correct_first_try: true }] },
    });
    const d = await loadExtras(http, 'kid1');
    expect(d.pets).toBeNull();
    expect(d.arena).toBeNull();
    expect(d.customActive).toBeNull();
    expect(d.stickers).toBe(2);
    expect(d.custom.attempts).toBe(1);
  });
  it('có dữ liệu', async () => {
    const { http } = fake({
      'pets?': { json: [{ species: 'dog', xp: 12, stage_seen: 'teen', hatched: true, active: true }] },
      'arena_attempts?': { json: [{ mode: 'heat', medal: 'bronze', score: 50, gems_awarded: 1 }] },
      'custom_questions?': {
        json: [
          { id: '1', active: true, child_id: null },
          { id: '2', active: true, child_id: 'kid1' },
          { id: '3', active: true, child_id: 'other' },
        ],
      },
    });
    const d = await loadExtras(http, 'kid1');
    expect(d.pets).toHaveLength(1);
    expect(d.arena?.medals.heat.bronze).toBe(1);
    expect(d.customActive).toBe(2);
  });
  it('lỗi khác 404 vẫn được ném', async () => {
    const { http } = fake({ 'pets?': { status: 500, json: { message: 'boom' } } });
    await expect(loadExtras(http, 'kid1')).rejects.toBeTruthy();
  });
});

describe('sửa hồ sơ bé', () => {
  it('kiểm tra tên và lớp', () => {
    expect(validateChildEdit('  Na ', 3)).toEqual({ ok: true, value: { name: 'Na', grade: 3 } });
    expect(validateChildEdit('', 2)).toMatchObject({ ok: false });
    expect(validateChildEdit('x'.repeat(41), 2)).toMatchObject({ ok: false });
    expect(validateChildEdit('Na', 0)).toMatchObject({ ok: false });
    expect(validateChildEdit('Na', '6')).toMatchObject({ ok: false });
    expect(validateChildEdit('Na', 2.5)).toMatchObject({ ok: false });
  });
  it('PATCH children theo id kèm updated_at mới', async () => {
    const { http, calls } = fake({ 'children?': { json: [] } });
    await updateChild(http, 'kid-1', { name: 'Na', grade: 3 });
    expect(calls[0].method).toBe('PATCH');
    expect(calls[0].url).toContain('children?id=eq.kid-1');
    const body = calls[0].body as { name: string; grade: number; updated_at: string };
    expect(body.name).toBe('Na');
    expect(body.grade).toBe(3);
    expect(Date.now() - Date.parse(body.updated_at)).toBeLessThan(5000);
  });
});

describe('thư: trạng thái và món quà', () => {
  it('chưa mở / đã mở lúc / đã nhận quà', () => {
    expect(messageStatusText({ opened_at: null, claimed_at: null })).toBe('Chưa mở');
    expect(messageStatusText({ opened_at: '2026-11-21T07:05:00Z', claimed_at: null })).toBe('Bé đã mở lúc 14:05 21/11/2026');
    expect(messageStatusText({ opened_at: '2026-11-21T07:05:00Z', claimed_at: '2026-11-21T07:06:00Z' })).toBe(
      'Đã nhận quà lúc 14:06 21/11/2026',
    );
  });
  it('danh mục món tặng có mã duy nhất và tên', () => {
    const ids = GIFT_ITEMS.map((i) => i.id);
    expect(new Set(ids).size).toBe(ids.length);
    expect(giftItemName('glasses')).toBe('Kính tròn');
    expect(giftItemName('khong-co')).toBe('khong-co');
  });
  it('tên loài pet đủ 6 loài của app', () => {
    for (const s of ['dog', 'cat', 'rabbit', 'squirrel', 'capybara', 'dragon']) expect(petSpeciesName(s)).not.toBe(s);
  });
});
