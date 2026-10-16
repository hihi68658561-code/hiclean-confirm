-- 하이클린 업무관리 1단계: 역할 4종 · 고객 · 계약 · 설치/A/S
-- Supabase 'SQL Editor' → 'New query'에 전체를 붙여넣고 'Run'.
-- setup.sql을 먼저 실행한 상태여야 합니다. 여러 번 실행해도 안전합니다.
-- 기존 확인서용 고객표(customers)는 legacy_customers로 이름만 바꿔 보관합니다.

-- 0) 기존 고객표 보관
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='customers' and column_name='data') then
    alter table public.customers rename to legacy_customers;
  end if;
end $$;

-- 1) 직원 역할: admin 관리자 · office 사무실 · sales 영업 · tech 설치·A/S 기사
alter table public.staff drop constraint if exists staff_role_check;
update public.staff set role = 'office' where role not in ('admin','office','sales','tech');
alter table public.staff add constraint staff_role_check check (role in ('admin','office','sales','tech'));
alter table public.staff add column if not exists aliases text[] not null default '{}';
alter table public.staff add column if not exists active  boolean not null default true;

create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.staff where user_id = auth.uid() and active;
$$;
create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff where user_id = auth.uid() and active);
$$;
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff where user_id = auth.uid() and active and role = 'admin');
$$;
create or replace function public.is_office() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff where user_id = auth.uid() and active and role in ('admin','office'));
$$;

-- 2) 고객(업체)
create table if not exists public.customers (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,                 -- 업체명(상호)
  biz_name    text not null default '',      -- 사업장명
  ceo         text not null default '',      -- 대표자
  phone       text not null default '',      -- 휴대번호
  phone2      text not null default '',      -- 일반전화
  biz_no      text not null default '',      -- 사업자등록번호
  address     text not null default '',      -- 상점주소
  owner       uuid references public.staff(user_id) on delete set null,   -- 담당자(3차 계약자)
  owner_name  text not null default '',      -- 엑셀에 적힌 담당자 이름(직원 연결 전)
  collector   uuid references public.staff(user_id) on delete set null,   -- 수금 배정
  memo        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid default auth.uid()
);

-- 3) 계약(판매 1건 = 제품 1대)
create table if not exists public.contracts (
  id            uuid primary key default gen_random_uuid(),
  customer_id   uuid not null references public.customers(id) on delete cascade,
  contract_date date,
  stage         text not null default '확정' check (stage in ('미정','보류','확정','미수','완료','취소')),
  channel       text not null default '',    -- 구분(중앙회·인바운드·MOU·보상판매…)
  referrer      text not null default '',    -- 소개
  sales1        text not null default '',    -- 1차 선행자(직원 또는 외부인)
  sales2        text not null default '',    -- 2차 상담자
  sales3        uuid references public.staff(user_id) on delete set null,  -- 3차 계약자
  sales3_name   text not null default '',
  free_trial    text not null default '',    -- 무료체험 메모(예: 9/19)
  product       text not null default '',
  size          text not null default '',
  options       text not null default '',    -- 무턱, 좌배수
  serial        text not null default '',
  wash_added    boolean not null default false,  -- 수압식 세척기 추가 구매
  amt_ultra     bigint not null default 0,   -- 초음파
  amt_wash      bigint not null default 0,   -- 워시(수압식)
  amt_parts     bigint not null default 0,   -- 부자재
  amount        bigint not null default 0,   -- 합계금액(VAT 포함)
  pay_method    text not null default '',    -- 현금·카드·카드+현금·CMS·분납·캐피탈
  contract_doc  text not null default '미수령' check (contract_doc in ('미수령','사진','원본','전자서명')),
  capital       jsonb not null default '{}', -- 승인처·승인자·월할부금·이자·기간·합계
  cms           jsonb not null default '{}', -- 출금일·월금액·기간
  tax           jsonb not null default '{}', -- 증빙 종류·발행일·공급가액·부가세
  settle_month  text not null default '',    -- 정산년월 YYYY-MM
  memo          text not null default '',
  import_raw    jsonb,                       -- 엑셀 원본 한 줄(입금 정보 이관용)
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid default auth.uid()
);
create index if not exists contracts_customer_idx on public.contracts(customer_id);

