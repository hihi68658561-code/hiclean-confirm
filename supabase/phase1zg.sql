-- 1단계-zg: 재고관리 (초음파세척기·수압식세척기·중고세척기) — phase1zf.sql 다음에 실행
-- 사무실·관리자만 보고 고칠 수 있습니다.

-- 초음파세척기: 제품 1대 = 1줄 (시리얼). 중고도 같은 목록에서 used=true 로 관리
create table if not exists public.stock_units (
  id         uuid primary key default gen_random_uuid(),
  mfg_y      int,                       -- 제조 년(2자리)
  mfg_m      int,
  mfg_d      int,
  model      text not null default '',  -- CL(클린365) / ON(온케어) / AT(올뉴트리플)
  ch         int,                       -- 채널 1/3
  size       int,                       -- 600·700 …
  ty         text not null default '',  -- A(세로700) / B(세로600) / C(세로 특수)
  lip        int,                       -- 유턱 1 / 무턱 0
  drain      text not null default '',  -- R(우) / L(좌)
  no         text not null default '',  -- 일련번호 (계약의 시리얼과 연결)
  serial     text not null default '',  -- 2002-AT307A1R-00101
  in_date    date,                      -- 입고일(재입고면 다시 입고한 날)
  out_date   date,                      -- 직접 출고 처리한 날 (계약과 자동 연결되면 비워 둠)
  site_name  text not null default '',  -- 직접 출고 업장
  customer_id uuid references public.customers(id) on delete set null,
  used       boolean not null default false,  -- 중고
  grade      text not null default '',  -- 중고 등급 A++ · B+ · B …
  remark     text not null default '',
  status     text not null default '',  -- '' 정상 / 불량 / 폐기 (불량·폐기는 재고에서 빠짐)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists stock_units_no_idx on public.stock_units(no);
drop trigger if exists stock_units_touch on public.stock_units;
create trigger stock_units_touch before update on public.stock_units for each row execute function public.touch_updated();

-- 적정 재고 (제품·사이즈·타입별)
create table if not exists public.stock_targets (
  model text not null, size int not null, ty text not null default 'A', qty int not null default 0,
  primary key (model, size, ty)
);

-- 수압식세척기: 입고·재고조정·(계약 없는) 출고. 계약의 수압식 추가 구매는 화면에서 자동으로 출고로 셈
create table if not exists public.wash_moves (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null check (kind in ('입고','조정','출고')),
  move_date  date not null default current_date,
  qty        int not null default 1,     -- 조정은 +/- 가능
  product    text not null default '워시',
  site_name  text not null default '',
  phone      text not null default '',
  address    text not null default '',
  customer_id uuid references public.customers(id) on delete set null,
  memo       text not null default '',
  created_at timestamptz not null default now()
);

alter table public.stock_units   enable row level security;
alter table public.stock_targets enable row level security;
alter table public.wash_moves    enable row level security;
drop policy if exists su_all on public.stock_units;
drop policy if exists st_all on public.stock_targets;
drop policy if exists wm_all on public.wash_moves;
create policy su_all on public.stock_units   for all to authenticated using ((select public.is_office())) with check ((select public.is_office()));
create policy st_all on public.stock_targets for all to authenticated using ((select public.is_office())) with check ((select public.is_office()));
create policy wm_all on public.wash_moves    for all to authenticated using ((select public.is_office())) with check ((select public.is_office()));
revoke all on public.stock_units, public.stock_targets, public.wash_moves from anon;
grant select, insert, update, delete on public.stock_units, public.stock_targets, public.wash_moves to authenticated;
