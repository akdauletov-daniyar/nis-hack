create extension if not exists pgcrypto;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null check (type in ('emergency', 'government', 'admin')),
  districts text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null default '',
  full_name text not null default '',
  phone text not null default '',
  district text not null default 'Alatau Central',
  mobility_type text not null default 'general',
  avoid_stairs boolean not null default true,
  avoid_steep_slopes boolean not null default true,
  avoid_broken_elevators boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists email text default '';

alter table public.profiles
  add column if not exists full_name text default '';

alter table public.profiles
  add column if not exists phone text default '';

alter table public.profiles
  add column if not exists district text default 'Alatau Central';

alter table public.profiles
  add column if not exists mobility_type text default 'general';

alter table public.profiles
  add column if not exists avoid_stairs boolean default true;

alter table public.profiles
  add column if not exists avoid_steep_slopes boolean default true;

alter table public.profiles
  add column if not exists avoid_broken_elevators boolean default true;

update public.profiles
set
  email = coalesce(email, ''),
  full_name = coalesce(full_name, ''),
  phone = coalesce(phone, ''),
  district = coalesce(district, 'Alatau Central'),
  mobility_type = coalesce(mobility_type, 'general'),
  avoid_stairs = coalesce(avoid_stairs, true),
  avoid_steep_slopes = coalesce(avoid_steep_slopes, true),
  avoid_broken_elevators = coalesce(avoid_broken_elevators, true)
where
  email is null
  or full_name is null
  or phone is null
  or district is null
  or mobility_type is null
  or avoid_stairs is null
  or avoid_steep_slopes is null
  or avoid_broken_elevators is null;

alter table public.profiles
  alter column email set default '',
  alter column email set not null,
  alter column full_name set default '',
  alter column full_name set not null,
  alter column phone set default '',
  alter column phone set not null,
  alter column district set default 'Alatau Central',
  alter column district set not null,
  alter column mobility_type set default 'general',
  alter column mobility_type set not null,
  alter column avoid_stairs set default true,
  alter column avoid_stairs set not null,
  alter column avoid_steep_slopes set default true,
  alter column avoid_steep_slopes set not null,
  alter column avoid_broken_elevators set default true,
  alter column avoid_broken_elevators set not null;

create table if not exists public.role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('resident', 'emergency_service', 'government', 'admin')),
  organization_id uuid references public.organizations(id) on delete set null,
  active boolean not null default true,
  granted_by uuid references public.profiles(id) on delete set null,
  granted_at timestamptz not null default now(),
  unique (user_id, role)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.role_assignments'::regclass
      and conname = 'role_assignments_user_id_role_key'
  ) then
    alter table public.role_assignments
      add constraint role_assignments_user_id_role_key unique (user_id, role);
  end if;
end;
$$;

