// Logic thuần (không gọi mạng): bucket ngày theo giờ Việt Nam, thống kê,
// dạng yếu, kiểm tra thư, định dạng thời gian.
import { STRANDS, strandOfForm, type Strand } from './labels';

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

export interface FormStat {
  formId: string;
  attempts: number;
  correctFirstTry: number;
  /** Tỉ lệ 0..1, null nếu chưa làm lượt nào. */
  accuracy: number | null;
  /** Đủ lượt và đúng ngay dưới ngưỡng (cùng tiêu chí với weakForms). */
  weak: boolean;
}

export interface StrandFormStats {
  strand: Strand;
  forms: FormStat[];
  attempted: number;
  total: number;
  attempts: number;
  accuracy: number | null;
}

/**
 * Thống kê từng dạng theo mảng. `allFormIds` là danh sách dạng của app: dạng
 * chưa làm lượt nào vẫn có mặt (attempts = 0). Trong mỗi mảng: dạng yếu trước,
 * rồi theo tỉ lệ đúng tăng dần (ít lượt hơn xếp trước khi bằng nhau để dạng
 * còn ít dữ liệu không lấn át), dạng chưa làm xuống cuối. Mã dạng lạ (không
 * thuộc mảng nào) bị bỏ qua.
 */
export function formStatsByStrand(attempts: AttemptLite[], allFormIds: readonly string[]): StrandFormStats[] {
  const m = new Map<string, { n: number; ok: number }>();
  for (const a of attempts) {
    const e = m.get(a.form_id) ?? { n: 0, ok: 0 };
    e.n++;
    if (a.correct_first_try) e.ok++;
    m.set(a.form_id, e);
  }
  const ids = new Set([...allFormIds, ...m.keys()]);
  const byStrand = new Map<Strand, FormStat[]>(STRANDS.map((s) => [s, []]));
  for (const formId of ids) {
    const s = strandOfForm(formId);
    if (!s) continue;
    const e = m.get(formId) ?? { n: 0, ok: 0 };
    const accuracy = e.n > 0 ? e.ok / e.n : null;
    byStrand.get(s)!.push({
      formId,
      attempts: e.n,
      correctFirstTry: e.ok,
      accuracy,
      weak: accuracy !== null && e.n >= WEAK_MIN_ATTEMPTS && accuracy < WEAK_MAX_ACCURACY,
    });
  }
  return STRANDS.map((strand) => {
    const forms = byStrand.get(strand)!.sort((a, b) => {
      if ((a.attempts === 0) !== (b.attempts === 0)) return a.attempts === 0 ? 1 : -1;
      if (a.weak !== b.weak) return a.weak ? -1 : 1;
      return (
        (a.accuracy ?? 0) - (b.accuracy ?? 0) ||
        a.attempts - b.attempts ||
        a.formId.localeCompare(b.formId)
      );
    });
    const attemptsSum = forms.reduce((x, f) => x + f.attempts, 0);
    const ok = forms.reduce((x, f) => x + f.correctFirstTry, 0);
    return {
      strand,
      forms,
      attempted: forms.filter((f) => f.attempts > 0).length,
      total: forms.length,
      attempts: attemptsSum,
      accuracy: attemptsSum > 0 ? ok / attemptsSum : null,
    };
  });
}

// ------------------------------------------------- nhân vật và pet

export type PetStage = 'egg' | 'newborn' | 'teen' | 'adult';
/** Khớp petTeenDays / petAdultDays trong app/lib/features/room/pet_growth.dart. */
export const PET_TEEN_DAYS = 3;
export const PET_ADULT_DAYS = 8;

/** Số ngày xong trọn đề ngày: đủ 5 chặng đều 'done'. */
export function countFullyDoneSets(rows: { stage_status: unknown }[]): number {
  return rows.filter((r) => {
    const st = parseJson(r.stage_status);
    return Array.isArray(st) && st.length === 5 && st.every((x) => x === 'done');
  }).length;
}

export function petStageForDays(doneDays: number): Exclude<PetStage, 'egg'> {
  if (doneDays >= PET_ADULT_DAYS) return 'adult';
  if (doneDays >= PET_TEEN_DAYS) return 'teen';
  return 'newborn';
}

