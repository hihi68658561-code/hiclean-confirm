-- 처음 한 번만: 대표님 계정을 관리자로 등록
-- 1) Supabase 'Authentication' → 'Users' → 'Add user' → 'Create new user'에서 대표님 이메일과 비밀번호로 계정을 만듭니다
--    ('Auto Confirm User' 체크).
-- 2) 아래 이메일을 그 이메일로 바꾼 뒤 SQL Editor에서 실행합니다.
insert into public.staff (user_id, name, role)
select id, '대표', 'admin' from auth.users where lower(email) = lower('여기에-대표님-이메일@example.com')
on conflict (user_id) do update set role = 'admin';
