import { defineConfig } from 'vitest/config';

// Kiểm thử đầu-cuối với backend thật. Chạy tay: npm run test:e2e
export default defineConfig({
  test: {
    include: ['src/**/*.e2e.test.ts'],
    testTimeout: 90_000,
    hookTimeout: 90_000,
  },
});
