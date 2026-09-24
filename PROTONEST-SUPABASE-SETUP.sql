-- PROTONEST live-order database setup
-- Run this entire file once in Supabase Dashboard > SQL Editor.

begin;

create extension if not exists pgcrypto;

create or replace function public.current_user_is_protonest_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(lower(auth.jwt() ->> 'email') = 'protonestdesign@gmail.com', false);
$$;

revoke all on function public.current_user_is_protonest_admin() from public;
grant execute on function public.current_user_is_protonest_admin() to authenticated;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  role text not null default 'customer' check (role in ('customer', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, phone, role)
  values (
    new.id,
    new.email,
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'phone', ''),
    case when lower(new.email) = 'protonestdesign@gmail.com' then 'admin' else 'customer' end
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    phone = coalesce(excluded.phone, public.profiles.phone),
    role = excluded.role,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update of email, raw_user_meta_data on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.make_protonest_order_number()
returns text
language sql
volatile
set search_path = public
as $$
  select 'PN-' || to_char(now(), 'YYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
$$;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default public.make_protonest_order_number(),
  customer_id uuid not null references auth.users(id) on delete restrict,
  customer_email text not null,
  customer_name text not null,
  phone text not null,
  service_id text not null,
  service_name text not null,
  description text not null,
  quantity integer not null default 1 check (quantity > 0),
  material text,
  complexity text not null default 'simple' check (complexity in ('simple', 'medium', 'complex')),
  delivery_speed text not null default 'standard' check (delivery_speed in ('standard', 'urgent')),
  delivery_method text not null default 'courier' check (delivery_method in ('courier', 'pickup')),
  shipping_address text not null,
  shipping_city text not null,
  shipping_state text not null,
  shipping_pincode text not null check (shipping_pincode ~ '^[0-9]{6}$'),
  estimate_min numeric(12,2),
  estimate_max numeric(12,2),
  final_amount numeric(12,2) check (final_amount is null or final_amount >= 0),
  status text not null default 'new' check (status in (
    'new', 'under_review', 'quote_approved', 'awaiting_payment', 'paid',
    'in_production', 'quality_check', 'shipped', 'completed', 'cancelled'
  )),
  payment_status text not null default 'not_requested' check (payment_status in ('not_requested', 'pending', 'paid', 'failed', 'refunded')),
  payment_url text,
  file_path text,
  file_name text,
  admin_note text,
  expected_delivery_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists orders_customer_id_idx on public.orders(customer_id);
create index if not exists orders_status_idx on public.orders(status);
create index if not exists orders_created_at_idx on public.orders(created_at desc);

create table if not exists public.order_status_history (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  note text,
  changed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists order_status_history_order_idx on public.order_status_history(order_id, created_at);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists orders_touch_updated_at on public.orders;
create trigger orders_touch_updated_at before update on public.orders
for each row execute procedure public.touch_updated_at();

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at before update on public.profiles
for each row execute procedure public.touch_updated_at();

create or replace function public.record_order_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.order_status_history (order_id, status, note, changed_by)
    values (new.id, new.status, new.admin_note, auth.uid());
  elsif new.status is distinct from old.status or new.admin_note is distinct from old.admin_note then
    insert into public.order_status_history (order_id, status, note, changed_by)
    values (new.id, new.status, new.admin_note, auth.uid());
  end if;
  return new;
end;
$$;

drop trigger if exists orders_record_status on public.orders;
create trigger orders_record_status
  after insert or update of status, admin_note on public.orders
  for each row execute procedure public.record_order_status();

alter table public.profiles enable row level security;
alter table public.orders enable row level security;
alter table public.order_status_history enable row level security;

drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin" on public.profiles
for select to authenticated
using (id = auth.uid() or public.current_user_is_protonest_admin());

drop policy if exists "profiles_update_own_or_admin" on public.profiles;
create policy "profiles_update_own_or_admin" on public.profiles
for update to authenticated
using (
  (id = auth.uid() and role = 'customer')
  or public.current_user_is_protonest_admin()
)
with check (
  (id = auth.uid() and role = 'customer')
  or public.current_user_is_protonest_admin()
);

drop policy if exists "orders_insert_own" on public.orders;
create policy "orders_insert_own" on public.orders
for insert to authenticated
with check (
  customer_id = auth.uid()
  and lower(customer_email) = lower(auth.jwt() ->> 'email')
);

drop policy if exists "orders_select_own_or_admin" on public.orders;
create policy "orders_select_own_or_admin" on public.orders
for select to authenticated
using (customer_id = auth.uid() or public.current_user_is_protonest_admin());

drop policy if exists "orders_admin_update" on public.orders;
create policy "orders_admin_update" on public.orders
for update to authenticated
using (public.current_user_is_protonest_admin())
with check (public.current_user_is_protonest_admin());

drop policy if exists "history_select_own_or_admin" on public.order_status_history;
create policy "history_select_own_or_admin" on public.order_status_history
for select to authenticated
using (
  public.current_user_is_protonest_admin()
  or exists (
    select 1 from public.orders
    where public.orders.id = order_status_history.order_id
      and public.orders.customer_id = auth.uid()
  )
);

grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update on public.orders to authenticated;
grant select on public.order_status_history to authenticated;

insert into storage.buckets (id, name, public, file_size_limit)
values ('order-files', 'order-files', false, 10485760)
on conflict (id) do update set public = false, file_size_limit = 10485760;

drop policy if exists "customers_upload_own_order_files" on storage.objects;
create policy "customers_upload_own_order_files" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'order-files'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "customers_read_own_order_files" on storage.objects;
create policy "customers_read_own_order_files" on storage.objects
for select to authenticated
using (
  bucket_id = 'order-files'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.current_user_is_protonest_admin()
  )
);

drop policy if exists "customers_delete_own_order_files" on storage.objects;
create policy "customers_delete_own_order_files" on storage.objects
for delete to authenticated
using (
  bucket_id = 'order-files'
  and (storage.foldername(name))[1] = auth.uid()::text
);

do $$
begin
  alter publication supabase_realtime add table public.orders;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.order_status_history;
exception when duplicate_object then null;
end $$;

commit;

-- After this script succeeds:
-- 1. Create/sign up the admin user with protonestdesign@gmail.com.
-- 2. Keep Secret/service_role keys private. The website uses only the publishable key.