create table if not exists public.saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references public.profiles(id) on delete cascade,
  reporter_name text not null,
  reporter_phone text not null default '',
  title text not null,
  category text not null,
  description text not null,
  status text not null check (
    status in (
      'draft',
      'submitted',
      'under_review',
      'validated',
      'assigned',
      'in_progress',
      'resolved',
      'closed',
      'rejected',
      'duplicate',
      'spam'
    )
  ) default 'submitted',
  urgency text not null check (urgency in ('low', 'medium', 'high', 'critical')),
  district text not null default 'Alatau Central',
  location_text text not null default '',
  latitude double precision,
  longitude double precision,
  accessibility_related boolean not null default false,
  assigned_organization_id uuid references public.organizations(id) on delete set null,
  photo_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.incidents (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.reports(id) on delete set null,
  created_by_user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  status text not null check (
    status in ('new', 'assigned', 'crew_en_route', 'on_site', 'resolved', 'transferred', 'closed')
  ) default 'new',
  urgency text not null check (urgency in ('low', 'medium', 'high', 'critical')),
  district text not null default 'Alatau Central',
  reporter_name text not null,
  reporter_phone text not null default '',
  assigned_organization_id uuid references public.organizations(id) on delete set null,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  author_user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  severity text not null default 'Notice',
  district text not null default 'Alatau Central',
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

insert into public.organizations (id, name, type, districts)
values
  ('11111111-1111-4111-8111-111111111111', 'Alatau EMS', 'emergency', array['Alatau Central', 'North Station']),
  ('22222222-2222-4222-8222-222222222222', 'Fire Response Unit', 'emergency', array['Alatau Central', 'East River']),
  ('33333333-3333-4333-8333-333333333333', 'Akimat Infrastructure Desk', 'government', array['Alatau Central', 'North Station', 'East River', 'South Garden']),
  ('44444444-4444-4444-8444-444444444444', 'Platform Administration', 'admin', array['All'])
on conflict (id) do update
set
  name = excluded.name,
  type = excluded.type,
  districts = excluded.districts;

insert into public.profiles (
  id,
  email,
  full_name,
  phone,
  district,
  mobility_type
)
select
  users.id,
  coalesce(users.email, ''),
  coalesce(users.raw_user_meta_data->>'full_name', ''),
  coalesce(users.raw_user_meta_data->>'phone', ''),
  coalesce(users.raw_user_meta_data->>'district', 'Alatau Central'),
  coalesce(users.raw_user_meta_data->>'mobility_type', 'general')
from auth.users as users
on conflict (id) do update
set
  email = excluded.email,
  full_name = excluded.full_name,
  phone = excluded.phone,
  district = excluded.district,
  mobility_type = excluded.mobility_type;

insert into public.role_assignments (user_id, role, active)
select profiles.id, 'resident', true
from public.profiles as profiles
on conflict (user_id, role) do nothing;

create or replace function public.current_user_has_role(target_role text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.role_assignments
    where user_id = auth.uid()
      and role = target_role
      and active = true
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    full_name,
    phone,
    district,
    mobility_type
  )
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'district', 'Alatau Central'),
    coalesce(new.raw_user_meta_data->>'mobility_type', 'general')
  )
  on conflict (id) do update
  set
    email = excluded.email,
    full_name = excluded.full_name,
    phone = excluded.phone,
    district = excluded.district,
    mobility_type = excluded.mobility_type;

  insert into public.role_assignments (user_id, role, active)
  values (new.id, 'resident', true)
  on conflict (user_id, role) do nothing;

  if not exists (
    select 1
    from public.role_assignments
    where role = 'admin'
      and active = true
  ) then
    insert into public.role_assignments (user_id, role, organization_id, active)
    values
      (new.id, 'admin', '44444444-4444-4444-8444-444444444444', true),
      (new.id, 'government', '33333333-3333-4333-8333-333333333333', true),
      (new.id, 'emergency_service', '11111111-1111-4111-8111-111111111111', true)
    on conflict (user_id, role) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.role_assignments enable row level security;
alter table public.saved_places enable row level security;
alter table public.reports enable row level security;
alter table public.incidents enable row level security;
alter table public.announcements enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "organizations read" on public.organizations;
create policy "organizations read"
on public.organizations for select
to authenticated
using (true);

drop policy if exists "organizations admin write" on public.organizations;
create policy "organizations admin write"
on public.organizations for all
to authenticated
using (public.current_user_has_role('admin'))
with check (public.current_user_has_role('admin'));

drop policy if exists "profiles self read or admin" on public.profiles;
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
drop policy if exists "Users can insert their own profile." on public.profiles;
drop policy if exists "Users can update own profile." on public.profiles;
create policy "profiles self read or admin"
on public.profiles for select
to authenticated
using (id = auth.uid() or public.current_user_has_role('admin'));

drop policy if exists "profiles self insert or admin" on public.profiles;
create policy "profiles self insert or admin"
on public.profiles for insert
to authenticated
with check (id = auth.uid() or public.current_user_has_role('admin'));

drop policy if exists "profiles self update or admin" on public.profiles;
create policy "profiles self update or admin"
on public.profiles for update
to authenticated
using (id = auth.uid() or public.current_user_has_role('admin'))
with check (id = auth.uid() or public.current_user_has_role('admin'));

drop policy if exists "role assignments self read or admin" on public.role_assignments;
create policy "role assignments self read or admin"
on public.role_assignments for select
to authenticated
using (user_id = auth.uid() or public.current_user_has_role('admin'));

