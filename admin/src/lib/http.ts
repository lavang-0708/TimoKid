// Lớp gọi mạng nhỏ: Neon Auth (cookie phiên -> JWT ngắn hạn) và Data API
// (PostgREST, gửi `Authorization: Bearer <jwt>`).
//
// - JWT sống khoảng 15 phút: lấy từ {AUTH}/token, lưu trong bộ nhớ, tự làm
//   mới khi sắp hết hạn hoặc khi Data API trả 401.
// - Neon compute có thể đang ngủ: yêu cầu chậm hơn SLOW_MS thì báo
//   "đang đánh thức máy chủ"; lỗi 502/503/504 và lỗi mạng với yêu cầu đọc
//   được thử lại vài lần.

export type ErrorKind = 'network' | 'auth' | 'server' | 'client';

export class ApiError extends Error {
  readonly kind: ErrorKind;
  readonly status: number;
  readonly code?: string;
  constructor(kind: ErrorKind, status: number, message: string, code?: string) {
    super(message);
    this.name = 'ApiError';
    this.kind = kind;
    this.status = status;
    this.code = code;
  }
}

export function decodeJwtExp(jwt: string): number | null {
  try {
    const part = jwt.split('.')[1];
    if (!part) return null;
    const b64 = part.replace(/-/g, '+').replace(/_/g, '/');
    const json = JSON.parse(atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, '=')));
    return typeof json.exp === 'number' ? json.exp : null;
  } catch {
    return null;
  }
}

/** JWT còn dùng được tới `skewSec` giây nữa không. */
export function jwtFresh(jwt: string | null, nowMs: number, skewSec = 60): boolean {
  if (!jwt) return false;
  const exp = decodeJwtExp(jwt);
  if (exp === null) return false;
  return exp * 1000 - nowMs > skewSec * 1000;
}

const SLOW_MS = 2500;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export interface HttpOptions {
  fetchImpl?: typeof fetch;
  authUrl: string;
  apiUrl: string;
  now?: () => number;
}

export interface RequestInit2 {
  method?: string;
  headers?: Record<string, string>;
  body?: unknown;
  /** Thử lại khi lỗi mạng / 502-504. Mặc định chỉ với GET. */
  retry?: boolean;
}

export interface AuthUser {
  id: string;
  email: string;
}

export class NeonHttp {
  private readonly f: typeof fetch;
  private readonly authUrl: string;
  private readonly apiUrl: string;
  private readonly now: () => number;
  private jwt: string | null = null;
  private pending = 0;
  private slowTimers = new Set<ReturnType<typeof setTimeout>>();
  private slow = 0;
  private listeners = new Set<(waking: boolean) => void>();
  onAuthLost: (() => void) | null = null;

  constructor(opts: HttpOptions) {
    this.f = opts.fetchImpl ?? ((...a) => fetch(...a));
    this.authUrl = opts.authUrl;
    this.apiUrl = opts.apiUrl;
    this.now = opts.now ?? (() => Date.now());
  }

  /** Đăng ký nghe trạng thái "đang đánh thức máy chủ". */
  subscribeWaking(fn: (waking: boolean) => void): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  private emitWaking() {
    const waking = this.slow > 0;
    this.listeners.forEach((l) => l(waking));
  }

  private async raw(url: string, init: RequestInit): Promise<Response> {
    this.pending++;
    let slowFlag = false;
    const t = setTimeout(() => {
      slowFlag = true;
      this.slow++;
      this.emitWaking();
    }, SLOW_MS);
    this.slowTimers.add(t);
    try {
      return await this.f(url, init);
    } catch {
      throw new ApiError('network', 0, 'Không kết nối được mạng.');
    } finally {
      clearTimeout(t);
      this.slowTimers.delete(t);
      this.pending--;
      if (slowFlag) {
        this.slow--;
        this.emitWaking();
      }
    }
  }

  private async parse(res: Response): Promise<unknown> {
    const text = await res.text();
    if (!text) return null;
    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  }

