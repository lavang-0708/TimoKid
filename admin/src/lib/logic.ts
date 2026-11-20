// Logic thuần (không gọi mạng): bucket ngày theo giờ Việt Nam, thống kê,
// dạng yếu, kiểm tra thư, định dạng thời gian.
import { STRANDS, type Strand } from './labels';

const VN_OFFSET_MS = 7 * 3600 * 1000; // Asia/Ho_Chi_Minh = UTC+7, không có giờ mùa hè.

/** Ngày (yyyy-mm-dd) theo giờ Việt Nam của một thời điểm. */
export function vnDay(d: Date | number | string): string {
  const ms = typeof d === 'number' ? d : new Date(d).getTime();
  return new Date(ms + VN_OFFSET_MS).toISOString().slice(0, 10);
}

/** Cộng `n` ngày vào chuỗi yyyy-mm-dd. */
export function addDays(day: string, n: number): string {
  const [y, m, d] = day.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}

/** `days` ngày liên tiếp kết thúc ở hôm nay (giờ VN), cũ -> mới. */
export function dayRange(days: number, now: Date | number = Date.now()): string[] {
  const today = vnDay(now);
  return Array.from({ length: days }, (_, i) => addDays(today, i - (days - 1)));
}

/** Thời điểm 00:00 (giờ VN) của một ngày, dạng ISO có múi giờ. */
export function vnStartOfDay(day: string): string {
  return `${day}T00:00:00+07:00`;
}

export interface DailyStatRow {
  day: string;
  strand: string;
  questions: number;
  correct_first_try: number;
  duration_ms: number;
}

export interface StrandTotals {
  strand: Strand;
  questions: number;
  correctFirstTry: number;
  durationMs: number;
}

export interface StatsSummary {
  questions: number;
  correctFirstTry: number;
  /** Tỉ lệ 0..1, null nếu chưa có câu nào. */
  accuracy: number | null;
  durationMs: number;
  perStrand: StrandTotals[];
  /** Mỗi ngày trong khoảng: số phút học (làm tròn 1 chữ số). */
  perDay: { day: string; minutes: number; questions: number }[];
}

export function summarizeStats(rows: DailyStatRow[], days: string[]): StatsSummary {
  const inRange = new Set(days);
  const perStrand = new Map<Strand, StrandTotals>(
    STRANDS.map((s) => [s, { strand: s, questions: 0, correctFirstTry: 0, durationMs: 0 }]),
  );
  const perDay = new Map(days.map((d) => [d, { ms: 0, q: 0 }]));
  let questions = 0;
  let correct = 0;
  let duration = 0;
  for (const r of rows) {
    if (!inRange.has(r.day)) continue;
    // PostgREST trả bigint/numeric dạng số hoặc chuỗi.
    const q = Number(r.questions);
    const c = Number(r.correct_first_try);
    const ms = Number(r.duration_ms);
    questions += q;
    correct += c;
    duration += ms;
    const st = perStrand.get(r.strand as Strand);
    if (st) {
      st.questions += q;
      st.correctFirstTry += c;
      st.durationMs += ms;
    }
    const d = perDay.get(r.day);
    if (d) {
      d.ms += ms;
      d.q += q;
    }
  }
  return {
    questions,
    correctFirstTry: correct,
    accuracy: questions > 0 ? correct / questions : null,
    durationMs: duration,
    perStrand: [...perStrand.values()],
    perDay: days.map((day) => {
      const d = perDay.get(day)!;
      return { day, minutes: Math.round((d.ms / 60000) * 10) / 10, questions: d.q };
    }),
  };
}

export interface AttemptLite {
  form_id: string;
  correct_first_try: boolean;
}

export interface WeakForm {
  formId: string;
  attempts: number;
  correctFirstTry: number;
  accuracy: number;
}

export const WEAK_MIN_ATTEMPTS = 5;
export const WEAK_MAX_ACCURACY = 0.6;

/** Dạng có >= 5 lượt và tỉ lệ đúng ngay lần đầu < 60%; yếu nhất xếp trước. */
export function weakForms(attempts: AttemptLite[]): WeakForm[] {
  const m = new Map<string, { n: number; ok: number }>();
  for (const a of attempts) {
    const e = m.get(a.form_id) ?? { n: 0, ok: 0 };
    e.n++;
    if (a.correct_first_try) e.ok++;
    m.set(a.form_id, e);
  }
  const out: WeakForm[] = [];
  for (const [formId, e] of m) {
    const accuracy = e.ok / e.n;
    if (e.n >= WEAK_MIN_ATTEMPTS && accuracy < WEAK_MAX_ACCURACY) {
      out.push({ formId, attempts: e.n, correctFirstTry: e.ok, accuracy });
    }
  }
  return out.sort((a, b) => a.accuracy - b.accuracy || b.attempts - a.attempts || a.formId.localeCompare(b.formId));
}

