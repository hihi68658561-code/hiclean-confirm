-- 1단계-p: 입금 내역 수단 '입금'을 '현금'으로 합침
update public.payments set method = '현금' where method = '입금';
