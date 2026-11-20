import { useState } from 'react';
import { http } from '../client';
import { Card, ErrorBox, RangePicker, Spinner, useLoad } from '../common';
import { loadStats } from '../lib/data';
import { STRANDS, STRAND_COLORS, STRAND_NAMES } from '../lib/labels';
import { formatDuration, formatPercent, shortDay } from '../lib/logic';

export function StatsScreen({ childId }: { childId: string }) {
  const [range, setRange] = useState(7);
  const q = useLoad(() => loadStats(http, childId, range), [childId, range]);
  const d = q.data;
  return (
    <>
      <div className="row" style={{ justifyContent: 'space-between', marginTop: 12 }}>
        <h2 style={{ margin: 0 }}>Thống kê</h2>
        <RangePicker value={range} onChange={setRange} />
      </div>
      {q.error != null && <ErrorBox error={q.error} onRetry={q.reload} />}
      {q.loading && !d && <Spinner />}
      {d && (
        <div style={{ opacity: q.loading ? 0.55 : 1 }}>
          <div className="grid g4" style={{ marginTop: 10 }}>
            <div className="stat"><b>{d.summary.questions}</b><span>Số câu đã làm</span></div>
            <div className="stat"><b>{formatPercent(d.summary.accuracy)}</b><span>Đúng ngay lần đầu</span></div>
            <div className="stat"><b>{formatDuration(d.summary.durationMs)}</b><span>Tổng thời gian học</span></div>
            <div className="stat"><b>{d.doneDays}/{range}</b><span>Ngày xong đề</span></div>
          </div>

          <Card title="Theo mảng">
            {d.summary.questions === 0 && <p className="muted">Chưa có câu nào trong {range} ngày qua.</p>}
            {STRANDS.map((s) => {
              const t = d.summary.perStrand.find((x) => x.strand === s)!;
              const acc = t.questions > 0 ? t.correctFirstTry / t.questions : null;
              const rung = d.strandRung[s];
              return (
                <div className="strand" key={s}>
                  <span className="name">{STRAND_NAMES[s]} {rung !== undefined && <span className="pill">Bậc {rung}</span>}</span>
                  <span className="nums">{t.questions} câu · {formatPercent(acc)} · {formatDuration(t.durationMs)}</span>
                  <div className="bar" role="img" aria-label={`${STRAND_NAMES[s]}: ${formatPercent(acc)} đúng ngay`}>
                    <i style={{ width: `${Math.round((acc ?? 0) * 100)}%`, background: STRAND_COLORS[s] }} />
                  </div>
                </div>
              );
            })}
          </Card>

          <Card title="Số phút học mỗi ngày">
            <DayChart perDay={d.summary.perDay} />
          </Card>

          <div className="grid">
            <div className="stat" style={{ background: '#fff6d8' }}><b>{d.balances.xu}</b><span>Xu hiện có</span></div>
            <div className="stat" style={{ background: '#e4f3ff' }}><b>{d.balances.gem}</b><span>Kim cương hiện có</span></div>
          </div>
        </div>
      )}
    </>
  );
}

function DayChart({ perDay }: { perDay: { day: string; minutes: number; questions: number }[] }) {
  const max = Math.max(1, ...perDay.map((p) => p.minutes));
  const step = perDay.length > 10 ? 5 : 1;
  return (
    <>
      <div className="chart" role="img" aria-label="Biểu đồ số phút học mỗi ngày">
        {perDay.map((p) => (
          <div className="col" key={p.day} title={`${shortDay(p.day)}: ${p.minutes} phút, ${p.questions} câu`}>
            <i className={p.minutes === 0 ? 'zero' : ''} style={{ height: `${Math.max(2, (p.minutes / max) * 100)}%` }} />
          </div>
        ))}
      </div>
      <div className="xlab">
        {perDay.map((p, i) => (
          <span key={p.day}>{i % step === 0 || i === perDay.length - 1 ? shortDay(p.day) : ''}</span>
        ))}
      </div>
      <p className="muted" style={{ marginBottom: 0 }}>Cao nhất: {max} phút/ngày.</p>
    </>
  );
}
