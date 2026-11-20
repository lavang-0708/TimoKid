// Kiểm thử đầu-cuối với backend THẬT (Neon Auth + Data API). Không chạy trong CI.
// Chạy tay:  npm run test:e2e
// Mỗi lần chạy đăng ký một tài khoản thử mới `rls-admin-<ngẫu nhiên>@example.com`
// (tiền tố `rls-` để chủ dự án dọn bằng db/tests/cleanup_test_accounts.sql).
// Vì web admin không tạo được bé, test chèn một bé thử bằng chính JWT của tài khoản.
import { randomBytes, randomUUID } from 'node:crypto';
import { beforeAll, describe, expect, it } from 'vitest';
import {
  deleteUnopenedMessage,
  ensureFamily,
  listChildren,
  listMessages,
  loadForms,
  loadSettings,
  loadStats,
  saveSetting,
  sendMessage,
  getSetting,
} from './data';
import { NeonHttp } from './http';
import { addDays, messageStatus, validateMessage, vnDay } from './logic';

const AUTH =
  process.env.TIMOKID_AUTH_URL ??
  'https://ep-damp-waterfall-a1cu82wt.neonauth.ap-southeast-1.aws.neon.tech/timokid/auth';
const API =
  process.env.TIMOKID_API_URL ??
  'https://ep-damp-waterfall-a1cu82wt.apirest.ap-southeast-1.aws.neon.tech/timokid/rest/v1';

/** fetch cho Node: thêm Origin và giữ cookie phiên như trình duyệt. */
function cookieFetch(): typeof fetch {
  let cookie = '';
  return (async (url: string, init: RequestInit = {}) => {
    const headers = new Headers(init.headers);
    headers.set('Origin', 'https://lavang-0708.github.io');
    if (cookie && String(url).startsWith(AUTH)) headers.set('Cookie', cookie);
    const res = await fetch(url, { ...init, headers });
    const set = res.headers.getSetCookie?.() ?? [];
    if (set.length) cookie = set.map((c) => c.split(';')[0]).join('; ');
    return res;
  }) as typeof fetch;
}

const email = `rls-admin-${randomBytes(4).toString('hex')}@example.com`;
const password = `Pw-${randomBytes(9).toString('base64url')}-1`;
const http = new NeonHttp({ authUrl: AUTH, apiUrl: API, fetchImpl: cookieFetch() });
const childId = randomUUID();
const now = Date.now();
const ago = (days: number, extraMs = 0) => new Date(now - days * 86400_000 - extraMs).toISOString();
const post = (table: string, rows: unknown[]) =>
  http.api(table, { method: 'POST', body: rows, headers: { Prefer: 'return=minimal' } });

function attempts(form: string, strand: string, ok: number, bad: number, whenIso: string) {
  return [...Array(ok).fill(true), ...Array(bad).fill(false)].map((c, i) => ({
    id: randomUUID(), child_id: childId, form_id: form, strand, level: 1, rung: 1,
    answer_type: 'choice', correct_first_try: c, attempts_count: c ? 1 : 2, duration_ms: 10_000,
    created_at: new Date(Date.parse(whenIso) - i * 1000).toISOString(),
  }));
}

