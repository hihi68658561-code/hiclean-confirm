-- 1단계-ze: 싱크대 발주 (phase1zd.sql 다음에 실행)
-- 발주 1건 = 업장 1곳의 품목 여러 개. 담당자(영업)는 품목만 입력, 금액·진행사항은 사무실·관리자만.
create table if not exists public.sink_orders (
  id          uuid primary key default gen_random_uuid(),
  order_date  date not null default current_date,         -- 발주일자
  owner       uuid references public.staff(user_id) on delete set null,  -- 담당자(주문자)
  owner_name  text not null default '',
  customer_id uuid references public.customers(id) on delete set null,
  contract_id uuid references public.contracts(id) on delete set null,
  site_name   text not null default '',                   -- 설치업장명 (재고면 '재고')
  due_date    date,                                       -- 입고요청일(입고예정)
  status      text not null default '신규접수'
              check (status in ('신규접수','주문완료','입고완료','출고완료','재고등록','취소')),
  items       jsonb not null default '[]',                -- [{name,opt1,opt2,w,d,h,hole,wheel,qty,note}]
  in_date     date,                                       -- 입고일자
  out_date    date,                                       -- 출고일자
  memo        text not null default '',                   -- 비고
  supplier    text not null default '나인주방',
  created_by  uuid default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists sink_orders_date_idx on public.sink_orders(order_date desc);
create index if not exists sink_orders_owner_idx on public.sink_orders(owner);
drop trigger if exists sink_orders_touch on public.sink_orders;
create trigger sink_orders_touch before update on public.sink_orders for each row execute function public.touch_updated();

-- 담당자는 '신규접수' 상태에서만 고치고, 진행사항은 바꿀 수 없음
create or replace function public.sink_guard() returns trigger language plpgsql as $$
begin
  if public.is_office() then return new; end if;
  if tg_op = 'INSERT' then
    if new.status <> '신규접수' or new.owner is distinct from auth.uid() then raise exception '담당자는 본인 이름으로 신규접수만 할 수 있습니다'; end if;
    new.in_date := null; new.out_date := null; return new;
  end if;
  if old.status <> '신규접수' or new.status <> old.status or new.owner is distinct from old.owner
     or new.in_date is distinct from old.in_date or new.out_date is distinct from old.out_date then
    raise exception '주문이 들어간 발주는 사무실에서만 고칠 수 있습니다';
  end if;
  return new;
end $$;
drop trigger if exists sink_orders_guard on public.sink_orders;
create trigger sink_orders_guard before insert or update on public.sink_orders for each row execute function public.sink_guard();

alter table public.sink_orders enable row level security;
drop policy if exists so_select on public.sink_orders;
drop policy if exists so_insert on public.sink_orders;
drop policy if exists so_update on public.sink_orders;
drop policy if exists so_delete on public.sink_orders;
create policy so_select on public.sink_orders for select to authenticated
  using ((select public.is_office()) or owner = (select auth.uid()));
create policy so_insert on public.sink_orders for insert to authenticated
  with check ((select public.is_office()) or ((select public.my_role()) = 'sales' and owner = (select auth.uid())));
create policy so_update on public.sink_orders for update to authenticated
  using ((select public.is_office()) or (owner = (select auth.uid()) and status = '신규접수'))
  with check ((select public.is_office()) or owner = (select auth.uid()));
create policy so_delete on public.sink_orders for delete to authenticated
  using ((select public.is_office()) or (owner = (select auth.uid()) and status = '신규접수'));
revoke all on public.sink_orders from anon;
grant select, insert, update, delete on public.sink_orders to authenticated;

-- 금액(단가·공제가)은 따로 보관: 사무실·관리자만
create table if not exists public.sink_prices (
  order_id   uuid primary key references public.sink_orders(id) on delete cascade,
  lines      jsonb not null default '[]',                 -- 품목 순서대로 [{price, deduct}]
  updated_at timestamptz not null default now()
);
alter table public.sink_prices enable row level security;
drop policy if exists sp_all on public.sink_prices;
create policy sp_all on public.sink_prices for all to authenticated using ((select public.is_office())) with check ((select public.is_office()));
revoke all on public.sink_prices from anon;
grant select, insert, update, delete on public.sink_prices to authenticated;
