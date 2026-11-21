// Truy vấn Data API cho từng màn hình. Mọi hàm nhận `NeonHttp` để chạy được
// cả trong trình duyệt lẫn trong kiểm thử Node.
import type { NeonHttp } from './http';
import { ApiError } from './http';
import {
  buildCharacterView,
  countFullyDoneSets,
  dayRange,
  formStatsByStrand,
  summarizeStats,
  vnStartOfDay,
  weakForms,
  type AttemptLite,
  type CharacterView,
  type DailyStatRow,
  type StatsSummary,
  type StrandFormStats,
  type ValidMessage,
  type WeakForm,
} from './logic';
import { ALL_FORM_IDS, REWARD_FIELDS, STRANDS, type Strand } from './labels';

export interface Family {
  id: string;
  owner_user_id: string;
  display_name: string;
}

export interface Child {
  id: string;
  name: string;
  grade: number;
  last_synced_at: string | null;
}

export interface SkillRow {
  scope: 'strand' | 'form';
  key: string;
  rung: number | null;
  mastered: boolean;
  mastered_at: string | null;
}

export interface ReviewRow {
  id: string;
  form_id: string;
  rung: number;
  due_date: string;
  correct_streak: number;
}

export interface MessageRow {
  id: string;
  body: string;
  gift_xu: number;
  gift_gem: number;
  gift_item_id: string | null;
  opened_at: string | null;
  claimed_at: string | null;
  created_at: string;
}

export interface SettingRow {
  id: string;
  value: unknown;
}

const enc = encodeURIComponent;
const PAGE = 1000;

/** Đọc hết các trang (PostgREST giới hạn số dòng mỗi lần). */
async function getAll<T>(http: NeonHttp, path: string): Promise<T[]> {
  const out: T[] = [];
  for (let offset = 0; ; offset += PAGE) {
    const { data } = await http.api<T[]>(`${path}&limit=${PAGE}&offset=${offset}`);
    out.push(...data);
    if (data.length < PAGE) return out;
  }
}

export async function ensureFamily(http: NeonHttp): Promise<Family> {
  const { data } = await http.api<Family | Family[]>('rpc/ensure_family', {
    method: 'POST',
    body: { p_display_name: '' },
    retry: true,
  });
  return Array.isArray(data) ? data[0] : data;
}

export async function listChildren(http: NeonHttp): Promise<Child[]> {
  const { data } = await http.api<Child[]>(
    'children?select=id,name,grade,last_synced_at&deleted_at=is.null&order=created_at.asc',
  );
  return data;
}

// ---------------------------------------------------------- thống kê

export interface StatsData {
  days: string[];
  summary: StatsSummary;
  doneDays: number;
  strandRung: Partial<Record<Strand, number>>;
  balances: { xu: number; gem: number };
}

export async function loadStats(http: NeonHttp, childId: string, rangeDays: number, now: number = Date.now()): Promise<StatsData> {
  const days = dayRange(rangeDays, now);
  const from = days[0];
  const c = enc(childId);
  const [rows, sets, skills, bal] = await Promise.all([
    getAll<DailyStatRow>(http, `child_daily_stats?child_id=eq.${c}&day=gte.${from}&select=day,strand,questions,correct_first_try,duration_ms`),
    getAll<{ date: string }>(http, `daily_sets?child_id=eq.${c}&date=gte.${from}&completed=is.true&select=date`),
    getAll<SkillRow>(http, `skill_progress?child_id=eq.${c}&scope=eq.strand&select=scope,key,rung,mastered,mastered_at`),
    http.api<{ xu: number | string; gem: number | string }[]>(`child_balances?child_id=eq.${c}&select=xu,gem`),
  ]);
  const strandRung: Partial<Record<Strand, number>> = {};
  for (const s of skills) {
    if ((STRANDS as readonly string[]).includes(s.key) && s.rung !== null) strandRung[s.key as Strand] = s.rung;
  }
  const b = bal.data[0];
  return {
    days,
    summary: summarizeStats(rows, days),
    doneDays: new Set(sets.map((s) => s.date).filter((d) => d >= from && d <= days[days.length - 1])).size,
    strandRung,
    balances: { xu: Number(b?.xu ?? 0), gem: Number(b?.gem ?? 0) },
  };
}

// ---------------------------------------------------------- dạng bài

export interface FormsData {
  mastered: SkillRow[];
  weak: WeakForm[];
  /** Thống kê từng dạng theo mảng, gồm cả dạng chưa làm. */
  byStrand: StrandFormStats[];
  review: ReviewRow[];
}

