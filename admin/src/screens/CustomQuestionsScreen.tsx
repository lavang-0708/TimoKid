import { useRef, useState, type ChangeEvent, type FormEvent } from 'react';
import { http } from '../client';
import { Card, ErrorBox, Spinner, errorText, useLoad } from '../common';
import {
  ImportError,
  importCustomQuestions,
  listCustomQuestions,
  saveCustomQuestion,
  setCustomQuestionActive,
  type Child,
  type CustomQuestionRow,
} from '../lib/data';
import {
  CSV_COLUMNS,
  CSV_COLUMN_HELP,
  CSV_EXAMPLE,
  CSV_MAX_ROWS,
  parseQuestionsCsv,
  validRows,
  validateQuestion,
  type CsvParse,
  type RawQuestion,
} from '../lib/customQuestions';
import { STRANDS, STRAND_NAMES } from '../lib/labels';

const EMPTY: Required<RawQuestion> = {
  strand: 'arith',
  rung: '1',
  grade: '2',
  text_vi: '',
  text_en: '',
  answer: '',
  choices: '',
  explanation_vi: '',
  active: 'true',
};

function toRaw(q: CustomQuestionRow): Required<RawQuestion> {
  return {
    strand: q.strand,
    rung: String(q.rung),
    grade: String(q.grade),
    text_vi: q.text_vi,
    text_en: q.text_en ?? '',
    answer: q.answer,
    choices: q.choices ? q.choices.join('|') : '',
    explanation_vi: q.explanation_vi,
    active: String(q.active),
  };
}

type Notice = { ok: boolean; text: string } | null;

function TargetSelect({ kids, value, onChange }: { kids: Child[]; value: string; onChange: (v: string) => void }) {
  return (
    <>
      <label htmlFor="cq-target">Áp dụng cho</label>
      <select id="cq-target" value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">Tất cả các bé</option>
        {kids.map((k) => (
          <option key={k.id} value={k.id}>Chỉ {k.name}</option>
        ))}
      </select>
    </>
  );
}

export function CustomQuestionsScreen({ kids }: { kids: Child[] }) {
  const q = useLoad(() => listCustomQuestions(http), []);
  const [mode, setMode] = useState<'list' | 'form' | 'csv'>('list');
  const [editing, setEditing] = useState<CustomQuestionRow | null>(null);
  const [notice, setNotice] = useState<Notice>(null);
  const [strandFilter, setStrandFilter] = useState('');
  const kidName = (id: string | null) => (id ? (kids.find((k) => k.id === id)?.name ?? 'Bé khác') : 'Tất cả các bé');

  async function toggle(row: CustomQuestionRow) {
    try {
      await setCustomQuestionActive(http, row.id, !row.active);
      setNotice({ ok: true, text: row.active ? 'Đã tắt câu này, app sẽ không đưa vào đề nữa.' : 'Đã bật lại câu này.' });
    } catch (err) {
      setNotice({ ok: false, text: errorText(err) });
    }
    q.reload();
  }

  if (mode === 'form') {
    return (
      <QuestionForm
        kids={kids}
        editing={editing}
        onDone={(text) => {
          setMode('list');
          setEditing(null);
          if (text) setNotice({ ok: true, text });
          q.reload();
        }}
        onCancel={() => {
          setMode('list');
          setEditing(null);
        }}
      />
    );
  }
  if (mode === 'csv') {
    return (
      <CsvImport
        kids={kids}
        onDone={(text) => {
          setMode('list');
          if (text) setNotice({ ok: true, text });
          q.reload();
        }}
        onCancel={() => setMode('list')}
      />
    );
  }

  const rows = (q.data ?? []).filter((r) => !strandFilter || r.strand === strandFilter);
  return (
    <>
      <h2>Đề tự soạn</h2>
      <p className="muted" style={{ marginTop: 0 }}>
        Câu bố/mẹ soạn sẽ được trộn vào đề ngày của bé: tối đa 1 câu mỗi chặng, đúng mảng và đúng bậc hiện tại của bé.
      </p>
      <div className="row">
        <button onClick={() => { setEditing(null); setMode('form'); }}>Thêm câu</button>
        <button className="ghost" onClick={() => setMode('csv')}>Nhập từ file CSV</button>
      </div>
      {notice && <div className={`banner ${notice.ok ? 'ok' : 'err'}`}>{notice.text}</div>}
      <Card title={`Danh sách (${q.data?.length ?? 0})`}>
        <div className="row" style={{ marginBottom: 8 }}>
          <button className={`chip ${strandFilter === '' ? 'on' : ''}`} onClick={() => setStrandFilter('')}>Tất cả</button>
          {STRANDS.map((s) => (
            <button key={s} className={`chip ${strandFilter === s ? 'on' : ''}`} onClick={() => setStrandFilter(s)}>
              {STRAND_NAMES[s]}
            </button>
          ))}
        </div>
        {q.error != null && <ErrorBox error={q.error} onRetry={q.reload} />}
        {q.loading && !q.data && <Spinner />}
        {q.data && rows.length === 0 && <p className="muted">Chưa có câu nào.</p>}
        {rows.map((r) => (
          <div className="msg" key={r.id} style={{ opacity: r.active ? 1 : 0.55 }}>
            <div className="row" style={{ justifyContent: 'space-between' }}>
              <span className="muted">
                {STRAND_NAMES[r.strand]} · bậc {r.rung} · lớp {r.grade} · {kidName(r.child_id)}
              </span>
              <span className={`pill ${r.active ? 'mint' : 'warn'}`}>{r.active ? 'Đang dùng' : 'Đã tắt'}</span>
            </div>
            <p>{r.text_vi}</p>
            <div className="muted">
              Đáp án: <b>{r.answer}</b>
              {r.choices && <> · Lựa chọn: {r.choices.join(' | ')}</>}
            </div>
            <div className="row" style={{ marginTop: 6 }}>
              <button className="chip" onClick={() => { setEditing(r); setMode('form'); }}>Sửa</button>
              <button className="chip" onClick={() => toggle(r)}>{r.active ? 'Tắt câu' : 'Bật lại'}</button>
            </div>
          </div>
        ))}
      </Card>
    </>
  );
}

