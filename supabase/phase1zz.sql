-- 1단계-zz: 본인이 올린 사진은 본인도 삭제 (phase1zy.sql 다음에 실행)
-- 지금까지는 사무실·관리자만 사진을 지울 수 있었습니다. 기사·영업이 잘못 올린 사진을 바로 지울 수 있게 합니다.
drop policy if exists cf_delete on public.customer_files;
create policy cf_delete on public.customer_files for delete to authenticated
  using ((select public.is_office()) or created_by = (select auth.uid()));

drop policy if exists bizdoc_delete on storage.objects;
create policy bizdoc_delete on storage.objects for delete to authenticated
  using (bucket_id = 'bizdocs' and ((select public.is_office()) or owner_id = (select auth.uid())::text));
