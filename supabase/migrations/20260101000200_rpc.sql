-- =============================================================================
-- Staydoct · RPC
-- =============================================================================
-- Contratos consumidos por Flutter:
--   create_emergency            → {incident, access_token, conversation_id}
--   get_emergency_status        → {incident, hospital, ambulance, events}
--   append_emergency_location   → {ok}
--   dispatch_emergency          → {incident, hospital, ambulance, events}
--   log_ai_message              → {message}
--   cancel_emergency            → {ok, status}
--   nearby_hospitals            → setof hospital rows
--   book_appointment            → {appointment}
--   cancel_appointment          → {ok}
--   place_order                 → {order, items}
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Helpers internos (no expuestos a la API)
-- -----------------------------------------------------------------------------

create or replace function public._distance_km(
  lat1 double precision,
  lng1 double precision,
  lat2 double precision,
  lng2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371.0 * 2.0 * asin(
    sqrt(
      least(
        1.0,
        power(sin(radians(lat2 - lat1) / 2.0), 2)
        + cos(radians(lat1)) * cos(radians(lat2))
          * power(sin(radians(lng2 - lng1) / 2.0), 2)
      )
    )
  );
$$;

create or replace function public._assert_emergency_access(
  p_incident_id uuid,
  p_access_token text
)
returns public.emergency_incidents
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_incident public.emergency_incidents;
begin
  select *
    into v_incident
    from public.emergency_incidents
   where id = p_incident_id;

  if not found then
    raise exception 'invalid emergency token';
  end if;

  if v_incident.access_token_hash is distinct from
     encode(digest(coalesce(p_access_token, ''), 'sha256'), 'hex') then
    raise exception 'invalid emergency token';
  end if;

  return v_incident;
end;
$$;

-- -----------------------------------------------------------------------------
-- Emergencias
-- -----------------------------------------------------------------------------

create or replace function public.create_emergency(
  p_description text,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_m double precision,
  p_address text,
  p_device_id text,
  p_reporter_name text,
  p_reporter_phone text,
  p_severity text default 'moderate'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token text;
  v_incident_id uuid;
  v_conversation_id uuid;
  v_payload jsonb;
begin
  if coalesce(trim(p_description), '') = '' then
    raise exception 'description required';
  end if;

  if coalesce(trim(p_device_id), '') = '' then
    raise exception 'device id required';
  end if;

  if p_severity is null
     or p_severity not in ('low', 'moderate', 'high', 'critical') then
    raise exception 'invalid severity';
  end if;

  -- Token de 256 bits: se guarda solo su hash y se devuelve una única vez.
  v_token := encode(gen_random_bytes(32), 'hex');

  insert into public.emergency_incidents (
    access_token_hash,
    device_id,
    reporter_name,
    reporter_phone,
    description,
    status,
    severity,
    latitude,
    longitude,
    accuracy_m,
    address,
    patient_id
  )
  values (
    encode(digest(v_token, 'sha256'), 'hex'),
    trim(p_device_id),
    nullif(trim(coalesce(p_reporter_name, '')), ''),
    nullif(trim(coalesce(p_reporter_phone, '')), ''),
    trim(p_description),
    'created',
    p_severity,
    p_latitude,
    p_longitude,
    p_accuracy_m,
    nullif(trim(coalesce(p_address, '')), ''),
    auth.uid()
  )
  returning id into v_incident_id;

  if p_latitude is not null and p_longitude is not null then
    insert into public.emergency_locations (
      incident_id, latitude, longitude, accuracy_m, address
    )
    values (
      v_incident_id,
      p_latitude,
      p_longitude,
      p_accuracy_m,
      nullif(trim(coalesce(p_address, '')), '')
    );
  end if;

  insert into public.ai_conversations (incident_id, user_id)
  values (v_incident_id, auth.uid())
  returning id into v_conversation_id;

  insert into public.emergency_incident_events (
    incident_id, event_type, message
  )
  values (
    v_incident_id,
    'created',
    'Reporte de emergencia creado desde la app. Iniciando triaje con Vera.'
  );

  select jsonb_build_object(
    'incident', jsonb_build_object(
      'id', i.id,
      'access_token', v_token,
      'description', i.description,
      'status', i.status,
      'severity', i.severity,
      'lat', i.latitude,
      'lng', i.longitude,
      'accuracy_m', i.accuracy_m,
      'address', i.address,
      'reporter_name', i.reporter_name,
      'reporter_phone', i.reporter_phone,
      'ai_summary', i.ai_summary,
      'recommendations', to_jsonb(i.recommendations),
      'created_at', i.created_at,
      'dispatched_at', i.dispatched_at,
      'resolved_at', i.resolved_at
    ),
    'access_token', v_token,
    'conversation_id', v_conversation_id
  )
  into v_payload
  from public.emergency_incidents i
  where i.id = v_incident_id;

  return v_payload;
end;
$$;

create or replace function public.get_emergency_status(
  p_incident_id uuid,
  p_access_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_incident public.emergency_incidents;
  v_hospital jsonb;
  v_ambulance jsonb;
  v_events jsonb;
begin
  v_incident := public._assert_emergency_access(p_incident_id, p_access_token);

  if v_incident.hospital_id is not null then
    select jsonb_build_object(
      'id', h.id,
      'name', h.name,
      'phone', coalesce(h.phone, h.emergency_phone),
      'address', h.address,
      'lat', h.latitude,
      'lng', h.longitude,
      'has_emergency_room', h.has_emergency_room,
      'beds_available', h.beds_available,
      'distance_km', case
        when v_incident.latitude is not null and v_incident.longitude is not null
        then round(
          public._distance_km(
            v_incident.latitude,
            v_incident.longitude,
            h.latitude,
            h.longitude
          )::numeric,
          2
        )::double precision
        else null
      end
    )
    into v_hospital
    from public.hospitals h
    where h.id = v_incident.hospital_id;
  end if;

  if v_incident.ambulance_id is not null then
    select jsonb_build_object(
      'id', a.id,
      'unit_code', a.unit_code,
      'status', a.status,
      'eta_minutes', a.eta_minutes
    )
    into v_ambulance
    from public.ambulances a
    where a.id = v_incident.ambulance_id;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', e.id,
        'event_type', e.event_type,
        'message', e.message,
        'created_at', e.created_at
      )
      order by e.created_at desc
    ),
    '[]'::jsonb
  )
  into v_events
  from public.emergency_incident_events e
  where e.incident_id = p_incident_id;

  return jsonb_build_object(
    'incident', jsonb_build_object(
      'id', v_incident.id,
      'description', v_incident.description,
      'status', v_incident.status,
      'severity', v_incident.severity,
      'lat', v_incident.latitude,
      'lng', v_incident.longitude,
      'accuracy_m', v_incident.accuracy_m,
      'address', v_incident.address,
      'reporter_name', v_incident.reporter_name,
      'reporter_phone', v_incident.reporter_phone,
      'ai_summary', v_incident.ai_summary,
      'recommendations', to_jsonb(v_incident.recommendations),
      'created_at', v_incident.created_at,
      'dispatched_at', v_incident.dispatched_at,
      'resolved_at', v_incident.resolved_at,
      'hospital', v_hospital,
      'ambulance', v_ambulance
    ),
    'hospital', v_hospital,
    'ambulance', v_ambulance,
    'events', v_events
  );