/** Số ngày xong đề nữa để lên giai đoạn sau; null nếu đã trưởng thành. */
export function petDaysToNextStage(doneDays: number): number | null {
  if (doneDays >= PET_ADULT_DAYS) return null;
  if (doneDays >= PET_TEEN_DAYS) return PET_ADULT_DAYS - doneDays;
  return PET_TEEN_DAYS - doneDays;
}

/** Giá trị settings.value có thể là chuỗi JSON (app lưu chuỗi) hoặc đã là JSON. */
export function parseJson(v: unknown): unknown {
  if (typeof v !== 'string') return v;
  try {
    return JSON.parse(v);
  } catch {
    return v;
  }
}

/** 'true' (chuỗi) hoặc true (boolean) -> true. */
export function parseFlag(v: unknown): boolean {
  const p = parseJson(v);
  return p === true || p === 'true';
}

export interface CharacterSettings {
  character_profile?: unknown;
  kid_head_accessory?: unknown;
  kid_glasses?: unknown;
  kid_white_shoes?: unknown;
  kid_backpack?: unknown;
  selected_egg?: unknown;
  egg_hatched?: unknown;
}

export interface CharacterView {
  name: string;
  gender: 'girl' | 'boy';
  /** Mã bộ đồ 1-3 (app: null/mã lạ -> bộ 1). */
  outfitNumber: 1 | 2 | 3;
  head: 'hat' | 'bow' | null;
  glasses: boolean;
  whiteShoes: boolean;
  backpack: boolean;
  /** Loài đã chọn ('dog' | 'cat' | 'rabbit'), null nếu chưa chọn hoặc mã lạ. */
  species: 'dog' | 'cat' | 'rabbit' | null;
  hatched: boolean;
  /** 'egg' nếu chưa nở, ngược lại theo số ngày xong đề. */
  stage: PetStage | null;
  doneDays: number;
  daysToNext: number | null;
}

/**
 * Gom các dòng settings của bé + số ngày xong đề thành dữ liệu hiển thị.
 * Trả null nếu chưa có dòng nào liên quan (app chưa đồng bộ).
 */