-- 4) 설치·A/S 작업
create table if not exists public.jobs (
  id            uuid primary key default gen_random_uuid(),
  kind          text not null check (kind in ('install','as')),
  customer_id   uuid not null references public.customers(id) on delete cascade,
  contract_id   uuid references public.contracts(id) on delete set null,
  customer_name text not null default '',    -- 목록 표시용(기사 전체 조회)
  address       text not null default '',
  product       jsonb not null default '{}', -- 제품·사이즈·옵션·시리얼 (확인서용)
  status        text not null default '접수' check (status in ('접수','배정','완료','취소')),
  request_date  date default current_date,
  visit_date    date,
  visit_time    text not null default '',
  techs         uuid[] not null default '{}',
  tech_names    text not null default '',    -- 외부업체·배송·엑셀 이름
  symptom       text not null default '',    -- 요청·불편사항
  result        text not null default '',    -- 처리 내용
  cost          bigint not null default 0,   -- A/S 비용
  sink_status   text not null default '' check (sink_status in ('','해당없음','발주대기','발주완료','중고사용','재고사용','기타')),
  sink_memo     text not null default '',
  parts         text not null default '',    -- 제공 부자재
  done_date     date,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid default auth.uid()
);
create index if not exists jobs_customer_idx on public.jobs(customer_id);

