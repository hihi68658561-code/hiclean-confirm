-- 1단계-zz2: 계약 입금 내역 삭제 권한을 입력·수정 권한과 맞춤 (phase1zz.sql 다음에 실행)
-- 지금까지 영업 담당은 본인 고객의 입금을 넣고 고칠 수는 있었지만 지울 수는 없었습니다.
-- (화면에는 삭제 버튼이 보이고 '삭제했습니다'라고 나오지만 실제로는 지워지지 않던 문제)
drop policy if exists pay_delete on public.payments;
create policy pay_delete on public.payments for delete to authenticated
  using (public.is_office() or (public.my_role() = 'sales' and public.owns_customer(customer_id)));