// ------------------------------------------------------------------ thư

export const MESSAGE_MAX = 300;
export const GIFT_XU_MAX = 1000;
export const GIFT_GEM_MAX = 100;

export interface MessageDraft {
  body: string;
  giftXu: string | number;
  giftGem: string | number;
  giftItemId: string;
}

export interface ValidMessage {
  body: string;
  gift_xu: number;
  gift_gem: number;
  gift_item_id: string | null;
}

export function validateMessage(d: MessageDraft): { ok: true; value: ValidMessage } | { ok: false; errors: string[] } {
  const errors: string[] = [];
  const body = d.body.trim();
  if (body.length === 0) errors.push('Hãy viết lời nhắn cho bé.');
  if ([...body].length > MESSAGE_MAX) errors.push(`Lời nhắn tối đa ${MESSAGE_MAX} ký tự.`);
  const xu = parseCount(d.giftXu);
  const gem = parseCount(d.giftGem);
  if (xu === null || xu > GIFT_XU_MAX) errors.push(`Số xu phải là số nguyên từ 0 đến ${GIFT_XU_MAX}.`);
  if (gem === null || gem > GIFT_GEM_MAX) errors.push(`Số kim cương phải là số nguyên từ 0 đến ${GIFT_GEM_MAX}.`);
  if (d.giftItemId.trim().length > 60) errors.push('Mã món đồ tối đa 60 ký tự.');
  if (errors.length > 0) return { ok: false, errors };
  return {
    ok: true,
    value: {
      body,
      gift_xu: xu as number,
      gift_gem: gem as number,
      gift_item_id: d.giftItemId.trim() === '' ? null : d.giftItemId.trim(),
    },
  };
}

/** '' -> 0; số nguyên không âm -> số; còn lại -> null. */
function parseCount(v: string | number): number | null {
  if (typeof v === 'number') return Number.isInteger(v) && v >= 0 ? v : null;
  const s = v.trim();
  if (s === '') return 0;
  return /^\d+$/.test(s) ? Number(s) : null;
}

export type MessageStatus = 'unopened' | 'opened' | 'claimed';

export function messageStatus(m: { opened_at: string | null; claimed_at: string | null }): MessageStatus {
  if (m.claimed_at) return 'claimed';
  if (m.opened_at) return 'opened';
  return 'unopened';
}

export const MESSAGE_STATUS_VI: Record<MessageStatus, string> = {
  unopened: 'Chưa mở',
  opened: 'Bé đã mở',
  claimed: 'Đã nhận quà',
};

// ------------------------------------------------------------ định dạng

const pad = (n: number) => String(n).padStart(2, '0');

/** "14:05 21/11/2026" theo giờ Việt Nam. */
export function formatVnDateTime(iso: string | number | Date): string {
  const ms = new Date(iso).getTime() + VN_OFFSET_MS;
  const d = new Date(ms);
  return `${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())} ${pad(d.getUTCDate())}/${pad(d.getUTCMonth() + 1)}/${d.getUTCFullYear()}`;
}

/** "5 phút trước", "3 giờ trước", "2 ngày trước". */
export function relativeVi(iso: string | number | Date, now: number = Date.now()): string {
  const diff = now - new Date(iso).getTime();
  if (diff < 0 || diff < 60_000) return 'vừa xong';
  const min = Math.floor(diff / 60_000);
  if (min < 60) return `${min} phút trước`;
  const h = Math.floor(min / 60);
  if (h < 24) return `${h} giờ trước`;
  return `${Math.floor(h / 24)} ngày trước`;
}

/** "1 giờ 05 phút", "12 phút", "0 phút". */
export function formatDuration(ms: number): string {
  const totalMin = Math.round(ms / 60000);
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  return h > 0 ? `${h} giờ ${pad(m)} phút` : `${m} phút`;
}

export function formatPercent(v: number | null): string {
  return v === null ? '-' : `${Math.round(v * 100)}%`;
}

/** "21/11" từ yyyy-mm-dd. */
export function shortDay(day: string): string {
  return `${day.slice(8, 10)}/${day.slice(5, 7)}`;
}
