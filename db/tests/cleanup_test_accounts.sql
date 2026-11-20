-- Xóa dữ liệu và tài khoản thử do db/tests/rls_test.py tạo (email rls-*@example.com).
-- Chạy bằng role chủ database sau mỗi lần chạy kiểm thử.
delete from public.families f using neon_auth."user" u
 where f.owner_user_id = u.id::text and u.email like 'rls-%@example.com';
delete from neon_auth."user" where email like 'rls-%@example.com';
