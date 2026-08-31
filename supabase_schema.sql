-- Pathway Build Board — Supabase schema
-- Run this once in your Supabase project: Dashboard -> SQL Editor -> New query -> paste all of this -> Run.

-- 1) Teams table: holds the editable roster + declared meeting cadence per team.
--    Milestone definitions themselves live in the frontend code (they rarely change),
--    only the per-team roster/cadence is stored here.
create table if not exists teams (
  id text primary key,
  name text not null,
  roster_cadence text not null default '',
  roster_members jsonb not null default '[]'::jsonb
);

-- Seed the 6 teams (safe to re-run: does nothing if they already exist)
insert into teams (id, name, roster_cadence, roster_members) values
  ('assimilation-membership', 'Assimilation and Membership', '', '["Josh Yates - Lead","Abbey Valiquette","Bethany McCleaf","Denise Covert"]'::jsonb),
  ('gospel-story', 'Gospel Story', '', '["Tim Beltz - Lead","Jonathan Bonetti","Mark Siverling"]'::jsonb),
  ('knowing-god', 'Knowing God', '', '["Stephen Johnson - Lead","Mark Vowels"]'::jsonb),
  ('communing-with-god', 'Communing with God', '', '["Brandon Swanner - Lead","Orlando Cabrera","Joe O''Neal"]'::jsonb),
  ('life-in-community', 'Life in Community', '', '["Justin Valiquette - Lead","Brandon Capuano","Mark Vowels"]'::jsonb),
  ('life-on-mission', 'Life on Mission', '', '["Kyle Balcerzak - Lead","Sam Jones","Zachary Brunson","Charlie Mitchell"]'::jsonb)
on conflict (id) do nothing;

-- 2) Submissions table: one row per meeting update a team lead posts.
create table if not exists submissions (
  id uuid primary key default gen_random_uuid(),
  team_id text not null references teams(id) on delete cascade,
  leader_name text not null,
  meeting_date date not null,
  submitted_at timestamptz not null default now(),
  summary text not null,
  file_path text,
  file_name text,
  review_requested boolean not null default false,
  reviewed boolean not null default false,
  steps jsonb not null default '{}'::jsonb,
  changes jsonb not null default '[]'::jsonb
);

create index if not exists submissions_team_id_idx on submissions (team_id);

-- 3) Row Level Security.
-- IMPORTANT: this app has no real login system (same soft-PIN approach as before, just
-- for the admin VIEW in the UI). These policies let anyone holding the public "anon" key
-- read and write — that key is embedded in the page's JS, so it is not a secret. This
-- matches the trust model you already had (the data was equally visible in the artifact's
-- page source before). If you later want real protection against a stranger hitting the
-- API directly, add Supabase Auth for yourself and tighten these policies to check
-- auth.uid() — happy to build that when you want it.

alter table teams enable row level security;
alter table submissions enable row level security;

drop policy if exists "teams are readable by anyone" on teams;
create policy "teams are readable by anyone" on teams for select using (true);

drop policy if exists "teams are editable by anyone" on teams;
create policy "teams are editable by anyone" on teams for update using (true);

drop policy if exists "submissions are readable by anyone" on submissions;
create policy "submissions are readable by anyone" on submissions for select using (true);

drop policy if exists "submissions are insertable by anyone" on submissions;
create policy "submissions are insertable by anyone" on submissions for insert with check (true);

drop policy if exists "submissions are updatable by anyone" on submissions;
create policy "submissions are updatable by anyone" on submissions for update using (true);

drop policy if exists "submissions are deletable by anyone" on submissions;
create policy "submissions are deletable by anyone" on submissions for delete using (true);

-- 4) Storage bucket for uploaded documents.
insert into storage.buckets (id, name, public)
values ('documents', 'documents', true)
on conflict (id) do nothing;

drop policy if exists "documents are readable by anyone" on storage.objects;
create policy "documents are readable by anyone" on storage.objects
  for select using (bucket_id = 'documents');

drop policy if exists "documents are uploadable by anyone" on storage.objects;
create policy "documents are uploadable by anyone" on storage.objects
  for insert with check (bucket_id = 'documents');

-- 5) Realtime: let the page subscribe to live changes so every open tab updates itself.
alter publication supabase_realtime add table teams;
alter publication supabase_realtime add table submissions;