-- 볼 수 있는 고객: 사무실·관리자는 전체, 담당자·수금 배정자, 그 고객의 작업에 배정된 기사
create or replace function public.can_see_customer(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_office()
      or exists (select 1 from public.customers x where x.id = c and auth.uid() in (x.owner, x.collector) and public.is_staff())
      or exists (select 1 from public.jobs j where j.customer_id = c and auth.uid() = any(j.techs) and public.is_staff());
$$;
create or replace function public.owns_customer(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_staff() and exists (select 1 from public.customers x where x.id = c and x.owner = auth.uid());
$$;

-- 5) 행 단위 보안
alter table public.customers enable row level security;
alter table public.contracts enable row level security;
alter table public.jobs      enable row level security;

drop policy if exists staff_read on public.staff;
create policy staff_read on public.staff for select to authenticated using (public.is_staff() or user_id = auth.uid());

drop policy if exists cust_select on public.customers;
drop policy if exists cust_insert on public.customers;
drop policy if exists cust_update on public.customers;
drop policy if exists cust_delete on public.customers;
create policy cust_select on public.customers for select to authenticated using (public.can_see_customer(id));
create policy cust_insert on public.customers for insert to authenticated
  with check (public.is_office() or (public.my_role() = 'sales' and owner = auth.uid()));
create policy cust_update on public.customers for update to authenticated
  using (public.is_office() or (owner = auth.uid() and public.is_staff()))
  with check (public.is_office() or (owner = auth.uid() and public.is_staff()));
create policy cust_delete on public.customers for delete to authenticated using (public.is_admin());

drop policy if exists ctr_select on public.contracts;
drop policy if exists ctr_insert on public.contracts;
drop policy if exists ctr_update on public.contracts;
drop policy if exists ctr_delete on public.contracts;
create policy ctr_select on public.contracts for select to authenticated
  using (public.is_office() or (public.my_role() = 'sales' and public.can_see_customer(customer_id)));
create policy ctr_insert on public.contracts for insert to authenticated
  with check (public.is_office() or (public.my_role() = 'sales' and public.owns_customer(customer_id)));
create policy ctr_update on public.contracts for update to authenticated
  using (public.is_office() or (public.my_role() = 'sales' and public.owns_customer(customer_id)))
  with check (public.is_office() or (public.my_role() = 'sales' and public.owns_customer(customer_id)));
create policy ctr_delete on public.contracts for delete to authenticated using (public.is_admin());

drop policy if exists job_select on public.jobs;
drop policy if exists job_insert on public.jobs;
drop policy if exists job_update on public.jobs;
drop policy if exists job_delete on public.jobs;
create policy job_select on public.jobs for select to authenticated
  using (public.is_office() or public.my_role() = 'tech' or (public.my_role() = 'sales' and public.can_see_customer(customer_id)));
create policy job_insert on public.jobs for insert to authenticated
  with check (public.is_office() or (public.my_role() = 'sales' and public.can_see_customer(customer_id)));
create policy job_update on public.jobs for update to authenticated
  using (public.is_office() or (auth.uid() = any(techs) and public.is_staff()))
  with check (public.is_office() or (auth.uid() = any(techs) and public.is_staff()));
create policy job_delete on public.jobs for delete to authenticated using (public.is_admin());

revoke all on public.customers, public.contracts, public.jobs from anon;
grant select, insert, update, delete on public.customers, public.contracts, public.jobs to authenticated;

-- 수정 시각 자동 기록
create or replace function public.touch_updated() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists customers_touch on public.customers;
drop trigger if exists contracts_touch on public.contracts;
drop trigger if exists jobs_touch on public.jobs;
create trigger customers_touch before update on public.customers for each row execute function public.touch_updated();
create trigger contracts_touch before update on public.contracts for each row execute function public.touch_updated();
create trigger jobs_touch      before update on public.jobs      for each row execute function public.touch_updated();

-- 6) 직원 관리 함수 (관리자만)
drop function if exists public.list_staff();
create or replace function public.list_staff()
returns table (user_id uuid, email text, name text, role text, aliases text[], active boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception '관리자만 볼 수 있습니다'; end if;
  return query select s.user_id, u.email::text, s.name, s.role, s.aliases, s.active
    from public.staff s join auth.users u on u.id = s.user_id order by s.active desc, s.role, s.name;
end $$;

create or replace function public.add_staff(p_email text, p_name text, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_admin() then raise exception '관리자만 직원을 등록할 수 있습니다'; end if;
  if p_role not in ('admin','office','sales','tech') then raise exception '역할이 올바르지 않습니다'; end if;
  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then raise exception '먼저 Supabase에서 이 이메일로 로그인 계정을 만들어 주세요'; end if;
  insert into public.staff (user_id, name, role) values (v_id, coalesce(p_name,''), p_role)
    on conflict (user_id) do update set name = excluded.name, role = excluded.role, active = true;
end $$;

create or replace function public.update_staff(p_user uuid, p_name text, p_role text, p_aliases text[], p_active boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception '관리자만 바꿀 수 있습니다'; end if;
  if p_role not in ('admin','office','sales','tech') then raise exception '역할이 올바르지 않습니다'; end if;
  if p_user = auth.uid() and (p_role <> 'admin' or not p_active) then raise exception '자기 자신의 관리자 권한은 해제할 수 없습니다'; end if;
  update public.staff set name = coalesce(p_name,''), role = p_role, aliases = coalesce(p_aliases,'{}'), active = p_active
   where user_id = p_user;
end $$;

-- 엑셀에 적힌 이름(3차·설치1)을 직원 계정에 연결
create or replace function public.link_staff_names()
returns table (owners int, sellers int, jobs_linked int)
language plpgsql security definer set search_path = public as $$
declare a int; b int; c int;
begin
  if not public.is_office() then raise exception '관리자·사무실만 실행할 수 있습니다'; end if;
  update public.contracts k set sales3 = s.user_id
    from public.staff s
   where k.sales3 is null and k.sales3_name <> '' and s.active
     and (k.sales3_name = s.name or k.sales3_name = any(s.aliases));
  get diagnostics b = row_count;
  update public.customers x set owner = s.user_id
    from public.staff s
   where x.owner is null and x.owner_name <> '' and s.active
     and (x.owner_name = s.name or x.owner_name = any(s.aliases));
  get diagnostics a = row_count;
  update public.jobs j set techs = (
      select coalesce(array_agg(distinct s.user_id), '{}') from public.staff s
       where s.active and exists (select 1 from regexp_split_to_table(j.tech_names, '[\s,/]+') t
                                   where t <> '' and (t = s.name or t = any(s.aliases))))
   where cardinality(j.techs) = 0 and j.tech_names <> '';
  get diagnostics c = row_count;
  return query select a, b, c;
end $$;

revoke all on function public.list_staff(), public.add_staff(text,text,text), public.remove_staff(uuid),
  public.update_staff(uuid,text,text,text[],boolean), public.link_staff_names() from public, anon;
grant execute on function public.list_staff(), public.add_staff(text,text,text), public.remove_staff(uuid),
  public.update_staff(uuid,text,text,text[],boolean), public.link_staff_names(),
  public.my_role(), public.is_staff(), public.is_admin(), public.is_office(),
  public.can_see_customer(uuid), public.owns_customer(uuid) to authenticated;