  private toError(status: number, body: unknown): ApiError {
    const b = (body ?? {}) as Record<string, unknown>;
    const message = String(b.message ?? b.error ?? b.hint ?? `Lỗi ${status}`);
    const code = typeof b.code === 'string' ? b.code : undefined;
    // 'not authenticated' do ensure_family ném ra khi Data API chưa nhận ra JWT (thấy thoáng qua
    // ngay sau khi đăng ký): coi như lỗi xác thực để lấy JWT mới và thử lại một lần.
    if (status === 401 || /not authenticated/i.test(message) || (status === 403 && /jwt|token/i.test(message))) {
      return new ApiError('auth', status, message, code);
    }
    return new ApiError(status >= 500 ? 'server' : 'client', status, message, code);
  }

  // ------------------------------------------------------------- auth

  private authInit(method: string, body?: unknown): RequestInit {
    return {
      method,
      credentials: 'include',
      headers: body !== undefined ? { 'Content-Type': 'application/json' } : {},
      body: body !== undefined ? JSON.stringify(body) : undefined,
    };
  }

  async signUp(email: string, password: string, name: string): Promise<AuthUser> {
    const res = await this.raw(`${this.authUrl}/sign-up/email`, this.authInit('POST', { email, password, name }));
    const body = await this.parse(res);
    if (!res.ok) throw this.authFail(res.status, body);
    return this.userFrom(body);
  }

  async signIn(email: string, password: string): Promise<AuthUser> {
    const res = await this.raw(`${this.authUrl}/sign-in/email`, this.authInit('POST', { email, password }));
    const body = await this.parse(res);
    if (!res.ok) throw this.authFail(res.status, body);
    return this.userFrom(body);
  }

  private authFail(status: number, body: unknown): ApiError {
    const e = this.toError(status, body);
    const message = status === 429 ? 'Thử quá nhiều lần. Hãy đợi một lúc rồi thử lại.' : authMessageVi(e.code, e.message);
    return new ApiError(status >= 500 ? 'server' : 'auth', status, message, e.code);
  }

  private userFrom(body: unknown): AuthUser {
    const u = ((body ?? {}) as { user?: { id?: string; email?: string } }).user;
    return { id: u?.id ?? '', email: u?.email ?? '' };
  }

  /**
   * Xin email đặt lại mật khẩu (Better Auth `request-password-reset`, bản cũ tên
   * `forget-password`). Server luôn trả thành công dù email có tài khoản hay không.
   * `redirectTo` phải thuộc domain được phép (trusted origins) của Neon Auth; Neon gửi
   * thư chứa liên kết, bấm vào thì chuyển tới `redirectTo?token=...`.
   */
  async requestPasswordReset(email: string, redirectTo: string): Promise<void> {
    for (const path of ['request-password-reset', 'forget-password']) {
      const res = await this.raw(`${this.authUrl}/${path}`, this.authInit('POST', { email, redirectTo }));
      const body = await this.parse(res);
      if (res.ok) return;
      if (res.status === 404 && path === 'request-password-reset') continue;
      throw this.authFail(res.status, body);
    }
  }

  /** Hoàn tất đặt lại mật khẩu bằng token trong liên kết email. */
  async resetPassword(token: string, newPassword: string): Promise<void> {
    const res = await this.raw(`${this.authUrl}/reset-password`, this.authInit('POST', { token, newPassword }));
    const body = await this.parse(res);
    if (!res.ok) throw this.authFail(res.status, body);
  }

  /** Đổi mật khẩu khi đang đăng nhập (sai mật khẩu hiện tại: code INVALID_PASSWORD). */
  async changePassword(currentPassword: string, newPassword: string): Promise<void> {
    const res = await this.raw(
      `${this.authUrl}/change-password`,
      this.authInit('POST', { currentPassword, newPassword, revokeOtherSessions: false }),
    );
    const body = await this.parse(res);
    if (!res.ok) throw this.authFail(res.status, body);
  }

