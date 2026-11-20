// Hai URL này là công khai (không phải bí mật); lấy từ Neon project `timokid`.
// Có thể ghi đè bằng biến môi trường Vite khi build (VITE_TIMOKID_AUTH_URL,
// VITE_TIMOKID_API_URL).
export const AUTH_URL: string =
  import.meta.env?.VITE_TIMOKID_AUTH_URL ??
  'https://ep-damp-waterfall-a1cu82wt.neonauth.ap-southeast-1.aws.neon.tech/timokid/auth';

export const API_URL: string =
  import.meta.env?.VITE_TIMOKID_API_URL ??
  'https://ep-damp-waterfall-a1cu82wt.apirest.ap-southeast-1.aws.neon.tech/timokid/rest/v1';
