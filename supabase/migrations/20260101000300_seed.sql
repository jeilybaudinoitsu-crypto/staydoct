-- =============================================================================
-- Staydoct · Datos de demostración
-- =============================================================================
-- Catálogo inicial para que la app no arranque vacía. Las coordenadas son
-- aproximadas y sirven para probar `nearby_hospitals` y el despacho.
-- Ejecuta esta migración después de schema/rls/rpc.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Hospitales (Bogotá y Medellín)
-- -----------------------------------------------------------------------------

insert into public.hospitals (
  id, name, address, city, phone, emergency_phone,
  latitude, longitude, has_emergency_room, has_ambulance,
  beds_available, trauma_level, services
)
values
  (
    '11111111-1111-4111-8111-111111111101',
    'Hospital Universitario San Ignacio',
    'Carrera 7 # 40-62',
    'Bogotá',
    '+57 601 594 6161',
    '+57 601 594 6161',
    4.6280, -74.0633,
    true, true, 12, 'Nivel II',
    array['Urgencias', 'Cardiología', 'Pediatría', 'Cirugía', 'UCI']
  ),
  (
    '11111111-1111-4111-8111-111111111102',
    'Hospital Simón Bolívar',
    'Calle 165 # 59-77',
    'Bogotá',
    '+57 601 676 0600',
    '+57 601 676 0600',
    4.7110, -74.0560,
    true, true, 20, 'Nivel II',
    array['Urgencias', 'Trauma', 'Ortopedia', 'Cirugía', 'Imágenes']
  ),
  (
    '11111111-1111-4111-8111-111111111103',
    'Clínica del Country',
    'Carrera 16 # 82-57',
    'Bogotá',
    '+57 601 530 0470',
    '+57 601 530 0470',
    4.6760, -74.0480,
    true, true, 8, 'Nivel III',
    array['Urgencias', 'Cardiología', 'Neurología', 'UCI', 'Laboratorio']
  ),
  (
    '11111111-1111-4111-8111-111111111104',
    'Hospital General de Medellín',
    'Carrera 48 # 32-102',
    'Medellín',
    '+57 604 384 7300',
    '+57 604 384 7300',
    6.2442, -75.5636,
    true, true, 16, 'Nivel II',
    array['Urgencias', 'Trauma', 'Cirugía', 'Pediatría', 'UCI']
  ),
  (
    '11111111-1111-4111-8111-111111111105',
    'Clínica Las Américas',
    'Diagonal 75B # 2A-80',
    'Medellín',
    '+57 604 342 1010',
    '+57 604 342 1010',
    6.2410, -75.5890,
    true, true, 10, 'Nivel III',
    array['Urgencias', 'Cardiología', 'Oncología', 'Cirugía', 'UCI']
  )
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Ambulancias
-- -----------------------------------------------------------------------------

insert into public.ambulances (
  id, hospital_id, unit_code, status, eta_minutes, crew_size, is_active
)
values
  (
    '22222222-2222-4222-8222-222222222201',
    '11111111-1111-4111-8111-111111111101',
    'AMB-BOG-01', 'available', 9, 3, true
  ),
  (
    '22222222-2222-4222-8222-222222222202',
    '11111111-1111-4111-8111-111111111101',
    'AMB-BOG-02', 'available', 14, 2, true
  ),
  (
    '22222222-2222-4222-8222-222222222203',
    '11111111-1111-4111-8111-111111111102',
    'AMB-BOG-03', 'available', 12, 3, true
  ),
  (
    '22222222-2222-4222-8222-222222222204',
    '11111111-1111-4111-8111-111111111103',
    'AMB-BOG-04', 'available', 11, 2, true
  ),
  (
    '22222222-2222-4222-8222-222222222205',
    '11111111-1111-4111-8111-111111111104',
    'AMB-MDE-01', 'available', 10, 3, true
  ),
  (
    '22222222-2222-4222-8222-222222222206',
    '11111111-1111-4111-8111-111111111105',
    'AMB-MDE-02', 'available', 15, 2, true
  )
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Especialistas
-- -----------------------------------------------------------------------------

insert into public.doctors (
  id, hospital_id, full_name, specialty, bio, rating,
  consultation_fee, is_active
)
values
  (
    '33333333-3333-4333-8333-333333333301',
    '11111111-1111-4111-8111-111111111101',
    'Dra. Camila Restrepo',
    'Medicina general',
    'Atención integral del adulto, con enfoque en prevención y seguimiento de enfermedades crónicas.',
    4.8, 120000, true
  ),
  (
    '33333333-3333-4333-8333-333333333302',
    '11111111-1111-4111-8111-111111111103',
    'Dr. Andrés Mejía',
    'Cardiología',
    'Cardiólogo clínico. Evaluación de riesgo cardiovascular, arritmias e hipertensión.',
    4.9, 220000, true
  ),
  (
    '33333333-3333-4333-8333-333333333303',
    '11111111-1111-4111-8111-111111111101',
    'Dra. Laura Beltrán',
    'Pediatría',
    'Pediatra con experiencia en urgencias y control del niño sano.',
    4.7, 150000, true
  ),
  (
    '33333333-3333-4333-8333-333333333304',
    '11111111-1111-4111-8111-111111111104',
    'Dr. Julián Ospina',
    'Ortopedia',
    'Cirugía de rodilla, hombro y columna. Rehabilitación deportiva.',
    4.6, 180000, true
  ),
  (
    '33333333-3333-4333-8333-333333333305',
    '11111111-1111-4111-8111-111111111105',
    'Dra. Valentina Ríos',
    'Neurología',
    'Cefaleas, epilepsia y trastornos del movimiento. Valoración de eventos cerebrovasculares.',
    4.8, 210000, true
  )
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Cirugías y tratamientos
-- -----------------------------------------------------------------------------

