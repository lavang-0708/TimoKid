import { useState } from 'react';
import { http } from '../client';
import { Card, ErrorBox, RangePicker, Spinner, useLoad } from '../common';
import { loadForms } from '../lib/data';
import { STRAND_COLORS, STRAND_NAMES, formLabel, strandOfForm } from '../lib/labels';
import { formatPercent, vnDay } from '../lib/logic';

function FormName({ id }: { id: string }) {
  const s = strandOfForm(id);
  const label = formLabel(id);
  return (
    <span>
      <b>{label}</b>
      {label !== id && <span className="muted"> ({id})</span>}
      {s && <span className="muted"> · {STRAND_NAMES[s]}</span>}
    </span>
  );
}

export function FormsScreen({ childId }: { childId: string }) {
  const [range, setRange] = useState(30);
  const q = useLoad(() => loadForms(http, childId, range), [childId, range]);
  const d = q.data;
  const today = vnDay(Date.now());
  return (
    <>
      <div className="row" style={{ justifyContent: 'space-between', marginTop: 12 }}>
        <h2 style={{ margin: 0 }}>Dạng bài</h2>
        <RangePicker value={range} onChange={setRange} options={[7, 30, 90]} />
      </div>
      {q.error != null && <ErrorBox error={q.error} onRetry={q.reload} />}
      {q.loading && !d && <Spinner />}
      {d && (
        <div style={{ opacity: q.loading ? 0.55 : 1 }}>
          <Card title={`Đã thành thạo (${d.mastered.length})`} tone="mint">
            {d.mastered.length === 0 ? (
              <p className="muted">Chưa có dạng nào được thành thạo.</p>
            ) : (
              <ul className="list">
                {d.mastered.map((m) => (
                  <li key={m.key}><FormName id={m.key} /></li>
                ))}
              </ul>
            )}
          </Card>
          <Card title="Thống kê từng dạng">
            <p className="muted" style={{ marginTop: 0 }}>
              Trong {range} ngày qua, theo từng mảng. Dạng yếu xếp trước, dạng chưa làm xếp cuối.
            </p>
            {d.byStrand.map((s) => (
              <details key={s.strand} className="strand-forms" open={s.forms.some((f) => f.weak)}>
                <summary>
                  <b style={{ color: STRAND_COLORS[s.strand] }}>{STRAND_NAMES[s.strand]}</b>
                  <span className="muted">
                    {' '}· đã làm {s.attempted}/{s.total} dạng · {s.attempts} lượt · {formatPercent(s.accuracy)}
                  </span>
                </summary>
                <ul className="list">
                  {s.forms.map((f) => (
                    <li key={f.formId}>
                      <FormName id={f.formId} />
                      {f.attempts === 0 ? (
                        <span className="pill">Chưa làm</span>
                      ) : (
                        <span className={`pill ${f.weak ? 'pink' : f.accuracy! >= 0.8 ? 'mint' : ''}`}>
                          {formatPercent(f.accuracy)} · {f.correctFirstTry}/{f.attempts}
                        </span>
                      )}
                    </li>
                  ))}
                </ul>
              </details>
            ))}
          </Card>
          <Card title={`Đang yếu (${d.weak.length})`}>
            <p className="muted" style={{ marginTop: 0 }}>
              Dạng có từ 5 lượt trở lên trong {range} ngày qua và đúng ngay lần đầu dưới 60%.
            </p>
            {d.weak.length === 0 ? (
              <p className="muted">Không có dạng nào yếu.</p>
            ) : (
              <ul className="list">
                {d.weak.map((w) => (
                  <li key={w.formId}>
                    <FormName id={w.formId} />
                    <span className="pill pink">{formatPercent(w.accuracy)} · {w.correctFirstTry}/{w.attempts}</span>
                  </li>
                ))}
              </ul>
            )}
          </Card>
          <Card title={`Sổ ôn tập (${d.review.length})`} tone="lav">
            {d.review.length === 0 ? (
              <p className="muted">Sổ ôn tập đang trống.</p>
            ) : (
              <ul className="list">
                {d.review.map((r) => {
                  const due = vnDay(r.due_date);
                  return (
                    <li key={r.id}>
                      <FormName id={r.form_id} />
                      <span className={`pill ${due <= today ? 'warn' : ''}`}>
                        {due <= today ? 'Đến hạn ' : 'Hạn '}
                        {due.slice(8, 10)}/{due.slice(5, 7)}
                      </span>
                    </li>
                  );
                })}
              </ul>
            )}
          </Card>
        </div>
      )}
    </>
  );
}
