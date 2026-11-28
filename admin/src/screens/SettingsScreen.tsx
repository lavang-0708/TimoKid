import { useEffect, useState } from 'react';
import { http } from '../client';
import { Card, ErrorBox, Spinner, errorText, useLoad } from '../common';
import { loadSettings, saveSetting, updateChild, type AnswerLock, type Child, type Rewards } from '../lib/data';
import { validateNewPassword, PASSWORD_MIN } from '../lib/authForm';
import { formatVnDateTime, validateChildEdit } from '../lib/logic';
import { ANSWER_TYPE_NAMES, REWARD_FIELDS, STRANDS, STRAND_NAMES } from '../lib/labels';

type LockChoice = '' | 'choice' | 'number';
const toChoice = (v: unknown): LockChoice => (v === 'choice' || v === 'number' ? v : '');

export function SettingsScreen({ child, kids, email, onChildrenChanged }: { child: Child; kids: Child[]; email: string; onChildrenChanged: () => void }) {
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
      <ChildrenCard kids={kids} currentId={child.id} onChanged={onChildrenChanged} />
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
      <AccountCard email={email} />
    </>
  );
}


function ChildRow({ kid, current, onChanged }: { kid: Child; current: boolean; onChanged: () => void }) {
  const [name, setName] = useState(kid.name);
  const [grade, setGrade] = useState(String(kid.grade));
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  useEffect(() => {
    setName(kid.name);
    setGrade(String(kid.grade));
  }, [kid.name, kid.grade]);
  const dirty = name.trim() !== kid.name || Number(grade) !== kid.grade;

  async function save() {
    const v = validateChildEdit(name, grade);
    if (!v.ok) {
      setNotice({ ok: false, text: v.error });
      return;
    }
    setBusy(true);
    setNotice(null);
    try {
      await updateChild(http, kid.id, v.value);
      setNotice({ ok: true, text: 'Đã lưu. App của bé cập nhật tên và lớp sau lần đồng bộ tiếp theo.' });
      onChanged();
    } catch (e) {
      setNotice({ ok: false, text: errorText(e) });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="kid-edit">
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <b>{kid.name}</b>
        {current && <span className="pill mint">Đang xem</span>}
      </div>
      <div className="muted">
        {kid.last_synced_at ? `Đồng bộ lần cuối: ${formatVnDateTime(kid.last_synced_at)}` : 'Đồng bộ lần cuối: chưa có'}
      </div>
      <div className="grid" style={{ marginTop: 6 }}>
        <div>
          <label htmlFor={`kn-${kid.id}`}>Tên</label>
          <input id={`kn-${kid.id}`} value={name} maxLength={40} onChange={(e) => setName(e.target.value)} />
        </div>
        <div>
          <label htmlFor={`kg-${kid.id}`}>Lớp</label>
          <select id={`kg-${kid.id}`} value={grade} onChange={(e) => setGrade(e.target.value)}>
            {[1, 2, 3, 4, 5].map((g) => (
              <option key={g} value={g}>Lớp {g}</option>
            ))}
          </select>
        </div>
      </div>
      {notice && <div className={`banner ${notice.ok ? 'ok' : 'err'}`}>{notice.text}</div>}
      <div style={{ marginTop: 8 }}>
        <button disabled={!dirty || busy} onClick={save}>{busy ? 'Đang lưu…' : 'Lưu hồ sơ'}</button>
      </div>
    </div>
  );
}

function ChildrenCard({ kids, currentId, onChanged }: { kids: Child[]; currentId: string; onChanged: () => void }) {
  return (
    <Card title="Hồ sơ các bé">
      {kids.length === 0 && <p className="muted">Chưa có bé nào.</p>}
      {kids.map((k) => (
        <ChildRow key={k.id} kid={k} current={k.id === currentId} onChanged={onChanged} />
      ))}
      <p className="muted" style={{ marginBottom: 0 }}>
        Hồ sơ bé mới được tạo trong app của bé. Tên và lớp sửa ở đây sẽ về app sau lần đồng bộ tiếp theo.
      </p>
    </Card>
  );
}

export function AccountCard({ email }: { email: string }) {
  const [open, setOpen] = useState(false);
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);

  async function submit() {
    if (!current) {
      setNotice({ ok: false, text: 'Hãy nhập mật khẩu hiện tại.' });
      return;
    }
    const invalid = validateNewPassword(next, confirm);
    if (invalid) {
      setNotice({ ok: false, text: invalid });
      return;
    }
    setBusy(true);
    setNotice(null);
    try {
      await http.changePassword(current, next);
      setNotice({ ok: true, text: 'Đã đổi mật khẩu. Lần đăng nhập sau trên app và web dùng mật khẩu mới.' });
      setCurrent('');
      setNext('');
      setConfirm('');
      setOpen(false);
    } catch (e) {
      const err = e as { kind?: string; message: string };
      setNotice({ ok: false, text: err.kind === 'auth' ? err.message : errorText(e) });
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card title="Tài khoản">
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <span className="muted">Email đăng nhập</span>
        <b style={{ wordBreak: 'break-all' }}>{email}</b>
      </div>
      {notice && <div className={`banner ${notice.ok ? 'ok' : 'err'}`}>{notice.text}</div>}
      {open ? (
        <>
          <label htmlFor="cp-cur">Mật khẩu hiện tại</label>
          <input id="cp-cur" type="password" autoComplete="current-password" value={current} onChange={(e) => setCurrent(e.target.value)} />
          <label htmlFor="cp-new">Mật khẩu mới (ít nhất {PASSWORD_MIN} ký tự)</label>
          <input id="cp-new" type="password" autoComplete="new-password" value={next} onChange={(e) => setNext(e.target.value)} />
          <label htmlFor="cp-new2">Nhập lại mật khẩu mới</label>
          <input id="cp-new2" type="password" autoComplete="new-password" value={confirm} onChange={(e) => setConfirm(e.target.value)} />
          <div className="row" style={{ marginTop: 10 }}>
            <button disabled={busy} onClick={submit}>{busy ? 'Đang đổi…' : 'Đổi mật khẩu'}</button>
            <button className="ghost" onClick={() => { setOpen(false); setNotice(null); }}>Hủy</button>
          </div>
        </>
      ) : (
        <div style={{ marginTop: 10 }}>
          <button className="ghost" onClick={() => { setOpen(true); setNotice(null); }}>Đổi mật khẩu</button>
        </div>
      )}
    </Card>
  );
}
