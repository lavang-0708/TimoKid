import { useEffect, useState } from 'react';
import { http } from '../client';
import { Card, ErrorBox, Spinner, errorText, useLoad } from '../common';
import { loadSettings, saveSetting, type AnswerLock, type Child, type Rewards } from '../lib/data';
import { ANSWER_TYPE_NAMES, REWARD_FIELDS, STRANDS, STRAND_NAMES } from '../lib/labels';

type LockChoice = '' | 'choice' | 'number';
const toChoice = (v: unknown): LockChoice => (v === 'choice' || v === 'number' ? v : '');

export function SettingsScreen({ child }: { child: Child }) {
  const q = useLoad(() => loadSettings(http, child.id), [child.id]);
  const [lock, setLock] = useState<Record<string, LockChoice>>({});
  const [rewards, setRewards] = useState<Record<string, string>>({});
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const d = q.data;

  useEffect(() => {
    if (!d) return;
    setLock(Object.fromEntries(STRANDS.map((s) => [s, toChoice(d.lock[s])])));
    setRewards(Object.fromEntries(REWARD_FIELDS.map((f) => [f.key, String(d.rewards[f.key] ?? f.def)])));
  }, [d]);

  if (q.error != null && !d) return <ErrorBox error={q.error} onRetry={q.reload} />;
  if (!d) return <Spinner />;

  const lockDirty = STRANDS.some((s) => (lock[s] ?? '') !== toChoice(d.lock[s]));
  const parsed = Object.fromEntries(REWARD_FIELDS.map((f) => [f.key, Number(rewards[f.key])]));
  const rewardsValid = REWARD_FIELDS.every((f) => Number.isInteger(parsed[f.key]) && parsed[f.key] >= 0 && parsed[f.key] <= 1000 && (rewards[f.key] ?? '').trim() !== '');
  const rewardsDirty = REWARD_FIELDS.some((f) => parsed[f.key] !== d.rewards[f.key]);

  async function saveLock() {
    setBusy(true);
    setNotice(null);
    try {
      const value: AnswerLock = Object.fromEntries(STRANDS.map((s) => [s, lock[s] === '' ? null : lock[s]]));
      await saveSetting(http, child.id, 'answer_type_lock', value);
      setNotice({ ok: true, text: 'Đã lưu khóa kiểu trả lời. App của bé áp dụng sau lần đồng bộ tiếp theo.' });
      q.reload();
    } catch (e) {
      setNotice({ ok: false, text: errorText(e) });
    } finally {
      setBusy(false);
    }
  }

  async function saveRewards() {
    setBusy(true);
    setNotice(null);
    try {
      const value: Rewards = { ...d!.rewards, ...parsed };
      await saveSetting(http, child.id, 'rewards', value);
      setNotice({ ok: true, text: 'Đã lưu mức thưởng. App của bé áp dụng sau lần đồng bộ tiếp theo.' });
      q.reload();
    } catch (e) {
      setNotice({ ok: false, text: errorText(e) });
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <h2>Cài đặt</h2>
      <Card title="Hồ sơ bé">
        <div className="row"><b>{child.name}</b><span className="pill">Lớp {child.grade}</span></div>
        <p className="muted" style={{ marginBottom: 0 }}>Tên và lớp do app của bé đồng bộ lên, chưa sửa được ở đây.</p>
      </Card>
      {notice && <div className={`banner ${notice.ok ? 'ok' : 'err'}`}>{notice.text}</div>}

      <Card title="Khóa kiểu trả lời theo mảng">
        <p className="muted" style={{ marginTop: 0 }}>"Theo bậc" nghĩa là app tự chọn kiểu trả lời theo bậc của bé.</p>
        {STRANDS.map((s) => (
          <div key={s}>
            <label htmlFor={`lock-${s}`}>{STRAND_NAMES[s]}</label>
            <select id={`lock-${s}`} value={lock[s] ?? ''} onChange={(e) => setLock({ ...lock, [s]: e.target.value as LockChoice })}>
              <option value="">Theo bậc</option>
              <option value="choice">{ANSWER_TYPE_NAMES.choice}</option>
              <option value="number">{ANSWER_TYPE_NAMES.number}</option>
            </select>
          </div>
        ))}
        <div style={{ marginTop: 12 }}>
          <button disabled={!lockDirty || busy} onClick={saveLock}>Lưu khóa kiểu trả lời</button>
        </div>
      </Card>

      <Card title="Mức thưởng">
        {REWARD_FIELDS.map((f) => (
          <div key={f.key}>
            <label htmlFor={`rw-${f.key}`}>{f.label} ({f.unit})</label>
            <input
              id={`rw-${f.key}`}
              inputMode="numeric"
              value={rewards[f.key] ?? ''}
              onChange={(e) => setRewards({ ...rewards, [f.key]: e.target.value })}
            />
          </div>
        ))}
        {!rewardsValid && <div className="banner err">Mỗi mức thưởng phải là số nguyên từ 0 đến 1000.</div>}
        <div style={{ marginTop: 12 }}>
          <button disabled={!rewardsDirty || !rewardsValid || busy} onClick={saveRewards}>Lưu mức thưởng</button>
        </div>
      </Card>
    </>
  );
}
