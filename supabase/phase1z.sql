-- 1단계-z: 미수·채권관리 (채권 건 + 조치 이력)
-- 채권 건: 미수가 있는 계약·A/S 1건마다 1줄 (처음 기록할 때 생김). 조치 이력: 누가·언제·무엇을 했는지.

create table if not exists public.recv_cases (
  id             uuid primary key default gen_random_uuid(),
  ref_type       text not null check (ref_type in ('ctr','as')),   -- 계약 / A/S
  ref_id         uuid not null,                                      -- contracts.id 또는 jobs.id
  customer_id    uuid not null references public.customers(id) on delete cascade,
  stage          text not null default '정상관리'
                 check (stage in ('정상관리','독촉중','분할약정','내용증명','법적조치','추심이관','회수완료','대손처리')),
  next_date      date,                 -- 다음 조치일
  promise_date   date,                 -- 입금 약속일
  promise_amount bigint not null default 0,
  transfer       jsonb not null default '{}',   -- 이관 정보 {date,to,contact,amount,status,result}
  memo           text not null default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid default auth.uid(),
  unique (ref_type, ref_id)
);
create index if not exists recv_cases_customer_idx on public.recv_cases(customer_id);
drop trigger if exists recv_cases_touch on public.recv_cases;
create trigger recv_cases_touch before update on public.recv_cases for each row execute function public.touch_updated();

create table if not exists public.recv_logs (
  id             uuid primary key default gen_random_uuid(),
  case_id        uuid not null references public.recv_cases(id) on delete cascade,
  customer_id    uuid not null references public.customers(id) on delete cascade,
  method         text not null default '전화',   -- 전화·문자·방문·내용증명·법적조치·이관·기타
  content        text not null default '',
  promise_date   date,
  promise_amount bigint not null default 0,
  next_date      date,
  by_name        text not null default '',
  edited_by_name text not null default '',
  edited_at      timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid default auth.uid()
);
create index if not exists recv_logs_case_idx on public.recv_logs(case_id);
drop trigger if exists recv_logs_touch on public.recv_logs;
create trigger recv_logs_touch before update on public.recv_logs for each row execute function public.touch_updated();

alter table public.recv_cases enable row level security;
alter table public.recv_logs  enable row level security;
drop policy if exists rc_select on public.recv_cases;
drop policy if exists rc_insert on public.recv_cases;
drop policy if exists rc_update on public.recv_cases;
drop policy if exists rc_delete on public.recv_cases;
drop policy if exists rl_select on public.recv_logs;
drop policy if exists rl_insert on public.recv_logs;
drop policy if exists rl_update on public.recv_logs;
drop policy if exists rl_delete on public.recv_logs;
-- 보기: 사무실·관리자 전체, 영업은 본인 담당·수금 고객. 기사는 안 보임
create policy rc_select on public.recv_cases for select to authenticated
  using ((select public.is_office()) or ((select public.my_role()) = 'sales' and customer_id in (select public.my_customer_ids())));
create policy rc_insert on public.recv_cases for insert to authenticated
  with check ((select public.is_office()) or ((select public.my_role()) = 'sales' and customer_id in (select public.my_customer_ids())));
-- 단계 변경 등 수정: 사무실·관리자, 영업은 본인 고객의 다음 조치일·약속만 (화면에서 제한)
create policy rc_update on public.recv_cases for update to authenticated
  using ((select public.is_office()) or ((select public.my_role()) = 'sales' and customer_id in (select public.my_customer_ids())))
  with check ((select public.is_office()) or ((select public.my_role()) = 'sales' and customer_id in (select public.my_customer_ids())));
create policy rc_delete on public.recv_cases for delete to authenticated using ((select public.is_admin()));
create policy rl_select on public.recv_logs for select to authenticated
  using ((select public.is_office()) or ((select public.my_role()) = 'sales' and customer_id in (select public.my_customer_ids())));
create policy rl_insert on public.recv_logs for insert to authenticated
  with check ((select public.is_office()) or ((select public.my_role()) = 'sales' and customer_id in (select public.my_customer_ids())));
-- 조치 이력은 사무실·관리자만 고칠 수 있고(고친 사람·시각 남김), 지우기는 관리자만
create policy rl_update on public.recv_logs for update to authenticated using ((select public.is_office())) with check ((select public.is_office()));
create policy rl_delete on public.recv_logs for delete to authenticated using ((select public.is_admin()));
revoke all on public.recv_cases from anon;
revoke all on public.recv_logs from anon;
grant select, insert, update, delete on public.recv_cases to authenticated;
grant select, insert, update, delete on public.recv_logs to authenticated;

-- 사진·서류에 '채권' 종류 추가 (내용증명·지급명령 등). 기사에게는 계약서처럼 숨김
alter table public.customer_files drop constraint if exists customer_files_kind_check;
alter table public.customer_files add constraint customer_files_kind_check
  check (kind in ('계약서','설치사진','철거사진','A/S사진','사업자등록증','채권','기타'));
drop policy if exists cf_select on public.customer_files;
create policy cf_select on public.customer_files for select to authenticated
  using (((select public.is_office()) or customer_id in (select public.my_customer_ids())) and ((select public.my_role()) <> 'tech' or kind not in ('계약서','채권')));
drop policy if exists bizdoc_select on storage.objects;
create policy bizdoc_select on storage.objects for select to authenticated
  using (bucket_id = 'bizdocs' and public.can_see_customer(public.bizdoc_customer(name))
         and (public.my_role() <> 'tech' or split_part(name, '/', 3) not in ('ctr','debt')));
