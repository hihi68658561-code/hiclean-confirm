-- 1단계-y: DB관리 (전화·중앙회 등 상담 신청 건 관리)
-- 계약 전 상담 건을 고객과 따로 보관하고, 계약되면 고객·계약으로 넘깁니다.
create table if not exists public.leads (
  id            uuid primary key default gen_random_uuid(),
  status        text not null default '',          -- 오더·미수·종결·방문·관리
  recv_date     date default current_date,          -- 접수일자
  item          text not null default '',          -- 품목 (초음파·젤라또 …)
  source        text not null default '',          -- 유입경로 (중앙회·인바운드·홍보관 …)
  receiver      text not null default '',          -- 접수자·선행자
  org           text not null default '',          -- 소속 (지회/업체)
  branch        text not null default '',          -- 지부
  contact_name  text not null default '',          -- 담당자/직급
  contact_phone text not null default '',          -- 담당자 연락처
  open_info     text not null default '',          -- 운영여부 (오픈일자)
  ceo           text not null default '',          -- 대표자
  biz_name      text not null default '',          -- 업장명
  address       text not null default '',
  phone         text not null default '',          -- 업장 연락처
  note          text not null default '',          -- 참고사항
  sales         uuid references public.staff(user_id) on delete set null,
  sales_name    text not null default '',          -- 영업담당
  progress      text not null default '',          -- 최종 진행내역 (오더·무료체험·통화요망·방문요망)
  feedback_date date,                               -- 피드백 일자
  next_date     date,                               -- 다음 연락일
  consults      jsonb not null default '[]',       -- 상담 이력 [{d:날짜, t:내용, by:작성자}]
  customer_id   uuid references public.customers(id) on delete set null,  -- 계약 전환된 고객
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid default auth.uid()
);
create index if not exists leads_recv_idx on public.leads(recv_date);
create index if not exists leads_updated_idx on public.leads(updated_at);
create index if not exists leads_customer_idx on public.leads(customer_id);
drop trigger if exists leads_touch on public.leads;
create trigger leads_touch before update on public.leads for each row execute function public.touch_updated();

alter table public.leads enable row level security;
drop policy if exists lead_select on public.leads;
drop policy if exists lead_insert on public.leads;
drop policy if exists lead_update on public.leads;
drop policy if exists lead_delete on public.leads;
-- 사무실·관리자는 전체, 영업은 본인이 영업담당이거나 직접 등록한 건, 기사는 안 보임
create policy lead_select on public.leads for select to authenticated
  using ((select public.is_office()) or ((select public.my_role()) = 'sales' and (sales = (select auth.uid()) or created_by = (select auth.uid()))));
create policy lead_insert on public.leads for insert to authenticated
  with check ((select public.is_office()) or (select public.my_role()) = 'sales');
create policy lead_update on public.leads for update to authenticated
  using ((select public.is_office()) or ((select public.my_role()) = 'sales' and (sales = (select auth.uid()) or created_by = (select auth.uid()))))
  with check ((select public.is_office()) or (select public.my_role()) = 'sales');
create policy lead_delete on public.leads for delete to authenticated using ((select public.is_admin()));
revoke all on public.leads from anon;
grant select, insert, update, delete on public.leads to authenticated;
