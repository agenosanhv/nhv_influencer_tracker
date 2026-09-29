-- =====================================================================
-- Campaign Tracker: Supabase setup
-- Paste this whole file into Supabase > SQL Editor and click "Run".
-- It creates the tables, the roles (admin / employee / viewer) and the
-- security rules that enforce them on the server.
-- =====================================================================

-- ---------- Profiles: one row per person, holds their role ----------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  full_name  text,
  role       text not null default 'viewer' check (role in ('admin','employee','viewer')),
  hide_name  boolean not null default false,   -- true = never show this person's name on edits
  created_at timestamptz not null default now()
);

-- Create a profile automatically when someone is invited / signs up.
-- Everyone starts as a viewer; an admin promotes them.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helper: the signed-in person's role (used by the rules below)
create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

-- Anyone signed in can set their own display name (but not their role).
create or replace function public.set_my_name(new_name text)
returns void language sql security definer set search_path = public as $$
  update public.profiles set full_name = left(trim(new_name), 80) where id = auth.uid()
$$;
revoke all on function public.set_my_name(text) from public, anon;
grant execute on function public.set_my_name(text) to authenticated;

-- ---------- Campaigns ----------
create table if not exists public.campaigns (
  id          uuid primary key default gen_random_uuid(),
  influencer  text not null,
  asset       text default '',
  channel     text default '',
  status      text not null default 'Not Started'
              check (status in ('Not Started','In Progress','Live','Done')),
  start_date  date,
  end_date    date,
  notes       text default '',
  created_by  uuid references public.profiles(id) on delete set null,
  updated_by  uuid references public.profiles(id) on delete set null,
  updated_at  timestamptz not null default now(),
  constraint dates_in_order check (end_date is null or start_date is null or end_date >= start_date)
);

-- The server stamps who edited and when, so nobody can fake it.
create or replace function public.stamp_campaign()
returns trigger language plpgsql as $$
begin
  new.updated_by := auth.uid();
  new.updated_at := now();
  if tg_op = 'INSERT' then new.created_by := auth.uid(); end if;
  if tg_op = 'UPDATE' then new.created_by := old.created_by; end if;
  return new;
end $$;

drop trigger if exists campaigns_stamp on public.campaigns;
create trigger campaigns_stamp
  before insert or update on public.campaigns
  for each row execute function public.stamp_campaign();

-- ---------- Security rules (Row Level Security) ----------
alter table public.profiles  enable row level security;
alter table public.campaigns enable row level security;

-- Profiles: every signed-in person can see the team list.
drop policy if exists "profiles readable by team" on public.profiles;
create policy "profiles readable by team" on public.profiles
  for select to authenticated using (true);

-- Only admins can change roles / profile settings.
drop policy if exists "admins update profiles" on public.profiles;
create policy "admins update profiles" on public.profiles
  for update to authenticated
  using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

-- Campaigns: everyone signed in can view.
drop policy if exists "team reads campaigns" on public.campaigns;
create policy "team reads campaigns" on public.campaigns
  for select to authenticated using (true);

-- Admins and employees can add and edit.
drop policy if exists "staff add campaigns" on public.campaigns;
create policy "staff add campaigns" on public.campaigns
  for insert to authenticated with check (public.my_role() in ('admin','employee'));

drop policy if exists "staff edit campaigns" on public.campaigns;
create policy "staff edit campaigns" on public.campaigns
  for update to authenticated
  using (public.my_role() in ('admin','employee'))
  with check (public.my_role() in ('admin','employee'));

-- Only admins can delete.
drop policy if exists "admins delete campaigns" on public.campaigns;
create policy "admins delete campaigns" on public.campaigns
  for delete to authenticated using (public.my_role() = 'admin');

-- ---------- Live updates (everyone sees changes instantly) ----------
do $$ begin
  alter publication supabase_realtime add table public.campaigns;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then null; end $$;

-- =====================================================================
-- AFTER your team has been invited and has set their passwords:
--
-- 1) Make Adrian the admin (use his real email):
--      update public.profiles set role = 'admin' where email = 'adrian@yourcompany.com';
--
-- 2) Hide your own name on edits (use your email):
--      update public.profiles set hide_name = true where email = 'you@yourcompany.com';
--
-- 3) Optional sample data, so the board isn't empty:
--      insert into public.campaigns (influencer, asset, channel, status, start_date, end_date, notes) values
--      ('Maya Chen','Fall recipe reel','Meta','Done','2026-09-15','2026-09-22','Strong saves, repurpose for ads'),
--      ('Dev Patel','30-day challenge video','TikTok','Live','2026-09-21','2026-10-05','Trending sound approved'),
--      ('Lena Ortiz','Product review','YouTube','In Progress','2026-10-05','2026-10-19','Rough cut due Oct 1'),
--      ('Sam Rivera','Autumn lookbook carousel','Instagram','In Progress','2026-10-01','2026-10-08','Captions in review'),
--      ('Ava Brooks','Holiday decor pins','Pinterest','Not Started','2026-10-26','2026-11-09','');
-- =====================================================================