drop policy if exists "role assignments self resident insert" on public.role_assignments;
create policy "role assignments self resident insert"
on public.role_assignments for insert
to authenticated
with check (
  (user_id = auth.uid() and role = 'resident')
  or public.current_user_has_role('admin')
);

drop policy if exists "role assignments admin update" on public.role_assignments;
create policy "role assignments admin update"
on public.role_assignments for update
to authenticated
using (public.current_user_has_role('admin'))
with check (public.current_user_has_role('admin'));

drop policy if exists "role assignments admin delete" on public.role_assignments;
create policy "role assignments admin delete"
on public.role_assignments for delete
to authenticated
using (public.current_user_has_role('admin'));

drop policy if exists "saved places self read or admin" on public.saved_places;
create policy "saved places self read or admin"
on public.saved_places for select
to authenticated
using (user_id = auth.uid() or public.current_user_has_role('admin'));

drop policy if exists "saved places self write or admin" on public.saved_places;
create policy "saved places self write or admin"
on public.saved_places for all
to authenticated
using (user_id = auth.uid() or public.current_user_has_role('admin'))
with check (user_id = auth.uid() or public.current_user_has_role('admin'));

drop policy if exists "reports authenticated read" on public.reports;
create policy "reports authenticated read"
on public.reports for select
to authenticated
using (true);

drop policy if exists "reports authenticated create" on public.reports;
create policy "reports authenticated create"
on public.reports for insert
to authenticated
with check (reporter_user_id = auth.uid());

drop policy if exists "reports elevated update" on public.reports;
create policy "reports elevated update"
on public.reports for update
to authenticated
using (
  reporter_user_id = auth.uid()
  or public.current_user_has_role('government')
  or public.current_user_has_role('emergency_service')
  or public.current_user_has_role('admin')
)
with check (
  reporter_user_id = auth.uid()
  or public.current_user_has_role('government')
  or public.current_user_has_role('emergency_service')
  or public.current_user_has_role('admin')
);

drop policy if exists "incidents authenticated read" on public.incidents;
create policy "incidents authenticated read"
on public.incidents for select
to authenticated
using (true);

drop policy if exists "incidents authenticated create" on public.incidents;
create policy "incidents authenticated create"
on public.incidents for insert
to authenticated
with check (
  created_by_user_id = auth.uid()
  or public.current_user_has_role('government')
  or public.current_user_has_role('emergency_service')
  or public.current_user_has_role('admin')
);

drop policy if exists "incidents elevated update" on public.incidents;
create policy "incidents elevated update"
on public.incidents for update
to authenticated
using (
  public.current_user_has_role('government')
  or public.current_user_has_role('emergency_service')
  or public.current_user_has_role('admin')
)
with check (
  public.current_user_has_role('government')
  or public.current_user_has_role('emergency_service')
  or public.current_user_has_role('admin')
);

drop policy if exists "announcements authenticated read" on public.announcements;
create policy "announcements authenticated read"
on public.announcements for select
to authenticated
using (true);

drop policy if exists "announcements elevated write" on public.announcements;
create policy "announcements elevated write"
on public.announcements for insert
to authenticated
with check (
  author_user_id = auth.uid()
  and (
    public.current_user_has_role('government')
    or public.current_user_has_role('emergency_service')
    or public.current_user_has_role('admin')
  )
);

drop policy if exists "notifications own read" on public.notifications;
create policy "notifications own read"
on public.notifications for select
to authenticated
using (user_id = auth.uid() or public.current_user_has_role('admin'));

drop policy if exists "notifications own or elevated create" on public.notifications;
create policy "notifications own or elevated create"
on public.notifications for insert
to authenticated
with check (
  user_id = auth.uid()
  or public.current_user_has_role('government')
  or public.current_user_has_role('emergency_service')
  or public.current_user_has_role('admin')
);

drop policy if exists "notifications own update" on public.notifications;
create policy "notifications own update"
on public.notifications for update
to authenticated
using (user_id = auth.uid() or public.current_user_has_role('admin'))
with check (user_id = auth.uid() or public.current_user_has_role('admin'));
