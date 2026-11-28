import { useState, type FormEvent } from 'react';
import { http } from '../client';
import { errorText } from '../common';
import { PASSWORD_MIN, resetRedirectUrl, validateAuth, type AuthMode } from '../lib/authForm';
import type { AuthUser } from '../lib/http';

const TITLES: Record<AuthMode, string> = { in: 'Đăng nhập', up: 'Đăng ký', forgot: 'Quên mật khẩu' };

export function AuthScreen({ onSignedIn }: { onSignedIn: (u: AuthUser) => void }) {
  const [mode, setMode] = useState<AuthMode>('in');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);

  function go(m: AuthMode) {
    setMode(m);
    setError(null);
    setSent(false);
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    const invalid = validateAuth({ mode, email, password, confirm });
    if (invalid) {
      setError(invalid);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const addr = email.trim();
      if (mode === 'forgot') {
        await http.requestPasswordReset(addr, resetRedirectUrl(window.location.origin, import.meta.env.BASE_URL));
        setSent(true);
      } else {
        const u = mode === 'in' ? await http.signIn(addr, password) : await http.signUp(addr, password, addr.split('@')[0] || 'Phụ huynh');
        onSignedIn(u);
      }
    } catch (err) {
      setError(errorMsg(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth">
      <h1 className="brand" style={{ textAlign: 'center', fontSize: '2rem' }}>TimoKid</h1>
      <p className="muted" style={{ textAlign: 'center' }}>Trang dành cho phụ huynh</p>
      <form className="card" onSubmit={submit} noValidate>
        <h2 style={{ marginTop: 0 }}>{TITLES[mode]}</h2>
        <label htmlFor="email">Email</label>
        <input id="email" type="email" autoComplete="email" inputMode="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        {mode === 'forgot' ? (
          <p className="muted">Nhập email đã đăng ký. TimoKid sẽ gửi thư kèm liên kết để đặt mật khẩu mới.</p>
        ) : (
          <>
            <label htmlFor="pw">Mật khẩu{mode === 'up' ? ` (ít nhất ${PASSWORD_MIN} ký tự)` : ''}</label>
            <input
              id="pw"
              type="password"
              autoComplete={mode === 'in' ? 'current-password' : 'new-password'}
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </>
        )}
        {mode === 'up' && (
          <>
            <label htmlFor="pw2">Nhập lại mật khẩu</label>
            <input id="pw2" type="password" autoComplete="new-password" required value={confirm} onChange={(e) => setConfirm(e.target.value)} />
            <p className="muted">Dùng cùng email và mật khẩu khi đăng nhập trên app của bé.</p>
          </>
        )}
        {sent && (
          <div className="banner ok" role="status">
            Nếu email này đã có tài khoản, TimoKid vừa gửi thư kèm liên kết đặt lại mật khẩu (xem cả mục Thư rác). Bấm liên kết trong thư để đặt mật khẩu mới.
          </div>
        )}
        {error && <div className="banner err" role="alert">{error}</div>}
        <div className="row" style={{ marginTop: 14 }}>
          <button type="submit" disabled={busy}>
            {busy ? 'Đang xử lý…' : mode === 'in' ? 'Đăng nhập' : mode === 'up' ? 'Tạo tài khoản' : 'Gửi thư đặt lại'}
          </button>
        </div>
        <div className="row" style={{ marginTop: 10 }}>
          {mode === 'in' && <button type="button" className="link" onClick={() => go('forgot')}>Quên mật khẩu?</button>}
          {mode !== 'up' && <button type="button" className="link" onClick={() => go('up')}>Chưa có tài khoản? Đăng ký</button>}
          {mode !== 'in' && <button type="button" className="link" onClick={() => go('in')}>{mode === 'up' ? 'Đã có tài khoản? Đăng nhập' : 'Quay lại đăng nhập'}</button>}
        </div>
      </form>
    </div>
  );
}

// Lỗi đăng nhập đã được dịch sẵn trong lớp http (kind 'auth'); lỗi mạng/máy chủ dùng câu chung.
function errorMsg(e: unknown): string {
  const err = e as { kind?: string; message: string };
  return err.kind === 'auth' ? err.message : errorText(e);
}
