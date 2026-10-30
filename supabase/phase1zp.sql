-- 1단계-zp: 직원 역할 여러 개 (phase1zo.sql 다음에 실행)
-- 기본 역할(권한)은 그대로 하나이고, '추가 역할'로 다른 업무를 더 맡깁니다.
--   예) 사무실 + A/S 기사 → 기사 배정·일정표 목록에 나오고 '내 배정 건'을 볼 수 있음
--       영업 + A/S 기사   → 영업 권한은 그대로, 배정받은 설치·A/S 건을 보고 처리
alter table public.staff add column if not exists extra_roles text[] not null default '{}';

create or replace function public.set_staff_extra(p_user uuid, p_roles text[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception '관리자만 바꿀 수 있습니다'; end if;
  update public.staff
     set extra_roles = coalesce((select array_agg(distinct r) from unnest(coalesce(p_roles,'{}')) r
                                 where r in ('admin','office','sales','tech') and r <> staff.role), '{}')
   where user_id = p_user;
end $$;
revoke all on function public.set_staff_extra(uuid, text[]) from public, anon;
grant execute on function public.set_staff_extra(uuid, text[]) to authenticated;
