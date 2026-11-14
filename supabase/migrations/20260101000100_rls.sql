-- =============================================================================
-- Staydoct · Row Level Security
-- =============================================================================
-- Principios:
--   1. La emergencia funciona sin cuenta, pero NUNCA lee/escribe tablas
--      sensibles directamente: usa RPC `security definer` con token.
--   2. El catálogo (hospitales, médicos, tratamientos, medicinas) es público
--      de solo lectura para permitir explorar sin registro.
--   3. Citas, pedidos y fórmulas son privados del paciente.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Perfiles
-- -----------------------------------------------------------------------------

alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id and role = 'patient');

-- -----------------------------------------------------------------------------
-- Catálogo público (solo lectura de registros activos)
-- -----------------------------------------------------------------------------

alter table public.hospitals enable row level security;
alter table public.doctors enable row level security;
alter table public.treatments enable row level security;
alter table public.medicines enable row level security;

drop policy if exists hospitals_public_read on public.hospitals;
create policy hospitals_public_read
  on public.hospitals for select
  to anon, authenticated
  using (is_active);

drop policy if exists doctors_public_read on public.doctors;
create policy doctors_public_read
  on public.doctors for select
  to anon, authenticated
  using (is_active);

drop policy if exists treatments_public_read on public.treatments;
create policy treatments_public_read
  on public.treatments for select
  to anon, authenticated
  using (is_active);

drop policy if exists medicines_public_read on public.medicines;
create policy medicines_public_read
  on public.medicines for select
  to anon, authenticated
  using (is_active);

-- -----------------------------------------------------------------------------
-- Citas (el alta y la cancelación pasan por RPC)
-- -----------------------------------------------------------------------------

alter table public.appointments enable row level security;

drop policy if exists appointments_select_own on public.appointments;
create policy appointments_select_own
  on public.appointments for select
  to authenticated
  using (patient_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Pedidos de farmacia
-- -----------------------------------------------------------------------------

alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists orders_select_own on public.orders;
create policy orders_select_own
  on public.orders for select
  to authenticated
  using (patient_id = auth.uid());

drop policy if exists order_items_select_own on public.order_items;
create policy order_items_select_own
  on public.order_items for select
  to authenticated
  using (
    exists (
      select 1
      from public.orders o
      where o.id = order_items.order_id
        and o.patient_id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- Fórmulas médicas
-- -----------------------------------------------------------------------------

alter table public.prescriptions enable row level security;

drop policy if exists prescriptions_select_own on public.prescriptions;
create policy prescriptions_select_own
  on public.prescriptions for select
  to authenticated
  using (patient_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Tablas sensibles: RLS activo y SIN políticas.
-- Solo las funciones `security definer` de la migración RPC pueden tocarlas.
-- -----------------------------------------------------------------------------

alter table public.ambulances enable row level security;
alter table public.emergency_incidents enable row level security;
alter table public.emergency_locations enable row level security;
alter table public.emergency_incident_events enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;

-- Defensa extra: quita permisos directos de tabla para los roles de la API.
revoke all on table public.ambulances from anon, authenticated;
revoke all on table public.emergency_incidents from anon, authenticated;
revoke all on table public.emergency_locations from anon, authenticated;
revoke all on table public.emergency_incident_events from anon, authenticated;
revoke all on table public.ai_conversations from anon, authenticated;
revoke all on table public.ai_messages from anon, authenticated;

revoke all on sequence public.emergency_locations_id_seq from anon, authenticated;
