import { useState } from 'react';
import { http } from '../client';
import { Card, ErrorBox, RangePicker, Spinner, useLoad } from '../common';
import { loadCharacter, loadExtras, loadStats, type ExtrasData } from '../lib/data';
import {
  GENDER_NAMES,
  MEDAL_NAMES,
  petSpeciesName,
  HEAD_ACCESSORY_NAMES,
  OUTFIT_NAMES,
  PET_SPECIES_NAMES,
  PET_STAGE_NAMES,
  STRANDS,
  STRAND_COLORS,
  STRAND_NAMES,
} from '../lib/labels';
import { formatDuration, formatPercent, shortDay, type ArenaSummary, type CharacterView } from '../lib/logic';

export function StatsScreen({ childId }: { childId: string }) {
  const [range, setRange] = useState(14);
  const q = useLoad(() => loadStats(http, childId, range), [childId, range]);
  const d = q.data;
  return (
    <>
      <div className="row" style={{ justifyContent: 'space-between', marginTop: 12 }}>
        <h2 style={{ margin: 0 }}>Thống kê</h2>
        <RangePicker value={range} onChange={setRange} options={[7, 14, 30]} />
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

          <CharacterCard childId={childId} />
          <ExtrasCards childId={childId} />

          <div className="grid">
            <div className="stat" style={{ background: '#fff6d8' }}><b>{d.balances.xu}</b><span>Xu hiện có</span></div>
            <div className="stat" style={{ background: '#e4f3ff' }}><b>{d.balances.gem}</b><span>Kim cương hiện có</span></div>
          </div>
        </div>
      )}
    </>
  );
}

function ExtrasCards({ childId }: { childId: string }) {
  const q = useLoad(() => loadExtras(http, childId), [childId]);
  return (
    <>
      {q.error != null && <ErrorBox error={q.error} onRetry={q.reload} />}
      {q.loading && !q.data && <Spinner />}
      {q.data && <ExtrasBody d={q.data} />}
    </>
  );
}

const NO_DATA = 'Chưa có dữ liệu.';

function ArenaMedals({ a }: { a: ArenaSummary }) {
  const row = (label: string, n: number, m: ArenaSummary['medals']['heat']) => (
    <li>
      <span>{label} ({n} lượt)</span>
      <b>
        {(['gold', 'silver', 'bronze', 'participant'] as const).map((k) => `${MEDAL_NAMES[k]} ${m[k]}`).join(' · ')}
      </b>
    </li>
  );
  return (
    <ul className="list">
      {row('Vòng loại', a.heats, a.medals.heat)}
      {row('Chung kết', a.finals, a.medals.final)}
      <li><span>Điểm cao nhất</span><b>{a.bestScore ?? '—'}</b></li>
      <li><span>Kim cương nhận từ đấu trường</span><b>{a.gems}</b></li>
    </ul>
  );
}

export function ExtrasBody({ d }: { d: ExtrasData }) {
  const arenaCount = d.arena ? d.arena.heats + d.arena.finals : 0;
  return (
    <>
      <Card title="Pet của bé">
        {d.pets === null || d.pets.length === 0 ? (
          <p className="muted" style={{ margin: 0 }}>{NO_DATA}</p>
        ) : (
          <ul className="list">
            {d.pets.map((p) => (
              <li key={p.species}>
                <span>{petSpeciesName(p.species)}{p.active ? ' (đang nuôi)' : ''}</span>
                <b>{p.hatched ? PET_STAGE_NAMES[p.stage_seen] ?? p.stage_seen : 'Trứng (chưa nở)'} · {p.xp} xp</b>
              </li>
            ))}
          </ul>
        )}
      </Card>
      <Card title="Đấu trường">
        {d.arena === null || arenaCount === 0 ? (
          <p className="muted" style={{ margin: 0 }}>{NO_DATA}</p>
        ) : (
          <ArenaMedals a={d.arena} />
        )}
      </Card>
      <div className="grid">
        <div className="stat"><b>{d.stickers}</b><span>Sticker (dạng đã thành thạo)</span></div>
        <div className="stat">
          <b>{d.custom.attempts}</b>
          <span>
            Lượt làm đề tự soạn
            {d.custom.attempts > 0 && ` (${d.custom.distinctQuestions} câu, đúng ngay ${d.custom.correctFirstTry})`}
            {d.customActive !== null && ` · ${d.customActive} câu đang bật`}
          </span>
        </div>
      </div>
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

function CharacterCard({ childId }: { childId: string }) {
  const q = useLoad(() => loadCharacter(http, childId), [childId]);
  return (
    <Card title="Nhân vật và pet của bé" tone="mint">
      {q.error != null && <ErrorBox error={q.error} onRetry={q.reload} />}
      {q.loading && !q.data && <Spinner />}
      {!q.loading && q.error == null && q.data === null && (
        <p className="muted" style={{ margin: 0 }}>Chưa có dữ liệu — app chưa đồng bộ.</p>
      )}
      {q.data && <CharacterBody v={q.data} />}
    </Card>
  );
}

function CharacterBody({ v }: { v: CharacterView }) {
  const worn = [
    v.head ? HEAD_ACCESSORY_NAMES[v.gender][v.head] : null,
    v.glasses ? 'Kính tròn' : null,
    v.whiteShoes ? 'Giày trắng' : null,
    v.backpack ? 'Balo' : null,
  ].filter((x): x is string => x !== null);
  let pet = 'Chưa chọn trứng';
  if (v.species) {
    const sp = PET_SPECIES_NAMES[v.species];
    pet = v.stage === 'egg' ? `Trứng ${sp} (chưa nở)` : `${sp}, ${PET_STAGE_NAMES[v.stage ?? 'newborn']}`;
  }
  return (
    <ul className="list">
      <li><span>Tên</span><b>{v.name || 'Chưa đặt tên'}</b></li>
      <li><span>Dáng</span><b>{GENDER_NAMES[v.gender]}</b></li>
      <li><span>Bộ đồ</span><b>{OUTFIT_NAMES[v.gender][v.outfitNumber - 1]}</b></li>
      <li><span>Phụ kiện đang đeo</span><b>{worn.length > 0 ? worn.join(', ') : 'Không có'}</b></li>
      <li><span>Pet</span><b>{pet}</b></li>
      {v.hatched && v.species && (
        <li>
          <span>Lớn lên</span>
          <b>
            {v.daysToNext === null
              ? `Đã trưởng thành (${v.doneDays} ngày xong đề)`
              : `Còn ${v.daysToNext} ngày xong đề nữa để lên giai đoạn sau (đã ${v.doneDays})`}
          </b>
        </li>
      )}
    </ul>
  );
}