export async function loadForms(http: NeonHttp, childId: string, rangeDays: number, now: number = Date.now()): Promise<FormsData> {
  const c = enc(childId);
  const from = enc(vnStartOfDay(dayRange(rangeDays, now)[0]));
  const [mastered, attempts, review] = await Promise.all([
    getAll<SkillRow>(http, `skill_progress?child_id=eq.${c}&scope=eq.form&mastered=is.true&select=scope,key,rung,mastered,mastered_at&order=mastered_at.desc.nullslast`),
    getAll<AttemptLite>(http, `attempts?child_id=eq.${c}&created_at=gte.${from}&select=form_id,correct_first_try`),
    getAll<ReviewRow>(http, `review_queue?child_id=eq.${c}&deleted_at=is.null&select=id,form_id,rung,due_date,correct_streak&order=due_date.asc`),
  ]);
  return { mastered, weak: weakForms(attempts), byStrand: formStatsByStrand(attempts, ALL_FORM_IDS), review };
}

// ---------------------------------------------------------- thư và quà

export async function listMessages(http: NeonHttp, childId: string): Promise<MessageRow[]> {
  const { data } = await http.api<MessageRow[]>(
    `messages?child_id=eq.${enc(childId)}&select=id,body,gift_xu,gift_gem,gift_item_id,opened_at,claimed_at,created_at&order=created_at.desc&limit=100`,
  );
  return data;
}

export async function sendMessage(http: NeonHttp, childId: string, m: ValidMessage): Promise<MessageRow> {
  const { data } = await http.api<MessageRow[]>('messages', {
    method: 'POST',
    headers: { Prefer: 'return=representation' },
    body: { child_id: childId, ...m },
  });
  return data[0];
}

/** Xóa thư chưa mở. Trả false nếu thư đã được bé mở (không xóa). */
export async function deleteUnopenedMessage(http: NeonHttp, id: string): Promise<boolean> {
  const { data } = await http.api<{ id: string }[]>(`messages?id=eq.${enc(id)}&opened_at=is.null&claimed_at=is.null`, {
    method: 'DELETE',
    headers: { Prefer: 'return=representation' },
  });
  return data.length > 0;
}

// ---------------------------------------------------------- cài đặt

export type AnswerLock = Partial<Record<Strand, 'choice' | 'number' | null>>;
export type Rewards = Record<string, number>;

export async function getSetting(http: NeonHttp, childId: string, key: string): Promise<SettingRow | null> {
  const { data } = await http.api<SettingRow[]>(`settings?child_id=eq.${enc(childId)}&key=eq.${enc(key)}&select=id,value`);
  return data[0] ?? null;
}

/**
 * Ghi một cài đặt của bé. Chỉ mục duy nhất của `settings` là chỉ mục biểu thức
 * nên không dùng on_conflict được: đọc theo child_id + key rồi PATCH theo id,
 * chưa có thì POST.
 */
export async function saveSetting(http: NeonHttp, childId: string, key: string, value: unknown): Promise<void> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const row = await getSetting(http, childId, key);
    const now = new Date().toISOString();
    try {
      if (row) {
        await http.api(`settings?id=eq.${enc(row.id)}`, { method: 'PATCH', body: { value, updated_at: now } });
      } else {
        await http.api('settings', { method: 'POST', body: { child_id: childId, key, value } });
      }
      return;
    } catch (e) {
      // Hai nơi cùng tạo một lúc: lần POST thua bị lỗi trùng (409), thử lại bằng PATCH.
      if (!(e instanceof ApiError && e.status === 409 && attempt === 0)) throw e;
    }
  }
}

export interface SettingsData {
  lock: AnswerLock;
  rewards: Rewards;
}

export function defaultRewards(): Rewards {
  return Object.fromEntries(REWARD_FIELDS.map((f) => [f.key, f.def]));
}

export async function loadSettings(http: NeonHttp, childId: string): Promise<SettingsData> {
  const [lock, rewards] = await Promise.all([
    getSetting(http, childId, 'answer_type_lock'),
    getSetting(http, childId, 'rewards'),
  ]);
  const lockObj = isObj(lock?.value) ? (lock!.value as AnswerLock) : {};
  const rw = defaultRewards();
  if (isObj(rewards?.value)) {
    for (const [k, v] of Object.entries(rewards!.value as Record<string, unknown>)) {
      if (typeof v === 'number') rw[k] = v;
    }
  }
  return { lock: lockObj, rewards: rw };
}

function isObj(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}


// ---------------------------------------------------- nhân vật và pet

const CHARACTER_KEYS = [
  'character_profile',
  'kid_head_accessory',
  'kid_glasses',
  'kid_white_shoes',
  'kid_backpack',
  'selected_egg',
  'egg_hatched',
];

/** Chỉ đọc. Trả null nếu app chưa đồng bộ dòng settings nào của nhân vật/pet. */
export async function loadCharacter(http: NeonHttp, childId: string): Promise<CharacterView | null> {
  const c = enc(childId);
  const [rows, sets] = await Promise.all([
    getAll<{ key: string; value: unknown }>(http, `settings?child_id=eq.${c}&key=in.(${CHARACTER_KEYS.join(',')})&select=key,value`),
    getAll<{ stage_status: unknown }>(http, `daily_sets?child_id=eq.${c}&select=stage_status`),
  ]);
  const settings: Record<string, unknown> = {};
  for (const r of rows) settings[r.key] = r.value;
  return buildCharacterView(settings, countFullyDoneSets(sets));
}
