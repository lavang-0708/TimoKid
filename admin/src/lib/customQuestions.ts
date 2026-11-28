// Đề tự soạn (T5-03): kiểm tra từng câu, đọc và kiểm tra file CSV. Logic thuần,
// không gọi mạng (xem data.ts cho phần gọi Data API).
import { STRANDS, STRAND_NAMES, type Strand } from './labels';

export const TEXT_MAX = 600;
export const ANSWER_MAX = 100;
export const CHOICES_MIN = 2;
export const CHOICES_MAX = 6;
export const NUMBER_ANSWER_RE = /^[0-9]{1,6}$/;
/** Số câu tối đa một lần nhập CSV (chống nhầm file quá lớn). */
export const CSV_MAX_ROWS = 500;
/** Số câu gửi mỗi lô khi nhập. */
export const IMPORT_BATCH = 50;
export const DEFAULT_GRADE = 2;

/** Cột của file CSV, theo thứ tự khuyên dùng. Dòng đầu bắt buộc là tên cột. */
export const CSV_COLUMNS = [
  'strand',
  'rung',
  'grade',
  'text_vi',
  'text_en',
  'answer',
  'choices',
  'explanation_vi',
  'active',
] as const;
export type CsvColumn = (typeof CSV_COLUMNS)[number];
/** Cột bắt buộc phải có trong dòng đầu. */
export const CSV_REQUIRED: readonly CsvColumn[] = ['strand', 'rung', 'text_vi', 'answer'];

/** Mô tả từng cột, hiện trong màn nhập CSV. */
export const CSV_COLUMN_HELP: Record<CsvColumn, string> = {
  strand: 'Bắt buộc. Mảng: logic, arith, number, geo, comb (hoặc tên tiếng Việt: Tư duy lôgic, Số học, Lý thuyết số, Hình học, Tổ hợp).',
  rung: 'Bắt buộc. Bậc 1 đến 6. App chỉ dùng câu đúng bậc hiện tại của bé ở mảng đó.',
  grade: 'Lớp 1 đến 12, để phân loại. Bỏ trống thì là lớp 2.',
  text_vi: 'Bắt buộc. Đề bài tiếng Việt (tối đa 600 ký tự).',
  text_en: 'Tùy chọn. Đề bài tiếng Anh.',
  answer: 'Bắt buộc. Câu điền số: một số nguyên từ 0, tối đa 6 chữ số. Câu trắc nghiệm: đúng một lựa chọn trong cột choices.',
  choices: 'Tùy chọn. Câu trắc nghiệm: 2 đến 6 lựa chọn, ngăn cách bằng dấu |, ví dụ  Cam|Táo|Chuối. Để trống nếu là câu điền số.',
  explanation_vi: 'Tùy chọn. Lời giải thích hiện cho bé khi trả lời sai.',
  active: 'Tùy chọn. true hoặc false (có hoặc không). Bỏ trống thì là true.',
};

export const CSV_EXAMPLE =
  CSV_COLUMNS.join(',') +
  '\n' +
  [
    'arith,3,2,"Lan có 12 viên bi, cho bạn 5 viên. Lan còn mấy viên?","Lan has 12 marbles and gives away 5. How many are left?",7,,"12 - 5 = 7",true',
    'logic,2,2,"Con vật nào biết bay?",,Chim,"Cá|Chim|Mèo",Chim biết bay.,true',
  ].join('\n') +
  '\n';

/** Một câu đã kiểm tra, khớp cột của bảng `custom_questions`. */
export interface CustomQuestionInput {
  strand: Strand;
  rung: number;
  grade: number;
  text_vi: string;
  text_en: string | null;
  answer: string;
  choices: string[] | null;
  explanation_vi: string;
  active: boolean;
}

export type Validation<T> = { ok: true; value: T } | { ok: false; errors: string[] };

/** Dữ liệu thô (chuỗi) của một câu, từ form hoặc một dòng CSV. */
export interface RawQuestion {
  strand?: string;
  rung?: string;
  grade?: string;
  text_vi?: string;
  text_en?: string;
  answer?: string;
  choices?: string;
  explanation_vi?: string;
  active?: string;
}