function QuestionForm({
  kids,
  editing,
  onDone,
  onCancel,
}: {
  kids: Child[];
  editing: CustomQuestionRow | null;
  onDone: (notice: string) => void;
  onCancel: () => void;
}) {
  const [raw, setRaw] = useState<Required<RawQuestion>>(editing ? toRaw(editing) : EMPTY);
  const [target, setTarget] = useState(editing?.child_id ?? '');
  const [busy, setBusy] = useState(false);
  const [errors, setErrors] = useState<string[]>([]);
  const set = (k: keyof RawQuestion) => (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) =>
    setRaw((r) => ({ ...r, [k]: e.target.value }));

  async function submit(e: FormEvent) {
    e.preventDefault();
    const v = validateQuestion(raw);
    if (!v.ok) {
      setErrors(v.errors);
      return;
    }
    setBusy(true);
    setErrors([]);
    try {
      await saveCustomQuestion(http, { id: editing?.id, childId: target || null, input: v.value });
      onDone(editing ? 'Đã lưu câu hỏi.' : 'Đã thêm câu hỏi. Bé sẽ thấy sau lần đồng bộ tiếp theo.');
    } catch (err) {
      setErrors([errorText(err)]);
      setBusy(false);
    }
  }

  return (
    <>
      <h2>{editing ? 'Sửa câu hỏi' : 'Thêm câu hỏi'}</h2>
      <form className="card pink" onSubmit={submit}>
        <div className="grid">
          <div>
            <label htmlFor="cq-strand">Mảng</label>
            <select id="cq-strand" value={raw.strand} onChange={set('strand')}>
              {STRANDS.map((s) => (
                <option key={s} value={s}>{STRAND_NAMES[s]}</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="cq-rung">Bậc (1-6)</label>
            <select id="cq-rung" value={raw.rung} onChange={set('rung')}>
              {[1, 2, 3, 4, 5, 6].map((n) => (
                <option key={n} value={n}>{n}</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="cq-grade">Lớp</label>
            <input id="cq-grade" inputMode="numeric" value={raw.grade} onChange={set('grade')} />
          </div>
          <div>
            <TargetSelect kids={kids} value={target} onChange={setTarget} />
          </div>
        </div>
        <label htmlFor="cq-vi">Đề bài (tiếng Việt)</label>
        <textarea id="cq-vi" rows={3} value={raw.text_vi} onChange={set('text_vi')} />
        <label htmlFor="cq-en">Đề bài (tiếng Anh, không bắt buộc)</label>
        <textarea id="cq-en" rows={2} value={raw.text_en} onChange={set('text_en')} />
        <label htmlFor="cq-choices">Các lựa chọn, ngăn cách bằng | (bỏ trống nếu bé điền số)</label>
        <input id="cq-choices" value={raw.choices} onChange={set('choices')} placeholder="Cá|Chim|Mèo" />
        <label htmlFor="cq-answer">Đáp án {raw.choices.trim() ? '(chép đúng một lựa chọn)' : '(số nguyên từ 0, tối đa 6 chữ số)'}</label>
        <input id="cq-answer" value={raw.answer} onChange={set('answer')} />
        <label htmlFor="cq-expl">Lời giải thích (hiện khi bé trả lời sai)</label>
        <textarea id="cq-expl" rows={2} value={raw.explanation_vi} onChange={set('explanation_vi')} />
        {errors.length > 0 && <div className="banner err">{errors.join(' ')}</div>}
        <div className="row" style={{ marginTop: 12 }}>
          <button type="submit" disabled={busy}>{busy ? 'Đang lưu…' : 'Lưu'}</button>
          <button type="button" className="ghost" onClick={onCancel} disabled={busy}>Hủy</button>
        </div>
      </form>
    </>
  );
}

function CsvImport({ kids, onDone, onCancel }: { kids: Child[]; onDone: (notice: string) => void; onCancel: () => void }) {
  const [text, setText] = useState('');
  const [parsed, setParsed] = useState<CsvParse | null>(null);
  const [target, setTarget] = useState('');
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  function preview(src: string) {
    setText(src);
    setError(null);
    setParsed(src.trim() === '' ? null : parseQuestionsCsv(src));
  }

  async function onFile(e: ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (f) preview(await f.text());
  }

  const good = parsed ? validRows(parsed) : [];
  const bad = parsed ? parsed.rows.filter((r) => !r.result.ok) : [];
  const canImport = parsed !== null && parsed.fileErrors.length === 0 && good.length > 0 && !busy;

  async function run() {
    if (!canImport) return;
    setBusy(true);
    setError(null);
    try {
      const n = await importCustomQuestions(http, target || null, good, setProgress);
      onDone(`Đã nhập ${n} câu.${bad.length > 0 ? ` Bỏ qua ${bad.length} dòng lỗi.` : ''}`);
    } catch (err) {
      if (err instanceof ImportError) {
        setError(`${errorText(err.cause)} Đã nhập ${err.imported}/${good.length} câu; ${good.length - err.imported} câu cuối chưa nhập. Đừng nhập lại cả file kẻo bị trùng.`);
      } else {
        setError(errorText(err));
      }
      setBusy(false);
    }
  }

  function downloadTemplate() {
    const url = URL.createObjectURL(new Blob(['﻿' + CSV_EXAMPLE], { type: 'text/csv;charset=utf-8' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = 'de-tu-soan-mau.csv';
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <>
      <h2>Nhập đề từ file CSV</h2>
      <Card title="Các cột">
        <p className="muted" style={{ marginTop: 0 }}>
          Dòng đầu là tên cột. Tối đa {CSV_MAX_ROWS} câu mỗi lần. Ô có dấu phẩy hoặc xuống dòng thì đặt trong ngoặc kép.
        </p>
        <ul className="list">
          {CSV_COLUMNS.map((c) => (
            <li key={c}><b>{c}</b>: <span className="muted">{CSV_COLUMN_HELP[c]}</span></li>
          ))}
        </ul>
        <button className="chip" onClick={downloadTemplate}>Tải file mẫu</button>
      </Card>
      <section className="card pink">
        <TargetSelect kids={kids} value={target} onChange={setTarget} />
        <label htmlFor="cq-file">Chọn file CSV</label>
        <input id="cq-file" ref={fileRef} type="file" accept=".csv,text/csv" onChange={onFile} />
        <label htmlFor="cq-paste">Hoặc dán nội dung vào đây</label>
        <textarea id="cq-paste" rows={5} value={text} onChange={(e) => preview(e.target.value)} />
      </section>
      {parsed && (
        <Card title="Xem trước">
          {parsed.fileErrors.map((e) => (
            <div className="banner err" key={e}>{e}</div>
          ))}
          {parsed.ignoredColumns.length > 0 && (
            <div className="banner warn">Cột không dùng, bỏ qua: {parsed.ignoredColumns.join(', ')}.</div>
          )}
          {parsed.fileErrors.length === 0 && (
            <>
              <p>
                <b>{good.length}</b> câu hợp lệ{bad.length > 0 && <>, <b>{bad.length}</b> dòng lỗi (sẽ bị bỏ qua)</>}.
              </p>
              {bad.slice(0, 20).map((r) => (
                <div className="banner err" key={r.line}>
                  Dòng {r.line}: {r.result.ok ? '' : r.result.errors.join(' ')}
                </div>
              ))}
              {bad.length > 20 && <p className="muted">Và {bad.length - 20} dòng lỗi nữa.</p>}
              {parsed.rows.slice(0, 5).map((r) =>
                r.result.ok ? (
                  <div className="msg" key={r.line}>
                    <span className="muted">
                      Dòng {r.line} · {STRAND_NAMES[r.result.value.strand]} · bậc {r.result.value.rung} · đáp án {r.result.value.answer}
                    </span>
                    <p>{r.result.value.text_vi}</p>
                  </div>
                ) : null,
              )}
              {good.length > 5 && <p className="muted">Chỉ hiện 5 câu đầu.</p>}
            </>
          )}
        </Card>
      )}
      {error && <div className="banner err">{error}</div>}
      <div className="row">
        <button onClick={run} disabled={!canImport}>
          {busy ? `Đang nhập… ${progress ? `${progress.done}/${progress.total}` : ''}` : `Nhập ${good.length || ''} câu`}
        </button>
        <button className="ghost" onClick={onCancel} disabled={busy}>Quay lại</button>
      </div>
    </>
  );
}
