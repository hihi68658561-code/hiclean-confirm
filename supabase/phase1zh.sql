-- 1단계-zh: 싱크대 단가표 (phase1zg.sql 다음에 실행)
-- 품명·옵션·가로(W) 기준 단가와 공제가. 발주 금액에 자동으로 들어갑니다. 사무실·관리자만 보고 고칩니다.
create table if not exists public.sink_price_list (
  id         uuid primary key default gen_random_uuid(),
  name       text not null default '',      -- 품명 (예: 01. 싱크대 / 왕대)
  opt1       text not null default '',      -- 옵션1 (비우면 모두)
  opt2       text not null default '',      -- 옵션2 (비우면 모두)
  w_max      integer,                       -- W(가로) 이하 (비우면 모든 크기)
  d          integer,                       -- D(깊이) (비우면 모두)
  price      integer not null default 0,    -- 단가
  deduct     integer not null default 0,    -- 공제가
  memo       text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
drop trigger if exists sink_price_list_touch on public.sink_price_list;
create trigger sink_price_list_touch before update on public.sink_price_list for each row execute function public.touch_updated();
alter table public.sink_price_list enable row level security;
drop policy if exists spl_all on public.sink_price_list;
create policy spl_all on public.sink_price_list for all to authenticated using ((select public.is_office())) with check ((select public.is_office()));
revoke all on public.sink_price_list from anon;
grant select, insert, update, delete on public.sink_price_list to authenticated;
