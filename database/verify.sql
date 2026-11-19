-- Execute ONLY after bootstrap.sql, in the dedicated PartWatch project.
-- Read-only verification. Expect 4 rows, rls_enabled = true,
-- anonymous_select = false, worker_select = true.

select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  has_table_privilege('anon', c.oid, 'SELECT') as anonymous_select,
  has_table_privilege('authenticated', c.oid, 'SELECT') as signed_in_select,
  has_table_privilege('service_role', c.oid, 'SELECT') as worker_select,
  (select count(*) from pg_policies p
   where p.schemaname = 'public' and p.tablename = c.relname) as policy_count
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in ('parts', 'price_history', 'alerts', 'builds')
order by c.relname;

-- Check that the mobile user cannot manipulate server-owned price history/alerts.
select
  has_table_privilege('authenticated', 'public.price_history', 'INSERT') as mobile_can_write_history,
  has_table_privilege('authenticated', 'public.alerts', 'INSERT') as mobile_can_create_alerts,
  has_column_privilege('authenticated', 'public.parts', 'current_price', 'UPDATE')
    as mobile_can_fake_observed_price,
  has_column_privilege('authenticated', 'public.parts', 'target_price', 'UPDATE')
    as mobile_can_change_target_price;
-- Expected: false, false, false, true.