describe('web admin với backend thật', () => {
  beforeAll(async () => {
    console.log('Tài khoản thử:', email);
    await http.signUp(email, password, 'RLS admin');
    const user = await http.restore(); // khôi phục phiên bằng cookie + JWT, như lúc tải lại trang
    expect(user?.email).toBe(email);
    const fam = await ensureFamily(http);
    expect(fam.id).toBeTruthy();
    expect((await ensureFamily(http)).id).toBe(fam.id);

    // Bé thử (admin thật không tạo được; app của bé tạo qua đồng bộ).
    await post('children', [{ id: childId, name: 'Bé thử', grade: 2, created_at: ago(0), updated_at: ago(0), last_synced_at: ago(0, 5 * 60000) }]);
    await post('attempts', [
      ...attempts('logic.age', 'logic', 2, 4, ago(0, 60000)), // 6 lượt, 2 đúng -> yếu
      ...attempts('arith.quick', 'arith', 5, 0, ago(2)), // 5 lượt đúng hết
      ...attempts('geo.perim', 'geo', 2, 0, ago(20)), // chỉ trong 30 ngày
      ...attempts('comb.outfit', 'comb', 0, 3, ago(40)), // ngoài cả hai khoảng
    ]);
    const w = (currency: string, amount: number, reason: string) => ({ id: randomUUID(), child_id: childId, currency, amount, reason, created_at: ago(0) });
    await post('wallet_ledger', [w('xu', 10, 'answer'), w('xu', 5, 'stage'), w('xu', -3, 'shop'), w('gem', 2, 'daily')]);
    const sp = (scope: string, key: string, rung: number | null, mastered: boolean) => ({
      id: randomUUID(), child_id: childId, scope, key, rung, mastered, mastered_at: mastered ? ago(1) : null, created_at: ago(1), updated_at: ago(1),
    });
    await post('skill_progress', [
      sp('strand', 'logic', 3, false), sp('strand', 'arith', 2, false),
      sp('form', 'logic.age', null, false), sp('form', 'arith.quick', null, true), sp('form', 'geo.perim', null, true),
    ]);
    const today = vnDay(now);
    const ds = (daysAgo: number, completed: boolean) => ({
      id: randomUUID(), child_id: childId, date: addDays(today, -daysAgo), questions: [], stage_status: [], completed,
      completed_at: completed ? ago(daysAgo) : null, created_at: ago(daysAgo), updated_at: ago(daysAgo),
    });
    await post('daily_sets', [ds(0, true), ds(1, true), ds(2, false), ds(20, true)]);
    const rq = (form: string, deleted: boolean) => ({
      id: randomUUID(), child_id: childId, form_id: form, rung: 2, due_date: ago(-3), correct_streak: 1,
      deleted_at: deleted ? ago(0) : null, created_at: ago(5), updated_at: ago(0),
    });
    await post('review_queue', [rq('logic.age', false), rq('arith.word', false), rq('geo.perim', true)]);
  });

  it('chọn bé: có 1 bé với mốc đồng bộ', async () => {
    const kids = await listChildren(http);
    expect(kids).toHaveLength(1);
    expect(kids[0]).toMatchObject({ id: childId, name: 'Bé thử', grade: 2 });
    expect(kids[0].last_synced_at).toBeTruthy();
  });

  it('thống kê 7 ngày', async () => {
    const s = await loadStats(http, childId, 7);
    expect(s.summary.questions).toBe(11);
    expect(s.summary.correctFirstTry).toBe(7);
    expect(s.summary.durationMs).toBe(110_000);
    expect(s.summary.perStrand.find((x) => x.strand === 'logic')).toMatchObject({ questions: 6, correctFirstTry: 2 });
    expect(s.summary.perStrand.find((x) => x.strand === 'geo')?.questions).toBe(0);
    expect(s.summary.perDay).toHaveLength(7);
    expect(s.doneDays).toBe(2);
    expect(s.strandRung).toEqual({ logic: 3, arith: 2 });
    expect(s.balances).toEqual({ xu: 12, gem: 2 });
  });

  it('thống kê 30 ngày', async () => {
    const s = await loadStats(http, childId, 30);
    expect(s.summary.questions).toBe(13);
    expect(s.summary.correctFirstTry).toBe(9);
    expect(s.doneDays).toBe(3);
  });

  it('dạng bài: thành thạo, yếu, sổ ôn tập', async () => {
    const f = await loadForms(http, childId, 7);
    expect(f.mastered.map((m) => m.key).sort()).toEqual(['arith.quick', 'geo.perim']);
    expect(f.weak.map((w) => w.formId)).toEqual(['logic.age']);
    expect(f.weak[0]).toMatchObject({ attempts: 6, correctFirstTry: 2 });
    expect(f.review.map((r) => r.form_id).sort()).toEqual(['arith.word', 'logic.age']); // không có dòng đã xóa
    const f30 = await loadForms(http, childId, 30);
    expect(f30.weak.map((w) => w.formId)).toEqual(['logic.age']); // comb.outfit ngoài khoảng
  });

  it('thư: gửi, hiện "Chưa mở", xóa được khi chưa mở, không xóa được khi đã mở', async () => {
    const v = validateMessage({ body: 'Bố tự hào về con', giftXu: '20', giftGem: '1', giftItemId: '' });
    if (!v.ok) throw new Error('thư không hợp lệ');
    const sent = await sendMessage(http, childId, v.value);
    let list = await listMessages(http, childId);
    expect(list).toHaveLength(1);
    expect(list[0]).toMatchObject({ id: sent.id, body: 'Bố tự hào về con', gift_xu: 20, gift_gem: 1 });
    expect(messageStatus(list[0])).toBe('unopened');

    const second = await sendMessage(http, childId, { body: 'Thư thứ hai', gift_xu: 0, gift_gem: 0, gift_item_id: null });
    list = await listMessages(http, childId);
    expect(list.map((m) => m.id)).toEqual([second.id, sent.id]); // mới nhất trước
    expect(await deleteUnopenedMessage(http, second.id)).toBe(true);

    // Bé mở thư (app gọi claim_message) -> admin thấy "Đã nhận quà" và không xóa được.
    await http.api('rpc/claim_message', { method: 'POST', body: { p_message_id: sent.id }, retry: true });
    list = await listMessages(http, childId);
    expect(list).toHaveLength(1);
    expect(messageStatus(list[0])).toBe('claimed');
    expect(await deleteUnopenedMessage(http, sent.id)).toBe(false);
    expect(await listMessages(http, childId)).toHaveLength(1);
  });

  it('cài đặt: POST lần đầu, PATCH các lần sau, chỉ một dòng', async () => {
    const before = await loadSettings(http, childId);
    expect(before.lock).toEqual({});
    expect(before.rewards.easy).toBe(2); // mặc định khi chưa có dòng

    await saveSetting(http, childId, 'answer_type_lock', { logic: 'number', arith: null });
    await saveSetting(http, childId, 'answer_type_lock', { logic: 'choice', arith: null, geo: 'number' });
    const { data: rows } = await http.api<{ id: string }[]>(`settings?child_id=eq.${childId}&key=eq.answer_type_lock&select=id`);
    expect(rows).toHaveLength(1);
    const lockRow = await getSetting(http, childId, 'answer_type_lock');
    expect(lockRow?.value).toEqual({ logic: 'choice', arith: null, geo: 'number' });

    await saveSetting(http, childId, 'rewards', { ...before.rewards, easy: 4, hard: 9 });
    const after = await loadSettings(http, childId);
    expect(after.rewards).toMatchObject({ easy: 4, medium: 3, hard: 9, stage_complete: 5 });
    expect(after.lock.logic).toBe('choice');
  });

  it('JWT hết hạn: xóa JWT trong bộ nhớ thì tự lấy lại', async () => {
    (http as unknown as { jwt: string | null }).jwt = 'a.b.c';
    // JWT rác bị coi là hết hạn ngay (jwtFresh=false) nên được làm mới trước khi gọi.
    expect((await listChildren(http))).toHaveLength(1);
  });
});
