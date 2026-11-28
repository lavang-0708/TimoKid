import { describe, expect, it } from 'vitest';
import {
  CSV_COLUMNS,
  CSV_EXAMPLE,
  CSV_MAX_ROWS,
  chunk,
  detectDelimiter,
  parseCsv,
  parseQuestionsCsv,
  splitChoices,
  validRows,
  validateQuestion,
} from './customQuestions';

const ok = { strand: 'arith', rung: '3', text_vi: 'Lan có 12 viên bi, cho 5. Còn mấy?', answer: '7' };

describe('validateQuestion', () => {
  it('câu điền số hợp lệ, có giá trị mặc định', () => {
    const v = validateQuestion(ok);
    expect(v.ok).toBe(true);
    if (v.ok) {
      expect(v.value).toEqual({
        strand: 'arith',
        rung: 3,
        grade: 2,
        text_vi: 'Lan có 12 viên bi, cho 5. Còn mấy?',
        text_en: null,
        answer: '7',
        choices: null,
        explanation_vi: '',
        active: true,
      });
    }
  });

  it('nhận tên mảng tiếng Việt, không phân biệt hoa thường', () => {
    const v = validateQuestion({ ...ok, strand: 'Lý thuyết số' });
    expect(v.ok && v.value.strand).toBe('number');
    const w = validateQuestion({ ...ok, strand: ' GEO ' });
    expect(w.ok && w.value.strand).toBe('geo');
  });

  it('mảng sai, bậc ngoài 1-6, lớp ngoài 1-12', () => {
    for (const rung of ['0', '7', 'a', '2.5', '-1', '']) {
      const v = validateQuestion({ ...ok, rung });
      expect(v.ok, `bậc ${rung}`).toBe(false);
    }
    expect(validateQuestion({ ...ok, strand: 'toan' }).ok).toBe(false);
    expect(validateQuestion({ ...ok, grade: '13' }).ok).toBe(false);
    expect(validateQuestion({ ...ok, grade: '0' }).ok).toBe(false);
    expect(validateQuestion({ ...ok, grade: '12' }).ok).toBe(true);
  });

  it('điền số: đáp án phải là số nguyên không âm tối đa 6 chữ số', () => {
    for (const answer of ['', '-3', '2.5', 'abc', '1234567', '1 2']) {
      expect(validateQuestion({ ...ok, answer }).ok, `đáp án "${answer}"`).toBe(false);
    }
    for (const answer of ['0', '999999', '007']) {
      expect(validateQuestion({ ...ok, answer }).ok, `đáp án "${answer}"`).toBe(true);
    }
  });

  it('trắc nghiệm: đáp án phải trùng đúng một lựa chọn', () => {
    const base = { ...ok, answer: 'Chim', choices: 'Cá|Chim|Mèo' };
    const v = validateQuestion(base);
    expect(v.ok && v.value.choices).toEqual(['Cá', 'Chim', 'Mèo']);
    const bad = validateQuestion({ ...base, answer: 'Gà' });
    expect(bad.ok).toBe(false);
    if (!bad.ok) expect(bad.errors.join(' ')).toContain('trùng');
    // Đáp án chữ cũng được khi có choices (không cần là số).
    expect(validateQuestion({ ...base, answer: 'Mèo' }).ok).toBe(true);
  });

  it('trắc nghiệm: 2-6 lựa chọn, không trùng, không rỗng', () => {
    expect(validateQuestion({ ...ok, answer: 'A', choices: 'A' }).ok).toBe(false);
    expect(validateQuestion({ ...ok, answer: 'A', choices: 'A|B|C|D|E|F|G' }).ok).toBe(false);
    expect(validateQuestion({ ...ok, answer: 'A', choices: 'A|B|C|D|E|F' }).ok).toBe(true);
    expect(validateQuestion({ ...ok, answer: 'A', choices: 'A|A' }).ok).toBe(false);
    expect(validateQuestion({ ...ok, answer: 'A', choices: 'A||B' }).ok).toBe(false);
  });

  it('trắc nghiệm đáp án số vẫn là chuỗi, không cần đúng 6 chữ số', () => {
    const v = validateQuestion({ ...ok, answer: '12345678', choices: '12345678|2' });
    expect(v.ok).toBe(true);
  });

  it('thiếu đề, đề quá dài, active sai', () => {
    expect(validateQuestion({ ...ok, text_vi: '  ' }).ok).toBe(false);
    expect(validateQuestion({ ...ok, text_vi: 'a'.repeat(601) }).ok).toBe(false);
    expect(validateQuestion({ ...ok, text_vi: 'a'.repeat(600) }).ok).toBe(true);
    expect(validateQuestion({ ...ok, active: 'maybe' }).ok).toBe(false);
    const off = validateQuestion({ ...ok, active: 'không' });
    expect(off.ok && off.value.active).toBe(false);
  });

  it('gom mọi lỗi một lúc', () => {
    const v = validateQuestion({});
    expect(v.ok).toBe(false);
    if (!v.ok) expect(v.errors.length).toBeGreaterThanOrEqual(4);
  });

  it('splitChoices', () => {
    expect(splitChoices('')).toBeNull();
    expect(splitChoices(undefined)).toBeNull();
    expect(splitChoices(' a | b ')).toEqual(['a', 'b']);
  });
});

