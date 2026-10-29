-- 1단계-zm: 제품 약칭을 정식 이름으로 (1→1채널, 3→3채널, 온→온케어, 대→대광). 두 번 실행해도 괜찮음
update public.contracts set product = case btrim(product) when '1' then '1채널' when '3' then '3채널' when '온' then '온케어' when '대' then '대광' end
 where btrim(product) in ('1','3','온','대');
update public.jobs set product = jsonb_set(product, '{product}', to_jsonb(case btrim(product->>'product') when '1' then '1채널' when '3' then '3채널' when '온' then '온케어' when '대' then '대광' end))
 where jsonb_typeof(product) = 'object' and btrim(product->>'product') in ('1','3','온','대');
