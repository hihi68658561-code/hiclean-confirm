-- 1단계-zd: 공지사항 (사진 첨부) — phase1zc.sql 다음에 실행
create table if not exists public.notices (
  id          uuid primary key default gen_random_uuid(),
  title       text not null default '',
  content     text not null default '',
  pinned      boolean not null default false,       -- 맨 위 고정
  images      jsonb not null default '[]',          -- [{path, name}]
  author_name text not null default '',
  created_by  uuid default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists notices_created_idx on public.notices(created_at desc);
drop trigger if exists notices_touch on public.notices;
create trigger notices_touch before update on public.notices for each row execute function public.touch_updated();
alter table public.notices enable row level security;
drop policy if exists nt_select on public.notices;
drop policy if exists nt_write on public.notices;
-- 보기: 모든 직원(기사 포함) / 쓰기·고치기·지우기: 사무실·관리자
create policy nt_select on public.notices for select to authenticated using ((select public.is_staff()));
create policy nt_write on public.notices for all to authenticated using ((select public.is_office())) with check ((select public.is_office()));
revoke all on public.notices from anon;
grant select, insert, update, delete on public.notices to authenticated;

-- 공지 사진 저장공간 (비공개, 사진 1장 최대 10MB)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('notices', 'notices', false, 10485760, array['image/jpeg','image/png','image/webp','image/heic','image/gif'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists notice_img_select on storage.objects;
drop policy if exists notice_img_insert on storage.objects;
drop policy if exists notice_img_delete on storage.objects;
create policy notice_img_select on storage.objects for select to authenticated using (bucket_id = 'notices' and public.is_staff());
create policy notice_img_insert on storage.objects for insert to authenticated with check (bucket_id = 'notices' and public.is_office());
create policy notice_img_delete on storage.objects for delete to authenticated using (bucket_id = 'notices' and public.is_office());
