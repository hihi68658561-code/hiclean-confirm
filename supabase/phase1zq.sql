-- 1단계-zq: 직원 연락처 (phase1zp.sql 다음에 실행)
-- 방문 안내(알림톡·문자)에 담당 기사 연락처를 넣기 위해 직원마다 연락처를 둡니다.
alter table public.staff add column if not exists phone text not null default '';

create or replace function public.set_staff_phone(p_user uuid, p_phone text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception '관리자만 바꿀 수 있습니다'; end if;
  update public.staff set phone = coalesce(trim(p_phone), '') where user_id = p_user;
end $$;
revoke all on function public.set_staff_phone(uuid, text) from public, anon;
grant execute on function public.set_staff_phone(uuid, text) to authenticated;
