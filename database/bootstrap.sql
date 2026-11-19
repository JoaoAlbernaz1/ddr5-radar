-- PartWatch initial database (run ONCE on a NEW, dedicated Supabase project).
-- Do not run this on the UniMove project. No data or users are seeded.
-- The current Flutter application still uses local SharedPreferences;
-- this schema alone does not connect the app to Supabase.
-- This script intentionally fails if the target tables already exist,
-- rather than silently masking incompatible database schemas.

begin;

create table public.parts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default (auth.uid())
    references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 250),
  category text not null check (char_length(btrim(category)) between 1 and 80),
  store text not null check (char_length(btrim(store)) between 1 and 120),
  current_price numeric(12, 2) not null check (current_price > 0),
  target_price numeric(12, 2) not null check (target_price >= 0),
  notify_on_drop boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create table public.price_history (
  id uuid primary key default gen_random_uuid(),
  part_id uuid not null references public.parts(id) on delete cascade,
  price numeric(12, 2) not null check (price > 0),
  created_at timestamptz not null default now()
);

create table public.alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  part_id uuid not null,
  message text not null check (char_length(btrim(message)) between 1 and 1000),
  created_at timestamptz not null default now(),
  foreign key (part_id, user_id)
    references public.parts(id, user_id) on delete cascade
);

-- Current Flutter 'BuildConfig' is a summary, not a part-level bill of materials.
create table public.builds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default (auth.uid())
    references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 150),
  price numeric(12, 2) not null default 0 check (price >= 0),
  pieces integer not null default 0 check (pieces >= 0),
  has_compatibility_warning boolean not null default false,
  created_at timestamptz not null default now()
);

create index parts_user_id_idx on public.parts(user_id);
create index price_history_part_created_idx
  on public.price_history(part_id, created_at desc);
create index alerts_user_created_idx
  on public.alerts(user_id, created_at desc);
create index builds_user_id_idx on public.builds(user_id);

-- All exposed tables require row level security.
alter table public.parts enable row level security;
alter table public.price_history enable row level security;
alter table public.alerts enable row level security;
alter table public.builds enable row level security;

-- No anonymous access, including on installations with permissive defaults.
revoke all on public.parts, public.price_history, public.alerts, public.builds
  from anon, authenticated;

-- Authenticated users can manage only their own watches and build summaries.
-- The worker (service role) is responsible for updating observed prices.
grant select, insert, delete on public.parts to authenticated;
grant update (name, category, store, target_price, notify_on_drop)
  on public.parts to authenticated;
grant select on public.price_history to authenticated;
grant select on public.alerts to authenticated;
grant select, insert, update, delete on public.builds to authenticated;

create policy "partwatch_parts_select_own" on public.parts
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "partwatch_parts_insert_own" on public.parts
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "partwatch_parts_update_own" on public.parts
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "partwatch_parts_delete_own" on public.parts
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- History and alerts are server-written, user-readable.
create policy "partwatch_history_select_own" on public.price_history
  for select to authenticated
  using (exists (
    select 1 from public.parts p
    where p.id = price_history.part_id
      and p.user_id = (select auth.uid())
  ));

create policy "partwatch_alerts_select_own" on public.alerts
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "partwatch_builds_select_own" on public.builds
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "partwatch_builds_insert_own" on public.builds
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "partwatch_builds_update_own" on public.builds
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "partwatch_builds_delete_own" on public.builds
  for delete to authenticated
  using ((select auth.uid()) = user_id);

commit;
