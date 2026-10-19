-- 1단계-h: 계약관리 (입금 내역 · 승인처 · 마감 체크)
-- 계약마다 입금 내역을 건수 제한 없이 기록합니다. 최종결제일·입금합계·미수금은 화면에서 자동 계산합니다.

-- 1) 계약에 승인처·마감 체크 칸 추가
alter table public.contracts add column if not exists approval  text not null default '';  -- 승인처 (예: 삼성+현금, 네이버)
alter table public.contracts add column if not exists chk_cust  text not null default '';  -- 고객등록 (OK, 임시코드, 기존고객 …)
alter table public.contracts add column if not exists chk_slip  text not null default '';  -- 전표마감
alter table public.contracts add column if not exists chk_sales text not null default '';  -- 매출마감

-- 2) 입금 내역
create table if not exists public.payments (
  id          uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.contracts(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  pay_date    date,
  method      text not null default '현금' check (method in ('카드','현금','입금','캐피탈','CMS','승인취소')),
  payer       text not null default '',   -- 카드사 / 입금자명
  amount      bigint not null default 0,  -- 승인취소는 음수
  memo        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid default auth.uid()
);
create index if not exists payments_contract_idx on public.payments(contract_id);

-- 3) 권한: 계약과 같음 (사무실·관리자 전체, 영업은 본인 고객 조회·본인 담당 고객 입력, 기사는 볼 수 없음, 삭제는 사무실·관리자)
alter table public.payments enable row level security;
drop policy if exists pay_select on public.payments;
drop policy if exists pay_insert on public.payments;
drop policy if exists pay_update on public.payments;
drop policy if exists pay_delete on public.payments;
create policy pay_select on public.payments for select to authenticated
  using (public.is_office() or (public.my_role() = 'sales' and public.can_see_customer(customer_id)));
create policy pay_insert on public.payments for insert to authenticated
  with check (public.is_office() or (public.my_role() = 'sales' and public.owns_customer(customer_id)));
create policy pay_update on public.payments for update to authenticated
  using (public.is_office() or (public.my_role() = 'sales' and public.owns_customer(customer_id)))
  with check (public.is_office() or (public.my_role() = 'sales' and public.owns_customer(customer_id)));
create policy pay_delete on public.payments for delete to authenticated using (public.is_office());
revoke all on public.payments from anon;
grant select, insert, update, delete on public.payments to authenticated;

drop trigger if exists payments_touch on public.payments;
create trigger payments_touch before update on public.payments for each row execute function public.touch_updated();