export function buildCharacterView(settings: CharacterSettings, doneDays: number): CharacterView | null {
  const has = Object.values(settings).some((v) => v !== undefined && v !== null);
  if (!has) return null;
  const rawProfile = parseJson(settings.character_profile);
  const profile = typeof rawProfile === 'object' && rawProfile !== null && !Array.isArray(rawProfile)
    ? (rawProfile as Record<string, unknown>)
    : {};
  const gender = profile.gender === 'boy' ? 'boy' : 'girl';
  const n = Number(/(\d+)$/.exec(typeof profile.dress === 'string' ? profile.dress : '')?.[1] ?? 1);
  const head = parseJson(settings.kid_head_accessory);
  const sp = parseJson(settings.selected_egg);
  const species = sp === 'dog' || sp === 'cat' || sp === 'rabbit' ? sp : null;
  const hatched = parseFlag(settings.egg_hatched);
  return {
    name: typeof profile.name === 'string' ? profile.name.trim() : '',
    gender,
    outfitNumber: n >= 1 && n <= 3 ? (n as 1 | 2 | 3) : 1,
    head: head === 'hat' || head === 'bow' ? head : null,
    glasses: parseFlag(settings.kid_glasses),
    whiteShoes: parseFlag(settings.kid_white_shoes),
    backpack: parseFlag(settings.kid_backpack),
    species,
    hatched,
    stage: species === null ? null : hatched ? petStageForDays(doneDays) : 'egg',
    doneDays,
    daysToNext: hatched ? petDaysToNextStage(doneDays) : null,
  };
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

/** "Chưa mở" / "Bé đã mở lúc 14:05 21/11/2026" / "Đã nhận quà lúc …" (giờ Việt Nam). */
export function messageStatusText(m: { opened_at: string | null; claimed_at: string | null }): string {
  const st = messageStatus(m);
  if (st === 'claimed') return `Đã nhận quà lúc ${formatVnDateTime(m.claimed_at as string)}`;
  if (st === 'opened') return `Bé đã mở lúc ${formatVnDateTime(m.opened_at as string)}`;
  return MESSAGE_STATUS_VI.unopened;
}

export const MESSAGE_STATUS_VI: Record<MessageStatus, string> = {
  unopened: 'Chưa mở',
  opened: 'Bé đã mở',
  claimed: 'Đã nhận quà',
};

// ------------------------------------------------ ví, đấu trường, đề tự soạn

/** Lý do dòng ví do bản thử của app tạo ra (app/lib/core/test_build.dart `testWalletReasons`). */
export const TEST_WALLET_REASONS = ['test_grant', 'test_topup', 'test_cleanup'] as const;

export interface LedgerRow {
  currency: string;
  amount: number | string;
  reason?: string;
}

/**
 * Số dư xu/kim cương từ sổ ví, BỎ các dòng của bản thử (kể cả khi server còn giữ dòng cũ
 * do bản thử đã gửi lên). Dòng chi tiêu bằng xu thử có thể làm tổng âm: hiện 0.
 */
export function sumBalances(rows: LedgerRow[]): { xu: number; gem: number } {
  const test = new Set<string>(TEST_WALLET_REASONS);
  let xu = 0;
  let gem = 0;
  for (const r of rows) {
    if (r.reason && test.has(r.reason)) continue;
    const n = Number(r.amount);
    if (r.currency === 'xu') xu += n;
    else if (r.currency === 'gem') gem += n;
  }
  return { xu: Math.max(0, xu), gem: Math.max(0, gem) };
}

export interface ArenaRow {
  mode: string;
  medal: string;
  score: number | string;
  correct_count?: number | string;
  gems_awarded?: number | string;
}

export interface ArenaSummary {
  heats: number;
  finals: number;
  /** Số huy chương theo loại, tách vòng loại (heat) và chung kết (final). */
  medals: Record<'heat' | 'final', Record<'gold' | 'silver' | 'bronze' | 'participant', number>>;
  bestScore: number | null;
  gems: number;
}

export function summarizeArena(rows: ArenaRow[]): ArenaSummary {
  const out: ArenaSummary = {
    heats: 0,
    finals: 0,
    medals: {
      heat: { gold: 0, silver: 0, bronze: 0, participant: 0 },
      final: { gold: 0, silver: 0, bronze: 0, participant: 0 },
    },
    bestScore: null,
    gems: 0,
  };
  for (const r of rows) {
    const mode = r.mode === 'final' ? 'final' : 'heat';
    if (mode === 'final') out.finals++;
    else out.heats++;
    const medal = r.medal as keyof ArenaSummary['medals']['heat'];
    if (medal in out.medals[mode]) out.medals[mode][medal]++;
    const score = Number(r.score);
    if (Number.isFinite(score) && (out.bestScore === null || score > out.bestScore)) out.bestScore = score;
    out.gems += Number(r.gems_awarded ?? 0) || 0;
  }
  return out;
}

export interface CustomUsage {
  /** Số lượt trả lời câu tự soạn. */
  attempts: number;
  correctFirstTry: number;
  /** Số câu tự soạn khác nhau bé đã gặp. */
  distinctQuestions: number;
}

/** Lượt làm câu tự soạn: `attempts.form_id = 'custom:<id>'`. */
export function summarizeCustomUsage(rows: { form_id: string; correct_first_try: boolean }[]): CustomUsage {
  const ids = new Set<string>();
  let attempts = 0;
  let correct = 0;
  for (const r of rows) {
    if (!r.form_id.startsWith('custom:')) continue;
    attempts++;
    if (r.correct_first_try) correct++;
    ids.add(r.form_id);
  }
  return { attempts, correctFirstTry: correct, distinctQuestions: ids.size };
}

export const CHILD_NAME_MAX = 40;
export const GRADE_MIN = 1;
export const GRADE_MAX = 5;

/** Kiểm tra sửa hồ sơ bé: tên 1-40 ký tự, lớp 1-5 (ràng buộc của bảng `children`). */
export function validateChildEdit(name: string, grade: number | string):
  | { ok: true; value: { name: string; grade: number } }
  | { ok: false; error: string } {
  const n = name.trim();
  if (n.length === 0) return { ok: false, error: 'Hãy nhập tên bé.' };
  if ([...n].length > CHILD_NAME_MAX) return { ok: false, error: `Tên bé tối đa ${CHILD_NAME_MAX} ký tự.` };
  const g = typeof grade === 'number' ? grade : Number(grade);
  if (!Number.isInteger(g) || g < GRADE_MIN || g > GRADE_MAX) {
    return { ok: false, error: `Lớp phải là số từ ${GRADE_MIN} đến ${GRADE_MAX}.` };
  }
  return { ok: true, value: { name: n, grade: g } };
}

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