  /** Khôi phục phiên từ cookie; trả null nếu chưa đăng nhập. */
  async restore(): Promise<AuthUser | null> {
    try {
      await this.refreshJwt();
    } catch (e) {
      if (e instanceof ApiError && e.kind === 'auth') return null;
      throw e;
    }
    const res = await this.raw(`${this.authUrl}/get-session`, this.authInit('GET'));
    const body = await this.parse(res);
    if (!res.ok || !body) return null;
    return this.userFrom(body);
  }

  async signOut(): Promise<void> {
    try {
      await this.raw(`${this.authUrl}/sign-out`, this.authInit('POST', {}));
    } catch {
      // đăng xuất cục bộ vẫn tiếp tục
    }
    this.jwt = null;
  }

  async refreshJwt(): Promise<string> {
    const res = await this.raw(`${this.authUrl}/token`, this.authInit('GET'));
    const body = (await this.parse(res)) as { token?: string } | null;
    if (!res.ok || !body?.token) {
      this.jwt = null;
      throw new ApiError('auth', res.status || 401, 'Phiên đăng nhập đã hết hạn, hãy đăng nhập lại.');
    }
    this.jwt = body.token;
    return body.token;
  }

  private async token(): Promise<string> {
    if (jwtFresh(this.jwt, this.now())) return this.jwt as string;
    return this.refreshJwt();
  }

  // ------------------------------------------------------------- data

  async api<T = unknown>(path: string, init: RequestInit2 = {}): Promise<{ data: T; headers: Headers }> {
    const method = init.method ?? 'GET';
    const canRetry = init.retry ?? method === 'GET';
    let refreshed = false;
    let attempt = 0;
    for (;;) {
      let jwt: string;
      try {
        jwt = await this.token();
      } catch (e) {
        if (e instanceof ApiError && e.kind === 'auth') this.onAuthLost?.();
        throw e;
      }
      try {
        const res = await this.raw(`${this.apiUrl}/${path}`, {
          method,
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${jwt}`,
            ...(init.headers ?? {}),
          },
          body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
        });
        const body = await this.parse(res);
        if (res.ok) return { data: body as T, headers: res.headers };
        const err = this.toError(res.status, body);
        if (err.kind === 'auth' && !refreshed) {
          refreshed = true;
          this.jwt = null;
          continue;
        }
        if (err.kind === 'auth') this.onAuthLost?.();
        if ([502, 503, 504].includes(res.status) && canRetry && attempt < 3) {
          attempt++;
          await sleep(1000 * attempt);
          continue;
        }
        throw err;
      } catch (e) {
        if (e instanceof ApiError && e.kind === 'network' && canRetry && attempt < 3) {
          attempt++;
          await sleep(1000 * attempt);
          continue;
        }
        throw e;
      }
    }
  }
}

function authMessageVi(code: string | undefined, fallback: string): string {
  switch (code) {
    case 'INVALID_EMAIL_OR_PASSWORD':
      return 'Email hoặc mật khẩu không đúng.';
    case 'USER_ALREADY_EXISTS':
    case 'USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL':
      return 'Email này đã có tài khoản. Hãy đăng nhập.';
    case 'INVALID_EMAIL':
      return 'Email không hợp lệ.';
    case 'PASSWORD_TOO_SHORT':
      return 'Mật khẩu quá ngắn (cần ít nhất 8 ký tự).';
    case 'PASSWORD_TOO_LONG':
      return 'Mật khẩu quá dài.';
    case 'INVALID_PASSWORD':
      return 'Mật khẩu hiện tại chưa đúng.';
    case 'INVALID_TOKEN':
      return 'Liên kết đặt lại mật khẩu không đúng hoặc đã hết hạn. Hãy xin liên kết mới.';
    case 'RESET_PASSWORD_DISABLED':
      return 'Máy chủ chưa bật tính năng quên mật khẩu.';
    case 'EMAIL_NOT_VERIFIED':
      return 'Email chưa được xác nhận.';
    default:
      return /password/i.test(fallback) && /short/i.test(fallback)
        ? 'Mật khẩu quá ngắn (cần ít nhất 8 ký tự).'
        : 'Không thực hiện được: ' + fallback;
  }
}