describe('parseCsv', () => {
  it('ô trong ngoặc kép chứa dấu phẩy, "" và xuống dòng', () => {
    const t = parseCsv('a,"b,c","d ""e"""\n"x\ny",2,3\n');
    expect(t).toEqual([
      ['a', 'b,c', 'd "e"'],
      ['x\ny', '2', '3'],
    ]);
  });

  it('CRLF, dòng cuối không xuống dòng, bỏ BOM, bỏ dòng trống', () => {
    expect(parseCsv('﻿a,b\r\n1,2\r\n\r\n3,4')).toEqual([
      ['a', 'b'],
      ['1', '2'],
      ['3', '4'],
    ]);
  });

  it('ô rỗng ở cuối dòng vẫn tính', () => {
    expect(parseCsv('a,b,\n1,,\n')).toEqual([
      ['a', 'b', ''],
      ['1', '', ''],
    ]);
  });

  it('đoán dấu chấm phẩy', () => {
    expect(detectDelimiter('strand;rung;answer')).toBe(';');
    expect(detectDelimiter('strand,rung,answer')).toBe(',');
    const p = parseQuestionsCsv('strand;rung;text_vi;answer\narith;3;Hai cộng ba;5\n');
    expect(p.fileErrors).toEqual([]);
    expect(validRows(p)).toHaveLength(1);
  });
});

describe('parseQuestionsCsv', () => {
  it('file mẫu trong màn nhập đọc được hết', () => {
    const p = parseQuestionsCsv(CSV_EXAMPLE);
    expect(p.fileErrors).toEqual([]);
    expect(p.rows).toHaveLength(2);
    expect(p.rows.every((r) => r.result.ok)).toBe(true);
    const [a, b] = validRows(p);
    expect(a.choices).toBeNull();
    expect(a.text_en).toContain('marbles');
    expect(b.choices).toEqual(['Cá', 'Chim', 'Mèo']);
    expect(b.answer).toBe('Chim');
    expect(CSV_COLUMNS.every((c) => CSV_EXAMPLE.split('\n')[0].includes(c))).toBe(true);
  });

  it('thiếu cột bắt buộc thì cả file lỗi', () => {
    const p = parseQuestionsCsv('strand,rung,text_vi\narith,1,abc\n');
    expect(p.fileErrors[0]).toContain('answer');
    expect(p.rows).toHaveLength(0);
  });

  it('báo lỗi theo số dòng, vẫn đọc các dòng tốt', () => {
    const p = parseQuestionsCsv(
      ['strand,rung,text_vi,answer', 'arith,1,Hai cộng hai,4', 'arith,9,Sai bậc,4', 'geo,2,Có mấy cạnh?,abc'].join('\n'),
    );
    expect(p.rows.map((r) => [r.line, r.result.ok])).toEqual([
      [2, true],
      [3, false],
      [4, false],
    ]);
    expect(validRows(p)).toHaveLength(1);
  });

  it('cột lạ bị bỏ qua nhưng được báo; cột lặp thì lỗi', () => {
    const p = parseQuestionsCsv('strand,rung,text_vi,answer,ghi_chu\narith,1,Hai cộng hai,4,hay\n');
    expect(p.ignoredColumns).toEqual(['ghi_chu']);
    expect(validRows(p)).toHaveLength(1);
    expect(parseQuestionsCsv('strand,rung,text_vi,answer,rung\n').fileErrors[0]).toContain('lặp');
  });

  it('tên cột không phân biệt hoa thường và có khoảng trắng', () => {
    const p = parseQuestionsCsv(' Strand , RUNG ,Text_VI,Answer\narith,1,Hai cộng hai,4\n');
    expect(validRows(p)).toHaveLength(1);
  });

  it('file rỗng, chỉ có dòng đầu, quá nhiều dòng', () => {
    expect(parseQuestionsCsv('').fileErrors).toHaveLength(1);
    expect(parseQuestionsCsv('strand,rung,text_vi,answer\n').fileErrors).toHaveLength(1);
    const many = ['strand,rung,text_vi,answer', ...Array.from({ length: CSV_MAX_ROWS + 1 }, () => 'arith,1,x,1')].join('\n');
    expect(parseQuestionsCsv(many).fileErrors[0]).toContain('tối đa');
  });
});

describe('chunk', () => {
  it('chia lô', () => {
    expect(chunk([1, 2, 3, 4, 5], 2)).toEqual([[1, 2], [3, 4], [5]]);
    expect(chunk([], 3)).toEqual([]);
    expect(chunk(Array.from({ length: 120 }, (_, i) => i), 50).map((c) => c.length)).toEqual([50, 50, 20]);
  });
});
