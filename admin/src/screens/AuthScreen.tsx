import { useState, type FormEvent } from 'react';
import { http } from '../client';
import { errorText } from '../common';
import type { AuthUser } from '../lib/http';

export function AuthScreen({ onSignedIn }: { onSignedIn: (u: AuthUser) => void }) {
  const [mode, setMode] = useState<'in' | 'up'>('in');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const u =
        mode === 'in'
          ? await http.signIn(email.trim(), password)
          : await http.signUp(email.trim(), password, email.trim().split('@')[0] || 'Phụ huynh');
      onSignedIn(u);
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth">
      <h1 className="brand" style={{ textAlign: 'center', fontSize: '2rem' }}>TimoKid</h1>
      <p className="muted" style={{ textAlign: 'center' }}>Trang dành cho phụ huynh</p>
      <form className="card" onSubmit={submit}>
        <h2 style={{ marginTop: 0 }}>{mode === 'in' ? 'Đăng nhập' : 'Đăng ký'}</h2>
        <label htmlFor="email">Email</label>
        <input id="email" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        <label htmlFor="pw">Mật khẩu</label>
        <input
          id="pw"
          type="password"
          autoComplete={mode === 'in' ? 'current-password' : 'new-password'}
          minLength={8}
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        {mode === 'up' && <p className="muted">Dùng cùng email và mật khẩu khi đăng nhập trên app của bé.</p>}
        {error != null && <div className="banner err">{errorMsg(error)}</div>}
        <div className="row" style={{ marginTop: 14 }}>
          <button type="submit" disabled={busy}>
            {busy ? 'Đang xử lý…' : mode === 'in' ? 'Đăng nhập' : 'Tạo tài khoản'}
          </button>
          <button
            type="button"
            className="link"
            onClick={() => {
              setMode(mode === 'in' ? 'up' : 'in');
              setError(null);
            }}
          >
            {mode === 'in' ? 'Chưa có tài khoản? Đăng ký' : 'Đã có tài khoản? Đăng nhập'}
          </button>
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