const STRAND_ALIASES: Record<string, Strand> = Object.fromEntries([
  ...STRANDS.map((s) => [s, s]),
  ...STRANDS.map((s) => [STRAND_NAMES[s].toLowerCase(), s]),
]);

export function parseStrand(raw: string): Strand | null {
  return STRAND_ALIASES[raw.trim().toLowerCase()] ?? null;
}

function parseIntStrict(raw: string): number | null {
  const t = raw.trim();
  return /^[0-9]{1,3}$/.test(t) ? Number(t) : null;
}

export function parseBool(raw: string | undefined, def: boolean): boolean | null {
  const t = (raw ?? '').trim().toLowerCase();
  if (t === '') return def;
  if (['true', '1', 'có', 'co', 'yes', 'x'].includes(t)) return true;
  if (['false', '0', 'không', 'khong', 'no'].includes(t)) return false;
  return null;
}

/** Tách ô choices (ngăn cách bằng `|`) thành danh sách; rỗng thì trả null. */
export function splitChoices(raw: string | undefined): string[] | null {
  const t = (raw ?? '').trim();
  if (t === '') return null;
  return t.split('|').map((c) => c.trim());
}

/** Kiểm tra một câu. Lỗi viết bằng tiếng Việt, mỗi lỗi một câu. */
export function validateQuestion(raw: RawQuestion): Validation<CustomQuestionInput> {
  const errors: string[] = [];
  const strand = parseStrand(raw.strand ?? '');
  if (!strand) errors.push('Mảng không hợp lệ (dùng logic, arith, number, geo hoặc comb).');

  const rung = parseIntStrict(raw.rung ?? '');
  if (rung === null || rung < 1 || rung > 6) errors.push('Bậc phải là số từ 1 đến 6.');

  const gradeRaw = (raw.grade ?? '').trim();
  const grade = gradeRaw === '' ? DEFAULT_GRADE : parseIntStrict(gradeRaw);
  if (grade === null || grade < 1 || grade > 12) errors.push('Lớp phải là số từ 1 đến 12.');

  const textVi = (raw.text_vi ?? '').trim();
  if (textVi === '') errors.push('Thiếu đề bài tiếng Việt.');
  else if ([...textVi].length > TEXT_MAX) errors.push(`Đề bài tiếng Việt dài quá ${TEXT_MAX} ký tự.`);

  const textEn = (raw.text_en ?? '').trim();
  if ([...textEn].length > TEXT_MAX) errors.push(`Đề bài tiếng Anh dài quá ${TEXT_MAX} ký tự.`);

  const expl = (raw.explanation_vi ?? '').trim();
  if ([...expl].length > TEXT_MAX) errors.push(`Lời giải dài quá ${TEXT_MAX} ký tự.`);

  const answer = (raw.answer ?? '').trim();
  const choices = splitChoices(raw.choices);
  if (answer === '') {
    errors.push('Thiếu đáp án.');
  } else if (choices === null) {
    if (!NUMBER_ANSWER_RE.test(answer)) errors.push('Câu điền số: đáp án phải là số nguyên từ 0, tối đa 6 chữ số.');
  } else {
    if ([...answer].length > ANSWER_MAX) errors.push(`Đáp án dài quá ${ANSWER_MAX} ký tự.`);
  }
  if (choices !== null) {
    if (choices.some((c) => c === '')) errors.push('Có lựa chọn bị bỏ trống.');
    else if (choices.length < CHOICES_MIN || choices.length > CHOICES_MAX) {
      errors.push(`Câu trắc nghiệm cần ${CHOICES_MIN} đến ${CHOICES_MAX} lựa chọn.`);
    } else if (new Set(choices).size !== choices.length) {
      errors.push('Các lựa chọn bị trùng nhau.');
    } else if (answer !== '' && !choices.includes(answer)) {
      errors.push('Đáp án phải trùng đúng một lựa chọn.');
    }
    if (choices.some((c) => [...c].length > ANSWER_MAX)) errors.push(`Mỗi lựa chọn tối đa ${ANSWER_MAX} ký tự.`);
  }

  const active = parseBool(raw.active, true);
  if (active === null) errors.push('Cột active phải là true hoặc false.');

  if (errors.length > 0) return { ok: false, errors };
  return {
    ok: true,
    value: {
      strand: strand!,
      rung: rung!,
      grade: grade!,
      text_vi: textVi,
      text_en: textEn === '' ? null : textEn,
      answer,
      choices,
      explanation_vi: expl,
      active: active!,
    },
  };
}