insert into public.treatments (
  id, hospital_id, name, category, description,
  duration_minutes, price, is_active
)
values
  (
    '44444444-4444-4444-8444-444444444401',
    '11111111-1111-4111-8111-111111111101',
    'Apendicectomía',
    'surgery',
    'Extracción del apéndice por laparoscopia. Incluye valoración prequirúrgica y control postoperatorio.',
    90, 8700000, true
  ),
  (
    '44444444-4444-4444-8444-444444444402',
    '11111111-1111-4111-8111-111111111103',
    'Colecistectomía laparoscópica',
    'surgery',
    'Extracción de la vesícula biliar mediante cirugía mínimamente invasiva.',
    75, 6900000, true
  ),
  (
    '44444444-4444-4444-8444-444444444403',
    '11111111-1111-4111-8111-111111111104',
    'Cirugía artroscópica de rodilla',
    'surgery',
    'Reparación de meniscos y ligamentos con artroscopia. Incluye fisioterapia inicial.',
    90, 8200000, true
  ),
  (
    '44444444-4444-4444-8444-444444444404',
    '11111111-1111-4111-8111-111111111105',
    'Terapia física respiratoria',
    'treatment',
    'Sesión de rehabilitación pulmonar para pacientes con EPOC o postoperatorio.',
    45, 95000, true
  ),
  (
    '44444444-4444-4444-8444-444444444405',
    '11111111-1111-4111-8111-111111111101',
    'Tratamiento de heridas y curaciones',
    'treatment',
    'Limpieza, sutura menor y cambio de apósitos con insumos estériles.',
    30, 120000, true
  ),
  (
    '44444444-4444-4444-8444-444444444406',
    '11111111-1111-4111-8111-111111111104',
    'Manejo del dolor crónico',
    'treatment',
    'Valoración y plan de manejo del dolor con seguimiento a cuatro semanas.',
    40, 180000, true
  )
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Farmacia
-- -----------------------------------------------------------------------------

insert into public.medicines (
  id, name, generic_name, description, category,
  requires_prescription, stock, manufacturer, dosage, price, is_active
)
values
  (
    '55555555-5555-4555-8555-555555555501',
    'Acetaminofén 500 mg', 'Paracetamol', 'Analgésico y antipirético.',
    'medicine', false, 200, 'Genfar', '1 tableta cada 8 horas', 4500, true
  ),
  (
    '55555555-5555-4555-8555-555555555502',
    'Ibuprofeno 400 mg', 'Ibuprofeno', 'Antiinflamatorio no esteroideo.',
    'medicine', false, 180, 'Tecnoquímicas', '1 tableta cada 8 horas con alimentos', 6200, true
  ),
  (
    '55555555-5555-4555-8555-555555555503',
    'Loratadina 10 mg', 'Loratadina', 'Antihistamínico para alergias.',
    'medicine', false, 160, 'MK', '1 tableta al día', 5800, true
  ),
  (
    '55555555-5555-4555-8555-555555555504',
    'Omeprazol 20 mg', 'Omeprazol', 'Protector gástrico.',
    'medicine', false, 140, 'Genfar', '1 cápsula en ayunas', 8900, true
  ),
  (
    '55555555-5555-4555-8555-555555555505',
    'Amoxicilina 500 mg', 'Amoxicilina', 'Antibiótico de amplio espectro.',
    'medicine', true, 90, 'Laproff', '1 cápsula cada 8 horas', 12900, true
  ),
  (
    '55555555-5555-4555-8555-555555555506',
    'Losartán 50 mg', 'Losartán', 'Antihipertensivo.',
    'medicine', true, 120, 'Genfar', '1 tableta al día', 9400, true
  ),
  (
    '55555555-5555-4555-8555-555555555507',
    'Inhalador de salbutamol', 'Salbutamol', 'Broncodilatador de rescate.',
    'medicine', true, 45, 'GSK', '2 inhalaciones si hay dificultad respiratoria', 27000, true
  ),
  (
    '55555555-5555-4555-8555-555555555508',
    'Kit de primeros auxilios', null, 'Gasas, vendas, alcohol y curitas.',
    'first_aid', false, 40, 'Staydoct', 'Contenido básico', 45000, true
  ),
  (
    '55555555-5555-4555-8555-555555555509',
    'Gasas estériles x10', null, 'Gasas de 7,5 x 7,5 cm.',
    'first_aid', false, 70, 'Cureband', 'Paquete por 10 unidades', 12000, true
  ),
  (
    '55555555-5555-4555-8555-555555555510',
    'Alcohol antiséptico 500 ml', null, 'Solución de alcohol al 70 %.',
    'first_aid', false, 80, 'Farmatodo', 'Uso externo', 9500, true
  ),
  (
    '55555555-5555-4555-8555-555555555511',
    'Termómetro digital', null, 'Termómetro de lectura rápida.',
    'equipment', false, 35, 'Omron', 'Medición axilar', 32000, true
  ),
  (
    '55555555-5555-4555-8555-555555555512',
    'Oxímetro de pulso', null, 'Medidor de saturación de oxígeno.',
    'equipment', false, 25, 'Contec', 'Uso en dedo índice', 78000, true
  ),
  (
    '55555555-5555-4555-8555-555555555513',
    'Vitamina C 1000 mg', 'Ácido ascórbico', 'Suplemento antioxidante.',
    'wellness', false, 100, 'Nature’s Garden', '1 tableta al día', 22000, true
  ),
  (
    '55555555-5555-4555-8555-555555555514',
    'Suero oral', null, 'Solución de rehidratación oral.',
    'wellness', false, 120, 'Pedialyte', '1 sobre en 1 litro de agua', 6800, true
  )
on conflict (id) do nothing;
