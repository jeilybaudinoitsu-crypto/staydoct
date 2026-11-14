-- =============================================================================
-- Staydoct · Esquema base
-- =============================================================================
-- Ejecuta las migraciones en orden:
--   20260101000000_schema.sql
--   20260101000100_rls.sql
--   20260101000200_rpc.sql
--   20260101000300_seed.sql
--
-- Arquitectura: Flutter (cliente) → Supabase (Postgres + Auth + RLS + RPC).
-- Las tablas de emergencia NO son accesibles directamente: solo mediante las
-- funciones RPC de `20260101000200_rpc.sql`, protegidas por un token por
-- incidente.
-- =============================================================================

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;

-- -----------------------------------------------------------------------------
-- Utilidades
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Perfiles de pacientes
-- -----------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text not null default '',
  phone text,
  blood_type text,
  allergies text[] not null default '{}',
  chronic_conditions text[] not null default '{}',
  emergency_contact_name text,
  emergency_contact_phone text,
  role text not null default 'patient'
    check (role in ('patient', 'doctor', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Datos clínicos básicos del paciente. RLS: cada usuario solo ve su fila.';

create index if not exists profiles_email_idx on public.profiles (lower(email));

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Crea el perfil automáticamente al registrarse en Supabase Auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, phone)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Hospitales y ambulancias
-- -----------------------------------------------------------------------------

create table if not exists public.hospitals (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  city text,
  phone text,
  emergency_phone text,
  latitude double precision not null,
  longitude double precision not null,
  has_emergency_room boolean not null default true,
  has_ambulance boolean not null default false,
  beds_available integer not null default 0 check (beds_available >= 0),
  trauma_level text,
  services text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists hospitals_active_idx
  on public.hospitals (is_active, city);
create index if not exists hospitals_coordinates_idx
  on public.hospitals (latitude, longitude);

drop trigger if exists hospitals_set_updated_at on public.hospitals;
create trigger hospitals_set_updated_at
  before update on public.hospitals
  for each row execute function public.set_updated_at();

create table if not exists public.ambulances (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.hospitals (id) on delete cascade,
  unit_code text not null unique,
  status text not null default 'available'
    check (status in ('available', 'dispatched', 'maintenance')),
  eta_minutes integer not null default 12 check (eta_minutes >= 0),
  crew_size integer not null default 2 check (crew_size > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ambulances_hospital_status_idx
  on public.ambulances (hospital_id, status, is_active);

drop trigger if exists ambulances_set_updated_at on public.ambulances;
create trigger ambulances_set_updated_at
  before update on public.ambulances
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Catálogo clínico
-- -----------------------------------------------------------------------------

create table if not exists public.doctors (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid references public.hospitals (id) on delete set null,
  full_name text not null,
  specialty text not null default 'Medicina general',
  bio text,
  rating numeric(2, 1) check (rating is null or (rating >= 0 and rating <= 5)),
  consultation_fee numeric(12, 2) not null default 0 check (consultation_fee >= 0),
  avatar_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists doctors_active_specialty_idx
  on public.doctors (is_active, specialty);

drop trigger if exists doctors_set_updated_at on public.doctors;
create trigger doctors_set_updated_at
  before update on public.doctors
  for each row execute function public.set_updated_at();

create table if not exists public.treatments (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid references public.hospitals (id) on delete set null,
  name text not null,
  category text not null default 'treatment'
    check (category in ('surgery', 'treatment', 'diagnostic', 'therapy')),
  description text,
  duration_minutes integer not null default 30 check (duration_minutes > 0),
  price numeric(12, 2) not null default 0 check (price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists treatments_active_category_idx
  on public.treatments (is_active, category);

drop trigger if exists treatments_set_updated_at on public.treatments;
create trigger treatments_set_updated_at
  before update on public.treatments
  for each row execute function public.set_updated_at();

create table if not exists public.medicines (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  generic_name text,
  description text,
  category text not null default 'medicine'
    check (category in ('medicine', 'first_aid', 'equipment', 'wellness')),
  requires_prescription boolean not null default false,
  stock integer not null default 0 check (stock >= 0),
  manufacturer text,
  dosage text,
  price numeric(12, 2) not null default 0 check (price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists medicines_active_category_idx
  on public.medicines (is_active, category);
create index if not exists medicines_name_trgm_idx
  on public.medicines using gin (name extensions.gin_trgm_ops);
create index if not exists medicines_generic_trgm_idx
  on public.medicines using gin (generic_name extensions.gin_trgm_ops);

drop trigger if exists medicines_set_updated_at on public.medicines;
create trigger medicines_set_updated_at
  before update on public.medicines
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Citas, cirugías y tratamientos programados
-- -----------------------------------------------------------------------------

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles (id) on delete cascade,
  doctor_id uuid references public.doctors (id) on delete set null,
  treatment_id uuid references public.treatments (id) on delete set null,
  hospital_id uuid references public.hospitals (id) on delete set null,
  type text not null default 'consultation'
    check (type in ('consultation', 'surgery', 'treatment', 'follow_up')),
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'completed', 'cancelled', 'no_show')),
  scheduled_at timestamptz not null,
  reason text,
  price numeric(12, 2) not null default 0 check (price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint appointments_has_target
    check (doctor_id is not null or treatment_id is not null)
);

create index if not exists appointments_patient_idx
  on public.appointments (patient_id, scheduled_at desc);
create index if not exists appointments_doctor_idx
  on public.appointments (doctor_id, scheduled_at);

-- Un especialista no puede tener dos citas activas en el mismo horario.
create unique index if not exists appointments_unique_doctor_slot_idx
  on public.appointments (doctor_id, scheduled_at)
  where doctor_id is not null and status in ('pending', 'confirmed');

create unique index if not exists appointments_unique_treatment_slot_idx
  on public.appointments (treatment_id, scheduled_at)
  where treatment_id is not null and status in ('pending', 'confirmed');

drop trigger if exists appointments_set_updated_at on public.appointments;
create trigger appointments_set_updated_at
  before update on public.appointments
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Farmacia: pedidos
-- -----------------------------------------------------------------------------

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'preparing', 'shipped', 'delivered', 'cancelled')),
  subtotal numeric(12, 2) not null default 0 check (subtotal >= 0),
  delivery_fee numeric(12, 2) not null default 4900 check (delivery_fee >= 0),
  total numeric(12, 2) not null default 0 check (total >= 0),
  delivery_address text not null,
  payment_method text not null default 'cash'
    check (payment_method in ('cash', 'card', 'transfer')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists orders_patient_idx
  on public.orders (patient_id, created_at desc);

drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at
  before update on public.orders
  for each row execute function public.set_updated_at();

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  medicine_id uuid not null references public.medicines (id) on delete restrict,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  created_at timestamptz not null default now()
);

create index if not exists order_items_order_idx
  on public.order_items (order_id);
create index if not exists order_items_medicine_idx
  on public.order_items (medicine_id);

-- -----------------------------------------------------------------------------
-- Fórmulas médicas (soporte de compra de medicamentos controlados)
-- -----------------------------------------------------------------------------

create table if not exists public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles (id) on delete cascade,
  doctor_id uuid references public.doctors (id) on delete set null,
  medicine_id uuid references public.medicines (id) on delete set null,
  status text not null default 'active'
    check (status in ('active', 'used', 'expired', 'cancelled')),
  notes text,
  issued_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists prescriptions_patient_idx
  on public.prescriptions (patient_id, status);

-- -----------------------------------------------------------------------------
-- Emergencias (acceso exclusivo por RPC con token por incidente)
-- -----------------------------------------------------------------------------

create table if not exists public.emergency_incidents (
  id uuid primary key default gen_random_uuid(),
  access_token_hash text not null,
  device_id text not null,
  reporter_name text,
  reporter_phone text,
  description text not null,
  status text not null default 'created'
    check (status in ('created', 'triaging', 'dispatched', 'en_route', 'on_scene', 'transporting', 'resolved', 'cancelled')),
  severity text not null default 'moderate'
    check (severity in ('low', 'moderate', 'high', 'critical')),
  latitude double precision,
  longitude double precision,
  accuracy_m double precision,
  address text,
  ai_summary text,
  recommendations text[] not null default '{}',
  hospital_id uuid references public.hospitals (id) on delete set null,
  ambulance_id uuid references public.ambulances (id) on delete set null,
  patient_id uuid references public.profiles (id) on delete set null,
  dispatched_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists emergency_incidents_device_idx
  on public.emergency_incidents (device_id, created_at desc);
create index if not exists emergency_incidents_status_idx
  on public.emergency_incidents (status, created_at desc);

drop trigger if exists emergency_incidents_set_updated_at on public.emergency_incidents;
create trigger emergency_incidents_set_updated_at
  before update on public.emergency_incidents
  for each row execute function public.set_updated_at();

create table if not exists public.emergency_locations (
  id bigserial primary key,
  incident_id uuid not null references public.emergency_incidents (id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  accuracy_m double precision,
  address text,
  created_at timestamptz not null default now()
);

create index if not exists emergency_locations_incident_idx
  on public.emergency_locations (incident_id, created_at desc);

create table if not exists public.emergency_incident_events (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.emergency_incidents (id) on delete cascade,
  event_type text not null default 'update',
  message text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists emergency_events_incident_idx
  on public.emergency_incident_events (incident_id, created_at desc);

-- -----------------------------------------------------------------------------
-- Conversaciones de triaje con IA
-- -----------------------------------------------------------------------------

create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.emergency_incidents (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ai_conversations_incident_idx
  on public.ai_conversations (incident_id, created_at desc);

drop trigger if exists ai_conversations_set_updated_at on public.ai_conversations;
create trigger ai_conversations_set_updated_at
  before update on public.ai_conversations
  for each row execute function public.set_updated_at();

create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations (id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists ai_messages_conversation_idx
  on public.ai_messages (conversation_id, created_at);

-- -----------------------------------------------------------------------------
-- Comentarios de documentación
-- -----------------------------------------------------------------------------

comment on table public.emergency_incidents is
  'Incidentes SOS anónimos. `access_token_hash` es SHA-256 del token devuelto una sola vez al dispositivo.';
comment on table public.emergency_locations is
  'Historial GPS del incidente (dato sensible; sin políticas RLS de lectura directa).';
comment on table public.appointments is
  'Citas de consulta, cirugía y tratamiento. La creación/cancelación pasa por RPC.';
comment on table public.orders is
  'Pedidos de farmacia; los precios se congelan en order_items.unit_price.';