// ------------------------------------------------------------------ CSV

function stripBom(t: string): string {
  return t.charCodeAt(0) === 0xfeff ? t.slice(1) : t;
}

/** Đọc CSV theo RFC 4180: ô trong ngoặc kép có thể chứa dấu phẩy, xuống dòng và "" (một dấu "). */
export function parseCsv(text: string, delimiter = ','): string[][] {
  const src = stripBom(text);
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;
  let touched = false;
  for (let i = 0; i < src.length; i++) {
    const ch = src[i];
    if (quoted) {
      if (ch === '"') {
        if (src[i + 1] === '"') {
          cell += '"';
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell += ch;
      }
      continue;
    }
    if (ch === '"' && cell === '') {
      quoted = true;
      touched = true;
    } else if (ch === delimiter) {
      row.push(cell);
      cell = '';
      touched = true;
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && src[i + 1] === '\n') i++;
      if (touched || cell !== '') {
        row.push(cell);
        rows.push(row);
      }
      row = [];
      cell = '';
      touched = false;
    } else {
      cell += ch;
      touched = true;
    }
  }
  if (touched || cell !== '') {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}

/** Excel ở máy dùng dấu phẩy thập phân hay xuất `;`: đoán dấu ngăn cách theo dòng đầu. */
export function detectDelimiter(text: string): string {
  const first = stripBom(text).split(/\r?\n/, 1)[0] ?? '';
  const commas = (first.match(/,/g) ?? []).length;
  const semis = (first.match(/;/g) ?? []).length;
  return semis > commas ? ';' : ',';
}

export interface CsvRowResult {
  /** Số dòng trong file (dòng đầu là 1). */
  line: number;
  raw: RawQuestion;
  result: Validation<CustomQuestionInput>;
}

export interface CsvParse {
  /** Lỗi cả file (thiếu cột, quá nhiều dòng, file rỗng...). Có lỗi thì không nhập được. */
  fileErrors: string[];
  rows: CsvRowResult[];
  /** Cột lạ bị bỏ qua. */
  ignoredColumns: string[];
}

export function parseQuestionsCsv(text: string): CsvParse {
  const table = parseCsv(text, detectDelimiter(text));
  const out: CsvParse = { fileErrors: [], rows: [], ignoredColumns: [] };
  if (table.length === 0) {
    out.fileErrors.push('File rỗng.');
    return out;
  }
  const header = table[0].map((h) => h.trim().toLowerCase());
  const known = new Set<string>(CSV_COLUMNS);
  out.ignoredColumns = header.filter((h) => h !== '' && !known.has(h));
  const missing = CSV_REQUIRED.filter((c) => !header.includes(c));
  if (missing.length > 0) {
    out.fileErrors.push(`Dòng đầu thiếu cột: ${missing.join(', ')}.`);
    return out;
  }
  const dup = header.filter((h, i) => h !== '' && header.indexOf(h) !== i);
  if (dup.length > 0) {
    out.fileErrors.push(`Cột bị lặp: ${[...new Set(dup)].join(', ')}.`);
    return out;
  }
  const body = table.slice(1);
  if (body.length === 0) {
    out.fileErrors.push('File chỉ có dòng tên cột, chưa có câu nào.');
    return out;
  }
  if (body.length > CSV_MAX_ROWS) {
    out.fileErrors.push(`File có ${body.length} dòng, tối đa ${CSV_MAX_ROWS} dòng mỗi lần nhập. Hãy tách file.`);
    return out;
  }
  body.forEach((cells, i) => {
    const raw: RawQuestion = {};
    header.forEach((h, j) => {
      if (known.has(h)) raw[h as CsvColumn] = cells[j] ?? '';
    });
    out.rows.push({ line: i + 2, raw, result: validateQuestion(raw) });
  });
  return out;
}

/** Chia mảng thành các lô tối đa `size` phần tử. */
export function chunk<T>(items: readonly T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

/** Các câu hợp lệ của một lần đọc CSV. */
export function validRows(p: CsvParse): CustomQuestionInput[] {
  return p.rows.flatMap((r) => (r.result.ok ? [r.result.value] : []));
}
