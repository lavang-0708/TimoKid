import { useState, type FormEvent } from 'react';
import { http } from '../client';
import { errorText } from '../common';
import { PASSWORD_MIN, validateNewPassword, type ResetParams } from '../lib/authForm';

/** Trang đặt mật khẩu mới: mở từ liên kết trong email (token nằm trong URL). */
export function ResetPasswordScreen({ params, onDone }: { params: NonNullable<ResetParams>; onDone: () => void }) {
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (params.kind !== 'token') return;
    const invalid = validateNewPassword(password, confirm);
    if (invalid) {
      setError(invalid);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await http.resetPassword(params.token, password);
      setDone(true);
    } catch (err) {
      const kind = (err as { kind?: string }).kind;
      setError(kind === 'auth' ? (err as Error).message : errorText(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth">
      <h1 className="brand" style={{ textAlign: 'center', fontSize: '2rem' }}>TimoKid</h1>
      <p className="muted" style={{ textAlign: 'center' }}>Đặt lại mật khẩu</p>
      <div className="card">
        {params.kind === 'error' ? (
          <>
            <div className="banner err">Liên kết đặt lại mật khẩu không đúng hoặc đã hết hạn. Hãy xin liên kết mới.</div>
            <button onClick={onDone}>Về trang đăng nhập</button>
          </>
        ) : done ? (
          <>
            <div className="banner ok" role="status">Đã đổi mật khẩu. Hãy đăng nhập bằng mật khẩu mới (cả trên app của bé).</div>
            <button onClick={onDone}>Đăng nhập</button>
          </>
        ) : (
          <form onSubmit={submit}>
            <h2 style={{ marginTop: 0 }}>Mật khẩu mới</h2>
            <label htmlFor="npw">Mật khẩu mới (ít nhất {PASSWORD_MIN} ký tự)</label>
            <input id="npw" type="password" autoComplete="new-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
            <label htmlFor="npw2">Nhập lại mật khẩu mới</label>
            <input id="npw2" type="password" autoComplete="new-password" required value={confirm} onChange={(e) => setConfirm(e.target.value)} />
            {error && <div className="banner err" role="alert">{error}</div>}
            <div className="row" style={{ marginTop: 14 }}>
              <button type="submit" disabled={busy}>{busy ? 'Đang lưu…' : 'Đặt mật khẩu'}</button>
              <button type="button" className="link" onClick={onDone}>Hủy</button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
