-- 1단계-q: A/S 관리 (엑셀 A/S 관리대장 양식의 칸 추가)
-- 조치내용·출장비·부품비·거리·만족도·세금계산서 발행일. 교체부품은 기존 parts 칸, 제품·규격·시리얼·설치일은 product 칸을 씁니다.
alter table public.jobs add column if not exists action       text   not null default '';  -- 조치내용 (방문조치 등)
alter table public.jobs add column if not exists trip_fee     bigint not null default 0;   -- 출장비
alter table public.jobs add column if not exists part_fee     bigint not null default 0;   -- 부품비
alter table public.jobs add column if not exists distance     integer;                     -- 거리(km)
alter table public.jobs add column if not exists satisfaction text   not null default '';  -- 만족도 (상·중·하)
alter table public.jobs add column if not exists tax_date     date;                        -- 세금계산서 발행일자
create index if not exists jobs_kind_req_idx on public.jobs(kind, request_date);
