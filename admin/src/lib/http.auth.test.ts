// Luồng quên / đặt lại / đổi mật khẩu của NeonHttp với fetch giả (không gọi mạng thật).
import { describe, expect, it } from 'vitest';
import { ApiError, NeonHttp } from './http';

interface Call {
  url: string;
  method: string;
  body: unknown;
}

function makeHttp(handler: (url: string, body: unknown) => { status: number; json?: unknown }) {
  const calls: Call[] = [];
  const fetchImpl = (async (url: string, init: RequestInit = {}) => {
    const body = init.body ? JSON.parse(String(init.body)) : undefined;
    calls.push({ url, method: init.method ?? 'GET', body });
    const r = handler(url, body);
    return new Response(r.json === undefined ? '' : JSON.stringify(r.json), { status: r.status });
  }) as typeof fetch;
  return { http: new NeonHttp({ fetchImpl, authUrl: 'https://auth.test/auth', apiUrl: 'https://api.test/rest/v1' }), calls };
}

describe('requestPasswordReset', () => {
  it('gọi request-password-reset với email và redirectTo', async () => {
    const { http, calls } = makeHttp(() => ({ status: 200, json: { status: true } }));
    await http.requestPasswordReset('bo@example.com', 'https://lavang-0708.github.io/TimoKid/');
    expect(calls).toEqual([
      {
        url: 'https://auth.test/auth/request-password-reset',
        method: 'POST',
        body: { email: 'bo@example.com', redirectTo: 'https://lavang-0708.github.io/TimoKid/' },
      },
    ]);
  });
  it('bản Better Auth cũ (404): thử forget-password', async () => {
    const { http, calls } = makeHttp((url) =>
      url.endsWith('/request-password-reset') ? { status: 404, json: { message: 'Not found' } } : { status: 200, json: { status: true } },
    );
    await http.requestPasswordReset('bo@example.com', 'https://x.io/');
    expect(calls.map((c) => c.url.split('/').pop())).toEqual(['request-password-reset', 'forget-password']);
  });
  it('lỗi mạng', async () => {
    const http = new NeonHttp({
      fetchImpl: (async () => {
        throw new TypeError('offline');
      }) as typeof fetch,
      authUrl: 'https://auth.test/auth',
      apiUrl: 'https://api.test',
    });
    await expect(http.requestPasswordReset('a@b.co', 'https://x.io/')).rejects.toMatchObject({ kind: 'network' });
  });
  it('429: báo thử quá nhiều lần', async () => {
    const { http } = makeHttp(() => ({ status: 429, json: { message: 'Too many requests' } }));
    await expect(http.requestPasswordReset('a@b.co', 'https://x.io/')).rejects.toThrow(/quá nhiều lần/);
  });
});

describe('resetPassword', () => {
  it('gửi token và mật khẩu mới', async () => {
    const { http, calls } = makeHttp(() => ({ status: 200, json: { status: true } }));
    await http.resetPassword('tok123', 'matkhaumoi1');
    expect(calls[0].url).toBe('https://auth.test/auth/reset-password');
    expect(calls[0].body).toEqual({ token: 'tok123', newPassword: 'matkhaumoi1' });
  });
  it('token sai/hết hạn: thông báo tiếng Việt', async () => {
    const { http } = makeHttp(() => ({ status: 400, json: { code: 'INVALID_TOKEN', message: 'Invalid token' } }));
    const err = await http.resetPassword('xxx', 'matkhaumoi1').catch((e) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err.kind).toBe('auth');
    expect(err.message).toMatch(/hết hạn/);
  });
  it('mật khẩu quá ngắn', async () => {
    const { http } = makeHttp(() => ({ status: 400, json: { code: 'PASSWORD_TOO_SHORT', message: 'Password too short' } }));
    await expect(http.resetPassword('t', 'ngan')).rejects.toThrow(/ít nhất 8/);
  });
});

describe('changePassword', () => {
  it('gửi mật khẩu hiện tại và mới', async () => {
    const { http, calls } = makeHttp(() => ({ status: 200, json: { status: true } }));
    await http.changePassword('cu123456', 'moi123456');
    expect(calls[0].body).toEqual({ currentPassword: 'cu123456', newPassword: 'moi123456', revokeOtherSessions: false });
  });
  it('sai mật khẩu hiện tại', async () => {
    const { http } = makeHttp(() => ({ status: 400, json: { code: 'INVALID_PASSWORD', message: 'Invalid password' } }));
    await expect(http.changePassword('sai', 'moi123456')).rejects.toThrow('Mật khẩu hiện tại chưa đúng.');
  });
});

describe('đăng ký / đăng nhập: thông báo lỗi', () => {
  it('email đã dùng', async () => {
    const { http } = makeHttp(() => ({ status: 422, json: { code: 'USER_ALREADY_EXISTS', message: 'User already exists' } }));
    await expect(http.signUp('a@b.co', 'matkhau123', 'a')).rejects.toThrow(/đã có tài khoản/);
  });
  it('sai mật khẩu', async () => {
    const { http } = makeHttp(() => ({ status: 401, json: { code: 'INVALID_EMAIL_OR_PASSWORD', message: 'x' } }));
    await expect(http.signIn('a@b.co', 'sai')).rejects.toThrow('Email hoặc mật khẩu không đúng.');
  });
});
