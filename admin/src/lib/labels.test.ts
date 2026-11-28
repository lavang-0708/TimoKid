import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { FORM_LABELS, STRANDS, formLabel, strandOfForm } from './labels';

// Nguồn thật của các dạng bài nằm trong app Flutter. Test này đọc thẳng mã Dart
// để bảng nhãn tiếng Việt của web admin không bị lệch khi app thêm/bớt dạng.
const QUESTIONS_DIR = fileURLToPath(new URL('../../../app/lib/features/questions/', import.meta.url));
const GEN_DIR = `${QUESTIONS_DIR}generators/`;

const ID = String.raw`'((?:logic|arith|number|geo|comb)\.[a-z0-9_]+)'`;
const PATTERNS = [
  new RegExp(String.raw`formId\s*=>\s*${ID}`, 'g'),
  new RegExp(String.raw`Timo[234]Generator\(\s*${ID}`, 'g'),
];

function extractFormIds(): string[] {
  const ids = new Set<string>();
  for (const f of readdirSync(GEN_DIR).filter((n) => n.endsWith('.dart'))) {
    const src = readFileSync(GEN_DIR + f, 'utf8');
    for (const re of PATTERNS) for (const m of src.matchAll(re)) ids.add(m[1]);
  }
  return [...ids].sort();
}

/** Số dạng mỗi mảng do registry khai báo (generatorCountByTopic). */
function declaredCounts(): Record<string, number> {
  const src = readFileSync(`${QUESTIONS_DIR}question_registry.dart`, 'utf8');
  const block = /generatorCountByTopic\s*=\s*\{([^}]*)\}/.exec(src)?.[1] ?? '';
  return Object.fromEntries([...block.matchAll(/'(\w+)'\s*:\s*(\d+)/g)].map((m) => [m[1], Number(m[2])]));
}

describe('nhãn dạng bài khớp mã nguồn app', () => {
  const ids = extractFormIds();

  it('trích được đủ số dạng theo từng mảng của registry', () => {
    const counts = declaredCounts();
    expect(Object.keys(counts).sort()).toEqual([...STRANDS].sort());
    const actual: Record<string, number> = {};
    for (const id of ids) actual[id.split('.')[0]] = (actual[id.split('.')[0]] ?? 0) + 1;
    expect(actual).toEqual(counts);
  });

  it('mọi dạng trong app đều có nhãn tiếng Việt', () => {
    const missing = ids.filter((id) => !FORM_LABELS[id] || FORM_LABELS[id].trim() === '');
    expect(missing).toEqual([]);
  });

  it('mọi khóa trong bảng nhãn đều là dạng có thật', () => {
    const real = new Set(ids);
    expect(Object.keys(FORM_LABELS).filter((k) => !real.has(k))).toEqual([]);
  });

  it('mỗi khóa thuộc một mảng đã biết và formLabel trả về nhãn', () => {
    for (const id of ids) {
      expect(strandOfForm(id)).not.toBeNull();
      expect(formLabel(id)).toBe(FORM_LABELS[id]);
    }
  });
});
