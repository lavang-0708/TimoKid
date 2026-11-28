// Kiểm tra form đăng nhập và đọc liên kết đặt lại mật khẩu (logic thuần).

export const PASSWORD_MIN = 8;

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export type AuthMode = 'in' | 'up' | 'forgot';

export interface AuthDraft {
  mode: AuthMode;
  email: string;
  password: string;
  confirm: string;
}

/** Trả thông báo lỗi tiếng Việt, hoặc null nếu hợp lệ. */
export function validateAuth(d: AuthDraft): string | null {
  const email = d.email.trim();
  if (!email) return 'Hãy nhập email.';
  if (!EMAIL_RE.test(email)) return 'Email chưa đúng dạng (vd: ten@gmail.com).';
  if (d.mode === 'forgot') return null;
  if (!d.password) return 'Hãy nhập mật khẩu.';
  if (d.mode === 'up') {
    if (d.password.length < PASSWORD_MIN) return `Mật khẩu cần ít nhất ${PASSWORD_MIN} ký tự.`;
    if (d.password !== d.confirm) return 'Hai mật khẩu chưa giống nhau.';
  }
  return null;
}

/** Kiểm tra mật khẩu mới (trang đặt lại và đổi mật khẩu). */
export function validateNewPassword(next: string, confirm: string): string | null {
  if (next.length < PASSWORD_MIN) return `Mật khẩu mới cần ít nhất ${PASSWORD_MIN} ký tự.`;
  if (next !== confirm) return 'Hai mật khẩu mới chưa giống nhau.';
  return null;
}

/**
 * Địa chỉ Neon Auth chuyển tới sau khi bấm liên kết trong email: chính trang web admin
 * (gốc của `base`), Neon thêm `?token=...` (hoặc `?error=INVALID_TOKEN`).
 */
export function resetRedirectUrl(origin: string, base: string): string {
  return `${origin.replace(/\/+$/, '')}${base.startsWith('/') ? base : `/${base}`}`;
}

export type ResetParams = { kind: 'token'; token: string } | { kind: 'error'; code: string } | null;

/** Đọc `?token=` hoặc `?error=` từ chuỗi query của trang. */
export function parseResetParams(search: string): ResetParams {
  const q = new URLSearchParams(search);
  const token = q.get('token');
  if (token) return { kind: 'token', token };
  const error = q.get('error');
  if (error) return { kind: 'error', code: error };
  return null;
}

/** Địa chỉ trang sau khi bỏ token/error khỏi URL (không để token nằm lại trong lịch sử). */
export function cleanUrl(href: string): string {
  const u = new URL(href);
  u.searchParams.delete('token');
  u.searchParams.delete('error');
  return u.pathname + (u.search ? u.search : '') + u.hash;
}