end;
$$;

create or replace function public.append_emergency_location(
  p_incident_id uuid,
  p_access_token text,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_m double precision,
  p_address text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_incident public.emergency_incidents;
begin
  v_incident := public._assert_emergency_access(p_incident_id, p_access_token);

  if v_incident.status in ('resolved', 'cancelled') then
    raise exception 'incident closed';
  end if;

  if p_latitude is null or p_longitude is null then
    raise exception 'location required';
  end if;

  insert into public.emergency_locations (
    incident_id, latitude, longitude, accuracy_m, address
  )
  values (
    p_incident_id,
    p_latitude,
    p_longitude,
    p_accuracy_m,
    nullif(trim(coalesce(p_address, '')), '')
  );

  update public.emergency_incidents
     set latitude = p_latitude,
         longitude = p_longitude,
         accuracy_m = p_accuracy_m,
         address = coalesce(
           nullif(trim(coalesce(p_address, '')), ''),
           address
         )
   where id = p_incident_id;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.dispatch_emergency(
  p_incident_id uuid,
  p_access_token text,
  p_severity text,
  p_summary text,
  p_recommendations text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_incident public.emergency_incidents;
  v_hospital public.hospitals;
  v_ambulance public.ambulances;
  v_lat double precision;
  v_lng double precision;
  v_unit text;
begin
  v_incident := public._assert_emergency_access(p_incident_id, p_access_token);

  if v_incident.status in ('resolved', 'cancelled') then
    raise exception 'incident closed';
  end if;

  -- Idempotente: si ya se despachó ayuda, devolvemos el estado actual sin
  -- duplicar eventos ni mover una segunda ambulancia.
  if v_incident.status in ('dispatched', 'en_route', 'on_scene', 'transporting') then
    return public.get_emergency_status(p_incident_id, p_access_token);
  end if;

  if p_severity is null
     or p_severity not in ('low', 'moderate', 'high', 'critical') then
    raise exception 'invalid severity';
  end if;

  v_lat := v_incident.latitude;
  v_lng := v_incident.longitude;

  if v_lat is null or v_lng is null then
    select l.latitude, l.longitude
      into v_lat, v_lng
      from public.emergency_locations l
     where l.incident_id = p_incident_id
     order by l.created_at desc
     limit 1;
  end if;

  -- Hospital con urgencias más cercano (o el primero disponible sin GPS).
  select h.*
    into v_hospital
    from public.hospitals h
   where h.is_active
     and h.has_emergency_room
   order by case
     when v_lat is not null and v_lng is not null
     then public._distance_km(v_lat, v_lng, h.latitude, h.longitude)
     else 0
   end asc
   limit 1;

  if not found then
    raise exception 'no hospital available';
  end if;

  select a.*
    into v_ambulance
    from public.ambulances a
   where a.hospital_id = v_hospital.id
     and a.is_active
     and a.status = 'available'
   order by a.eta_minutes asc
   limit 1
   for update skip locked;

  if found then
    update public.ambulances
       set status = 'dispatched'
     where id = v_ambulance.id;
    v_unit := v_ambulance.unit_code;
  end if;

  update public.emergency_incidents
     set status = 'dispatched',
         severity = p_severity,
         ai_summary = coalesce(nullif(trim(coalesce(p_summary, '')), ''), ai_summary),
         recommendations = coalesce(p_recommendations, recommendations),
         hospital_id = v_hospital.id,
         ambulance_id = case when v_unit is null then ambulance_id else v_ambulance.id end,
         dispatched_at = coalesce(dispatched_at, now())
   where id = p_incident_id;

  insert into public.emergency_incident_events (
    incident_id, event_type, message, metadata
  )
  values (
    p_incident_id,
    'dispatched',
    case
      when v_unit is null then
        'Servicios de emergencia notificados. Hospital asignado: ' || v_hospital.name || '.'
      else
        'Ambulancia ' || v_unit || ' asignada por ' || v_hospital.name || '.'
    end,
    jsonb_build_object(
      'hospital_id', v_hospital.id,
      'ambulance_id', case when v_unit is null then null else v_ambulance.id end,
      'severity', p_severity
    )
  );

  return public.get_emergency_status(p_incident_id, p_access_token);
end;
$$;

create or replace function public.log_ai_message(
  p_incident_id uuid,
  p_access_token text,
  p_role text,
  p_content text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_incident public.emergency_incidents;
  v_conversation_id uuid;
  v_message_id uuid;
begin
  v_incident := public._assert_emergency_access(p_incident_id, p_access_token);

  if p_role is null or p_role not in ('user', 'assistant', 'system') then
    raise exception 'invalid role';
  end if;

  if coalesce(trim(p_content), '') = '' then
    raise exception 'empty message';
  end if;

  select id
    into v_conversation_id
    from public.ai_conversations
   where incident_id = p_incident_id
   order by created_at desc
   limit 1;

  if v_conversation_id is null then
    insert into public.ai_conversations (incident_id, user_id)
    values (p_incident_id, v_incident.patient_id)
    returning id into v_conversation_id;
  else
    update public.ai_conversations
       set updated_at = now()
     where id = v_conversation_id;
  end if;

  insert into public.ai_messages (conversation_id, role, content, metadata)
  values (
    v_conversation_id,
    p_role,
    trim(p_content),
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_message_id;

  if v_incident.status = 'created' then
    update public.emergency_incidents
       set status = 'triaging'
     where id = p_incident_id;
  end if;

  return jsonb_build_object(
    'message', jsonb_build_object(
      'id', v_message_id,
      'conversation_id', v_conversation_id,
      'role', p_role,
      'created_at', now()
    )
  );
end;
$$;

create or replace function public.cancel_emergency(
  p_incident_id uuid,
  p_access_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_incident public.emergency_incidents;
begin
  v_incident := public._assert_emergency_access(p_incident_id, p_access_token);

  if v_incident.status in ('resolved', 'cancelled') then
    return jsonb_build_object('ok', true, 'status', v_incident.status);
  end if;

  if v_incident.ambulance_id is not null then
    update public.ambulances
       set status = 'available'
     where id = v_incident.ambulance_id
       and status = 'dispatched';
  end if;

  update public.emergency_incidents
     set status = 'cancelled',
         resolved_at = now()
   where id = p_incident_id;

  insert into public.emergency_incident_events (
    incident_id, event_type, message
  )
  values (
    p_incident_id,
    'cancelled',
    'El usuario finalizó el reporte. Ambulancia liberada.'
  );

  return jsonb_build_object('ok', true, 'status', 'cancelled');
end;
$$;

-- -----------------------------------------------------------------------------
-- Hospitales cercanos
-- -----------------------------------------------------------------------------

create or replace function public.nearby_hospitals(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_km double precision default 30,
  p_limit integer default 20
)
returns table (
  id uuid,
  name text,
  address text,
  city text,
  phone text,
  emergency_phone text,
  lat double precision,
  lng double precision,
  distance_km double precision,
  has_emergency_room boolean,
  has_ambulance boolean,
  beds_available integer,
  trauma_level text,
  services text[]
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    h.id,
    h.name,
    h.address,
    h.city,
    h.phone,
    h.emergency_phone,
    h.latitude as lat,
    h.longitude as lng,
    round(
      public._distance_km(p_latitude, p_longitude, h.latitude, h.longitude)::numeric,
      2
    )::double precision as distance_km,
    h.has_emergency_room,
    h.has_ambulance,
    h.beds_available,
    h.trauma_level,
    h.services
  from public.hospitals h
  where h.is_active
    and public._distance_km(
      p_latitude,
      p_longitude,
      h.latitude,
      h.longitude
    ) <= greatest(coalesce(p_radius_km, 30), 1)
  order by distance_km asc
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$$;

-- -----------------------------------------------------------------------------
-- Citas
-- -----------------------------------------------------------------------------

create or replace function public.book_appointment(
  p_doctor_id uuid,
  p_treatment_id uuid,
  p_scheduled_at timestamptz,
  p_reason text,
  p_type text,
  p_hospital_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_patient_id uuid := auth.uid();
  v_doctor public.doctors;
  v_treatment public.treatments;
  v_price numeric(12, 2) := 0;
  v_hospital_id uuid;
  v_appointment_id uuid;
  v_payload jsonb;
begin
  if v_patient_id is null then
    raise exception 'authentication required';
  end if;

  if p_scheduled_at is null or p_scheduled_at <= now() then
    raise exception 'appointment must be in the future';
  end if;

  if p_type is null
     or p_type not in ('consultation', 'surgery', 'treatment', 'follow_up') then
    raise exception 'invalid appointment type';
  end if;

  if p_doctor_id is null and p_treatment_id is null then
    raise exception 'doctor or treatment required';
  end if;

  if p_doctor_id is not null then
    select *
      into v_doctor
      from public.doctors
     where id = p_doctor_id
       and is_active;

    if not found then
      raise exception 'doctor not found';
    end if;

    v_price := coalesce(v_doctor.consultation_fee, 0);
    v_hospital_id := coalesce(p_hospital_id, v_doctor.hospital_id);
  end if;

  if p_treatment_id is not null then
    select *
      into v_treatment
      from public.treatments
     where id = p_treatment_id
       and is_active;

    if not found then
      raise exception 'treatment not found';
    end if;

    if p_doctor_id is null then
      v_price := coalesce(v_treatment.price, 0);
      v_hospital_id := coalesce(p_hospital_id, v_treatment.hospital_id);
    end if;
  end if;

  begin
    insert into public.appointments (
      patient_id,
      doctor_id,
      treatment_id,
      hospital_id,
      type,
      status,
      scheduled_at,
      reason,
      price
    )
    values (
      v_patient_id,
      p_doctor_id,
      p_treatment_id,
      v_hospital_id,
      p_type,
      'pending',
      p_scheduled_at,
      nullif(trim(coalesce(p_reason, '')), ''),
      v_price
    )
    returning id into v_appointment_id;
  exception
    when unique_violation then
      raise exception 'duplicate appointment slot';
  end;

  select jsonb_build_object(
    'id', a.id,
    'patient_id', a.patient_id,
    'doctor_id', a.doctor_id,
    'treatment_id', a.treatment_id,
    'hospital_id', a.hospital_id,
    'type', a.type,
    'status', a.status,
    'scheduled_at', a.scheduled_at,
    'reason', a.reason,
    'price', a.price,
    'created_at', a.created_at,
    'doctor_name', d.full_name,
    'hospital_name', h.name,
    'doctors', case
      when d.id is null then null
      else jsonb_build_object(
        'full_name', d.full_name,
        'specialty', d.specialty
      )
    end,
    'hospitals', case
      when h.id is null then null
      else jsonb_build_object('name', h.name)
    end
  )
  into v_payload
  from public.appointments a
  left join public.doctors d on d.id = a.doctor_id
  left join public.hospitals h on h.id = a.hospital_id
  where a.id = v_appointment_id;

  return jsonb_build_object('appointment', v_payload);
end;
$$;

create or replace function public.cancel_appointment(
  p_appointment_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_patient_id uuid := auth.uid();
begin
  if v_patient_id is null then
    raise exception 'authentication required';
  end if;

  update public.appointments
     set status = 'cancelled'
   where id = p_appointment_id
     and patient_id = v_patient_id
     and status in ('pending', 'confirmed');

  if not found then
    raise exception 'appointment not found or not cancellable';
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

-- -----------------------------------------------------------------------------
-- Farmacia
-- -----------------------------------------------------------------------------

create or replace function public.place_order(
  p_items jsonb,
  p_delivery_address text,
  p_payment_method text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_patient_id uuid := auth.uid();
  v_item jsonb;
  v_medicine public.medicines;
  v_quantity integer;
  v_subtotal numeric(12, 2) := 0;
  v_delivery_fee numeric(12, 2) := 4900;
  v_total numeric(12, 2);
  v_order_id uuid;
  v_items jsonb := '[]'::jsonb;
begin
  if v_patient_id is null then
    raise exception 'authentication required';
  end if;

  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'empty cart';
  end if;

  if coalesce(trim(p_delivery_address), '') = '' then
    raise exception 'delivery address required';
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'card', 'transfer') then
    raise exception 'invalid payment method';
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_quantity := coalesce((v_item ->> 'quantity')::integer, 0);

    if v_quantity <= 0 then
      raise exception 'invalid quantity';
    end if;

    select *
      into v_medicine
      from public.medicines
     where id = (v_item ->> 'medicine_id')::uuid
       and is_active
     for update;

    if not found then
      raise exception 'medicine not found';
    end if;

    if v_medicine.stock < v_quantity then
      raise exception 'insufficient stock for %', v_medicine.name;
    end if;

    v_subtotal := v_subtotal + (v_medicine.price * v_quantity);

    update public.medicines
       set stock = stock - v_quantity
     where id = v_medicine.id;

    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'medicine_id', v_medicine.id,
        'medicine_name', v_medicine.name,
        'quantity', v_quantity,
        'unit_price', v_medicine.price
      )
    );
  end loop;

  v_total := v_subtotal + v_delivery_fee;

  insert into public.orders (
    patient_id,
    status,
    subtotal,
    delivery_fee,
    total,
    delivery_address,
    payment_method
  )
  values (
    v_patient_id,
    'pending',
    v_subtotal,
    v_delivery_fee,
    v_total,
    trim(p_delivery_address),
    p_payment_method
  )
  returning id into v_order_id;

  insert into public.order_items (order_id, medicine_id, quantity, unit_price)
  select
    v_order_id,
    (item ->> 'medicine_id')::uuid,
    (item ->> 'quantity')::integer,
    (item ->> 'unit_price')::numeric
  from jsonb_array_elements(v_items) as item;

  return jsonb_build_object(
    'order', (
      select to_jsonb(o)
      from public.orders o
      where o.id = v_order_id
    ),
    'items', v_items
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- Permisos
-- -----------------------------------------------------------------------------

revoke all on function public._distance_km(double precision, double precision, double precision, double precision) from public, anon, authenticated;
revoke all on function public._assert_emergency_access(uuid, text) from public, anon, authenticated;

grant execute on function public.create_emergency(text, double precision, double precision, double precision, text, text, text, text, text) to anon, authenticated;
grant execute on function public.get_emergency_status(uuid, text) to anon, authenticated;
grant execute on function public.append_emergency_location(uuid, text, double precision, double precision, double precision, text) to anon, authenticated;
grant execute on function public.dispatch_emergency(uuid, text, text, text, text[]) to anon, authenticated;
grant execute on function public.log_ai_message(uuid, text, text, text, jsonb) to anon, authenticated;
grant execute on function public.cancel_emergency(uuid, text) to anon, authenticated;
grant execute on function public.nearby_hospitals(double precision, double precision, double precision, integer) to anon, authenticated;
grant execute on function public.book_appointment(uuid, uuid, timestamptz, text, text, uuid) to authenticated;
grant execute on function public.cancel_appointment(uuid) to authenticated;
grant execute on function public.place_order(jsonb, text, text) to authenticated;
