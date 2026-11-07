-- Stable user-defined ordering of product formats.
alter table public.product_formats add column if not exists sort_order integer not null default 0;
with ranked as (
 select id,row_number() over(partition by product_id order by created_at,id)-1 as rn
 from public.product_formats
)
update public.product_formats f set sort_order=ranked.rn from ranked where ranked.id=f.id;
