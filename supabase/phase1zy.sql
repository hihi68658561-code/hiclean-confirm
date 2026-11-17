-- 1단계-zy: Security Advisor 경고 정리 (phase1zx.sql 다음에 실행)
-- 1) 함수마다 search_path 고정 (Function Search Path Mutable)
-- 2) 로그인 안 한 사람(anon)은 SECURITY DEFINER 함수를 못 부르게 (Public Can Execute ...)
-- 3) 트리거용 함수는 로그인한 직원도 직접 못 부르게 (Signed-In Users Can Execute ... 중 트리거 함수)
--    트리거는 이 권한과 상관없이 그대로 동작합니다.
-- 권한 확인용 함수(is_admin, is_office 등)와 직원 관리 함수(add_staff 등)는 프로그램이 써야 해서
-- 로그인한 직원에게는 그대로 열어 둡니다. 직원 관리 함수는 안에서 관리자인지 확인합니다.
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig, p.prosecdef, pg_get_function_result(p.oid) as ret,
           coalesce(array_to_string(p.proconfig, ','), '') as cfg
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prokind = 'f'
       and p.proowner = (select oid from pg_roles where rolname = current_user)
  loop
    if r.cfg not like '%search_path=%' then
      execute format('alter function %s set search_path = public, pg_temp', r.sig);
    end if;
    if r.prosecdef then
      execute format('revoke execute on function %s from public, anon', r.sig);
      if r.ret in ('trigger', 'event_trigger') then
        execute format('revoke execute on function %s from authenticated', r.sig);
      else
        execute format('grant execute on function %s to authenticated', r.sig);
      end if;
    end if;
  end loop;
end $$;
