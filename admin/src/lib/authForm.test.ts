import { describe, expect, it } from 'vitest';
import { cleanUrl, parseResetParams, resetRedirectUrl, validateAuth, validateNewPassword } from './authForm';

const base = { email: 'bo@example.com', password: 'matkhau123', confirm: 'matkhau123' };

describe('validateAuth', () => {
  it('đăng nhập hợp lệ', () => {
    expect(validateAuth({ mode: 'in', ...base })).toBeNull();
  });
  it('thiếu hoặc sai email', () => {
    expect(validateAuth({ mode: 'in', ...base, email: '  ' })).toBe('Hãy nhập email.');
    expect(validateAuth({ mode: 'in', ...base, email: 'abc' })).toMatch(/Email chưa đúng dạng/);
  });
  it('đăng ký: mật khẩu tối thiểu 8 ký tự và phải nhập lại giống nhau', () => {
    expect(validateAuth({ mode: 'up', ...base, password: 'ngan', confirm: 'ngan' })).toBe('Mật khẩu cần ít nhất 8 ký tự.');
    expect(validateAuth({ mode: 'up', ...base, confirm: 'khac' })).toBe('Hai mật khẩu chưa giống nhau.');
    expect(validateAuth({ mode: 'up', ...base })).toBeNull();
  });
  it('đăng nhập không ép độ dài mật khẩu cũ', () => {
    expect(validateAuth({ mode: 'in', ...base, password: 'abc', confirm: '' })).toBeNull();
  });
  it('quên mật khẩu chỉ cần email', () => {
    expect(validateAuth({ mode: 'forgot', email: 'bo@example.com', password: '', confirm: '' })).toBeNull();
  });
  it('mật khẩu mới', () => {
    expect(validateNewPassword('ngan', 'ngan')).toMatch(/ít nhất 8/);
    expect(validateNewPassword('matkhaumoi1', 'matkhaumoi2')).toMatch(/chưa giống/);
    expect(validateNewPassword('matkhaumoi1', 'matkhaumoi1')).toBeNull();
  });
});

describe('liên kết đặt lại mật khẩu', () => {
  it('redirect về gốc của trang admin', () => {
    expect(resetRedirectUrl('https://lavang-0708.github.io', '/TimoKid/')).toBe('https://lavang-0708.github.io/TimoKid/');
    expect(resetRedirectUrl('http://localhost:5173/', '/TimoKid/')).toBe('http://localhost:5173/TimoKid/');
  });
  it('đọc token và lỗi từ query', () => {
    expect(parseResetParams('?token=abc123')).toEqual({ kind: 'token', token: 'abc123' });
    expect(parseResetParams('?error=INVALID_TOKEN')).toEqual({ kind: 'error', code: 'INVALID_TOKEN' });
    expect(parseResetParams('')).toBeNull();
    expect(parseResetParams('?x=1')).toBeNull();
  });
  it('bỏ token khỏi URL nhưng giữ phần còn lại', () => {
    expect(cleanUrl('https://a.io/TimoKid/?token=abc&x=1#top')).toBe('/TimoKid/?x=1#top');
    expect(cleanUrl('https://a.io/TimoKid/?error=INVALID_TOKEN')).toBe('/TimoKid/');
  });
});
