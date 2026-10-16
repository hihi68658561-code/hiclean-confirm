-- 하이클린 확인서 출력: Supabase 설정
-- Supabase 화면 왼쪽 메뉴 'SQL Editor' → 'New query'에 전체를 붙여넣고 'Run'을 누르세요.
-- 여러 번 실행해도 안전합니다.

-- 1) 직원(로그인 계정)과 역할: admin = 엑셀 올리기·고객 수정·직원 관리, viewer = 조회·인쇄만
create table if not exists public.staff (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  name       text not null default '',
  role       text not null default 'viewer' check (role in ('admin','viewer')),
  created_at timestamptz not null default now()
);

-- 2) 고객: 엑셀 한 줄 = 한 건. 항목은 data(JSON)에 그대로 보관
create table if not exists public.customers (
  id         text primary key,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid()
);

-- 3) 설정: 확인서에 찍히는 입금계좌 문구
create table if not exists public.settings (
  id   int primary key default 1 check (id = 1),
  bank text not null default '403-087449-01-023 기업은행 ㈜하이클린'
);
insert into public.settings (id) values (1) on conflict (id) do nothing;

-- 권한 확인 함수
create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff where user_id = auth.uid());
$$;
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff where user_id = auth.uid() and role = 'admin');
$$;

-- 행 단위 보안: 등록된 직원만 읽고, 관리자만 씀
alter table public.staff     enable row level security;
alter table public.customers enable row level security;
alter table public.settings  enable row level security;

drop policy if exists staff_read on public.staff;
create policy staff_read on public.staff for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists customers_read  on public.customers;
drop policy if exists customers_write on public.customers;
create policy customers_read  on public.customers for select to authenticated using (public.is_staff());
create policy customers_write on public.customers for all    to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists settings_read  on public.settings;
drop policy if exists settings_write on public.settings;
create policy settings_read  on public.settings for select to authenticated using (public.is_staff());
create policy settings_write on public.settings for update to authenticated using (public.is_admin()) with check (public.is_admin());

-- 로그인하지 않은 사람에게는 어떤 표도 열지 않음
revoke all on public.staff, public.customers, public.settings from anon;
grant select on public.staff to authenticated;
grant select, insert, update, delete on public.customers to authenticated;
grant select, update on public.settings to authenticated;

-- 직원 관리 함수 (관리자만 실행 가능)
create or replace function public.list_staff()
returns table (user_id uuid, email text, name text, role text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception '관리자만 볼 수 있습니다'; end if;
  return query select s.user_id, u.email::text, s.name, s.role
    from public.staff s join auth.users u on u.id = s.user_id order by s.role, s.name;
end $$;

create or replace function public.add_staff(p_email text, p_name text, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_admin() then raise exception '관리자만 직원을 등록할 수 있습니다'; end if;
  if p_role not in ('admin','viewer') then raise exception '역할이 올바르지 않습니다'; end if;
  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then raise exception '먼저 Supabase에서 이 이메일로 로그인 계정을 만들어 주세요'; end if;
  insert into public.staff (user_id, name, role) values (v_id, coalesce(p_name,''), p_role)
    on conflict (user_id) do update set name = excluded.name, role = excluded.role;
end $$;

create or replace function public.remove_staff(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception '관리자만 직원을 해제할 수 있습니다'; end if;
  if p_user = auth.uid() then raise exception '자기 자신은 해제할 수 없습니다'; end if;
  delete from public.staff where user_id = p_user;
end $$;

revoke all on function public.list_staff(), public.add_staff(text,text,text), public.remove_staff(uuid) from public, anon;
grant execute on function public.list_staff(), public.add_staff(text,text,text), public.remove_staff(uuid), public.is_staff(), public.is_admin() to authenticated;
