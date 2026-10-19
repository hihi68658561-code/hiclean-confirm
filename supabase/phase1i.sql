-- 1단계-i: 사업자등록증 보관
-- 고객마다 사업자등록증 파일(사진·PDF)을 비공개 저장공간 'bizdocs'에 '고객ID/파일명'으로 보관합니다.

-- 1) 고객에 등록증 파일 위치 칸
alter table public.customers add column if not exists biz_doc text not null default '';

-- 2) 비공개 저장공간 (파일 1개 최대 10MB, 사진·PDF만)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bizdocs', 'bizdocs', false, 10485760, array['image/jpeg','image/png','image/webp','image/heic','application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- 3) 파일 경로의 첫 폴더(고객ID)를 꺼내는 도우미
create or replace function public.bizdoc_customer(path text) returns uuid
language sql immutable as $$
  select case when split_part(path, '/', 1) ~ '^[0-9a-fA-F-]{36}$' then split_part(path, '/', 1)::uuid end
$$;

-- 4) 권한: 그 고객을 볼 수 있는 직원만 보기, 고객정보를 고칠 수 있는 직원만 올리기, 삭제는 사무실·관리자
drop policy if exists bizdoc_select on storage.objects;
drop policy if exists bizdoc_insert on storage.objects;
drop policy if exists bizdoc_update on storage.objects;
drop policy if exists bizdoc_delete on storage.objects;
create policy bizdoc_select on storage.objects for select to authenticated
  using (bucket_id = 'bizdocs' and public.can_see_customer(public.bizdoc_customer(name)));
create policy bizdoc_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'bizdocs' and (public.is_office() or (public.my_role() = 'sales' and public.owns_customer(public.bizdoc_customer(name)))));
create policy bizdoc_update on storage.objects for update to authenticated
  using (bucket_id = 'bizdocs' and (public.is_office() or (public.my_role() = 'sales' and public.owns_customer(public.bizdoc_customer(name)))));
create policy bizdoc_delete on storage.objects for delete to authenticated
  using (bucket_id = 'bizdocs' and public.is_office());
