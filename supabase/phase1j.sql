-- 1단계-j: 고객별 사진·서류 (계약서, 설치사진, A/S사진, 사업자등록증, 기타)
-- 파일은 비공개 저장공간 'bizdocs'의 '고객ID/f/종류코드/파일명'에 보관합니다. (phase1i.sql 먼저 실행)
-- 계약서 사진은 금액이 보이므로 기사 계정에는 보이지 않습니다.

create table if not exists public.customer_files (
  id          uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  path        text not null unique,
  kind        text not null default '기타' check (kind in ('계약서','설치사진','A/S사진','사업자등록증','기타')),
  name        text not null default '',
  mime        text not null default '',
  size        bigint not null default 0,
  memo        text not null default '',
  created_at  timestamptz not null default now(),
  created_by  uuid default auth.uid()
);
create index if not exists customer_files_customer_idx on public.customer_files(customer_id);

alter table public.customer_files enable row level security;
drop policy if exists cf_select on public.customer_files;
drop policy if exists cf_insert on public.customer_files;
drop policy if exists cf_update on public.customer_files;
drop policy if exists cf_delete on public.customer_files;
create policy cf_select on public.customer_files for select to authenticated
  using (public.can_see_customer(customer_id) and (public.my_role() <> 'tech' or kind <> '계약서'));
create policy cf_insert on public.customer_files for insert to authenticated
  with check (public.is_staff() and public.can_see_customer(customer_id));
create policy cf_update on public.customer_files for update to authenticated
  using (public.is_office()) with check (public.is_office());
create policy cf_delete on public.customer_files for delete to authenticated using (public.is_office());
revoke all on public.customer_files from anon;
grant select, insert, update, delete on public.customer_files to authenticated;

-- 저장공간 권한 갱신: 그 고객을 볼 수 있는 직원(배정 기사 포함)은 올릴 수 있고, 계약서 폴더(ctr)는 기사에게 숨김
drop policy if exists bizdoc_select on storage.objects;
drop policy if exists bizdoc_insert on storage.objects;
create policy bizdoc_select on storage.objects for select to authenticated
  using (bucket_id = 'bizdocs' and public.can_see_customer(public.bizdoc_customer(name))
         and (public.my_role() <> 'tech' or split_part(name, '/', 3) <> 'ctr'));
create policy bizdoc_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'bizdocs' and public.is_staff() and public.can_see_customer(public.bizdoc_customer(name)));
