-- 1단계-zz2: 계약 입금 내역 수정·삭제는 사무실·관리자만 (phase1zz.sql 다음에 실행)
-- 영업 담당은 본인 고객의 입금을 '추가'만 할 수 있고, 고치거나 지울 수는 없습니다.
-- (A/S 입금은 그대로: 배정된 기사가 본인이 적은 입금을 고칠 수 있습니다)
drop policy if exists pay_update on public.payments;
create policy pay_update on public.payments for update to authenticated
  using (public.is_office()) with check (public.is_office());
drop policy if exists pay_delete on public.payments;
create policy pay_delete on public.payments for delete to authenticated
  using (public.is_office());
