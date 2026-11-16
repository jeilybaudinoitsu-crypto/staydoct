# Staydoct

**Ayuda médica de emergencia, sin barreras.**

Staydoct es una aplicación Flutter de asistencia médica de emergencia. Cualquier
persona puede reportar una emergencia **sin crear una cuenta**: un botón SOS
recoge la ubicación GPS, un agente de IA (Gemini + protocolo local de respaldo)
acompaña a la persona, da primeros auxilios y despacha los servicios de
emergencia con la ubicación exacta. Los usuarios registrados, además, pueden
agendar citas y cirugías, reservar tratamientos y comprar medicamentos.

> Staydoct **complementa** al número local de emergencias (123 en Colombia); no
> lo reemplaza. En una emergencia con riesgo vital, llama también al 123.

---

## Tabla de contenido

- [Funcionalidades](#funcionalidades)
- [Stack tecnológico](#stack-tecnológico)
- [Inicio rápido](#inicio-rápido)
- [Variables de entorno](#variables-de-entorno)
- [Configuración de Supabase](#configuración-de-supabase)
- [Arquitectura feature-first](#arquitectura-feature-first)
- [Flujo de emergencia](#flujo-de-emergencia)
- [Modelo de seguridad del modo anónimo](#modelo-de-seguridad-del-modo-anónimo)
- [Autenticación: primero invitado](#autenticación-primero-invitado)
- [Contratos RPC](#contratos-rpc)
- [Modelo de datos](#modelo-de-datos)
- [IA conversacional y voz](#ia-conversacional-y-voz)
- [Mapas](#mapas)
- [Pruebas y calidad](#pruebas-y-calidad)
- [Cumplimiento, privacidad y límites](#cumplimiento-privacidad-y-límites)
- [Roadmap](#roadmap)

---

## Funcionalidades

### Emergencia (sin login)

- **SOS en tres toques**: abrir → confirmar → describir la emergencia.
- **Ubicación GPS** capturada de inmediato y reenviada periódicamente mientras
  el incidente está activo.
- **Chat con "Vera"**, la agente de triaje: contiene a la persona, hace una sola
  pregunta por turno y da primeros auxilios de protocolo.
- **Despacho automático**: si la IA detecta riesgo vital, llama a la herramienta
  `dispatch_emergency_services` en el primer turno, sin esperar una historia
  clínica completa.
- **Respaldo local**: si Gemini no está configurado o falla, un motor de reglas
  (`LocalTriageAssistant`) responde y despacha igualmente. El flujo de
  emergencia nunca se queda sin respuesta.
- **Seguimiento en vivo**: estado del incidente, hospital y ambulancia asignados,
  línea de tiempo de eventos y botón directo al 123.
- **Retomar un reporte activo**: el incidente y su token de acceso se guardan en
  el dispositivo, de modo que cerrar la app no pierde la emergencia.

### Servicios para usuarios registrados

- **Citas médicas** con especialistas verificados (fecha, hora, motivo).
- **Cirugías y tratamientos** con precio y hospital asociados.
- **Farmacia** con catálogo, control de existencias, carrito, checkout y
  seguimiento de pedidos.
- **Hospitales cercanos** ordenados por distancia, con llamada directa.
- **Perfil clínico**: tipo de sangre, alergias, condiciones crónicas y contacto
  de emergencia.

### Transversal

- Autenticación **primero invitado**: explorar y pedir ayuda nunca exige cuenta.
- Tema claro/oscuro, tipografía del sistema y tokens de diseño propios.
- Voz bidireccional: dictado por micrófono y lectura en voz alta de las
  respuestas de la IA (degrada con elegancia si el dispositivo no la soporta).
- Errores de backend traducidos a mensajes claros en español.

---

## Stack tecnológico

| Capa | Tecnología |
| --- | --- |
| Frontend | Flutter 3.47+ / Dart 3.13+ |
| Estado | `provider` + `ChangeNotifier` |
| Navegación | `go_router` (`StatefulShellRoute.indexedStack`) |
| Backend | Supabase (PostgreSQL, Auth, RLS, RPC) |
| IA | Gemini (`gemini-2.0-flash`) vía Supabase Edge Function + motor local |
| Voz | `flutter_tts` + `speech_to_text` |
| Mapas y ubicación | `google_maps_flutter`, `geolocator`, `geocoding` |
| Persistencia local | `shared_preferences` |

---

## Inicio rápido

### Requisitos

- Flutter 3.47 o superior (Dart 3.13+).
- Un proyecto de Supabase con las migraciones de [`supabase/migrations`](supabase/migrations).
- (Opcional) Clave de Gemini en [Google AI Studio](https://aistudio.google.com/apikey).
- (Opcional) Clave de Google Maps Platform.

### Instalar y ejecutar

```bash
flutter pub get

flutter run \
  --dart-define=GOOGLE_MAPS_API_KEY=tu_api_key_de_maps
```

Gemini se configura en el backend de Supabase; la app conserva el protocolo
local como alternativa si la función remota no está disponible. La voz en
tiempo real usa Gemini Live y transmite PCM mono de 16 kHz desde el micrófono;
las respuestas llegan como PCM mono de 24 kHz. Sin `GOOGLE_MAPS_API_KEY` se
muestra un panel informativo en lugar del mapa.

### Compilar

```bash
# Android: configura antes android/key.properties y la clave restringida de Maps.
flutter build appbundle --release \
  -PGOOGLE_MAPS_API_KEY=tu_api_key_de_maps \
  --dart-define=GOOGLE_MAPS_API_KEY=tu_api_key_de_maps

# iOS: la clave se inyecta con GOOGLE_MAPS_API_KEY en el xcconfig de Xcode
# (ios/Flutter/Debug.xcconfig y Release.xcconfig).
flutter build ios --release \
  --dart-define=GOOGLE_MAPS_API_KEY=tu_api_key_de_maps

# Web: además, descomenta el <script> de Google Maps en web/index.html.
flutter build web
```

> La clave de Maps debe pasarse dos veces en móvil: como `--dart-define` (para
> que el widget sepa que hay mapa) y como clave nativa (`-PGOOGLE_MAPS_API_KEY`
> en Android, `GOOGLE_MAPS_API_KEY` en el xcconfig de iOS).

Para firmar Android en release local, guarda `android/key.properties` (ignorado
por Git) con `storeFile`, `storePassword`, `keyAlias` y `keyPassword`, y conserva
el keystore fuera del repositorio. No uses ni compartas la clave de debug.

Este proyecto ya incluye una clave de release local
(`android/app/staydoct-release.jks`) y su `android/key.properties`; ambos están
ignorados por Git. **Haz una copia de seguridad de los dos ahora**: la misma
clave debe usarse en todas las actualizaciones distribuidas y su contraseña vive
en `key.properties`. Si el archivo no existe (por ejemplo en CI), el build de
release usa la clave de debug para no fallar, pero ese APK no sirve para Google
Play. `storeFile` puede ser relativo a `android/app/` o a `android/`.

El workflow [Android APK](.github/workflows/android-apk.yml) crea un APK
firmado al ejecutarlo manualmente o al subir una etiqueta `v*`; en este último
caso también adjunta el APK a un GitHub Release. Configura en GitHub Actions
los secretos `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS` y `ANDROID_KEY_PASSWORD`. `GOOGLE_MAPS_API_KEY` es
opcional; restringe esa clave por aplicación Android y API en Google Cloud. La
ejecución manual deja el APK como artefacto de Actions.

Para crear la clave de firma una sola vez (fuera del repositorio) en Linux:

```bash
keytool -genkeypair -v -keystore "$HOME/staydoct-upload.jks" \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w 0 "$HOME/staydoct-upload.jks"
```

Guarda la salida base64 y los datos de alias/contraseñas como los secretos
indicados en la configuración de GitHub Actions. Conserva una copia segura del
keystore; la misma clave debe usarse en todas las actualizaciones distribuidas.

---

## Variables de entorno

Todas se inyectan en tiempo de compilación con `--dart-define` y se leen en
[`lib/core/config/env.dart`](lib/core/config/env.dart).

| Variable | Obligatoria | Valor por defecto | Uso |
| --- | --- | --- | --- |
| `SUPABASE_URL` | No | URL del proyecto incluido | Endpoint de Supabase |
| `SUPABASE_PUBLISHABLE_KEY` | No | Publishable key incluida | Clave pública de Supabase |
| `GOOGLE_MAPS_API_KEY` | Opcional | vacío | Habilita el mapa; si falta, se muestra un panel |

La URL y la *publishable key* de Supabase son públicas por diseño: la seguridad
real vive en las políticas RLS y en las funciones RPC del backend. La clave de
Gemini solo se configura como secreto de la Edge Function; no la pases con
`--dart-define` ni la guardes en el repositorio o en el APK.

### Configurar Gemini en el backend

1. Crea una clave en Google AI Studio.
2. En Supabase Dashboard, abre **Edge Functions → Secrets** y añade
   `GEMINI_API_KEY`. Opcionalmente, añade `GEMINI_MODEL` para cambiar el modelo
   del chat escrito (el valor por defecto es `gemini-2.0-flash`) y
   `GEMINI_LIVE_MODEL` para cambiar el modelo de voz (el recomendado y valor
   por defecto es `gemini-3.8-live`). La clave debe tener acceso a Gemini Live;
   no se necesita otra clave ni configuración de base de datos.
3. Enlaza el directorio con el proyecto Supabase y despliega
   `supabase/functions/gemini-assistant` con la CLI de Supabase:

   ```bash
   supabase link --project-ref <project-ref>
   supabase functions deploy gemini-assistant
   ```

   Si el navegador muestra un error CORS y la petición `OPTIONS` devuelve
   `NOT_FOUND`, la función no está desplegada en el proyecto indicado por
   `SUPABASE_URL`. Confirma que el proyecto enlazado sea el correcto y vuelve
   a desplegarla antes de probar desde la app.

La función tiene la verificación JWT del gateway desactivada porque la pantalla
de emergencia permite continuar sin una cuenta. Antes de llamar a Gemini,
valida el ID y el token de acceso del incidente mediante el RPC
`get_emergency_status`. No uses una clave `service_role` en la app. La función
valida la sesión antes de responder por texto o emitir un token de un solo uso
para Gemini Live. El token temporal se limita al modelo, las instrucciones y
las herramientas de Staydoct. En modo de voz, el audio se envía en tiempo real
a Google; el ID y token de acceso del incidente se quedan en Supabase y las
coordenadas GPS no se envían a Gemini.

---

## Configuración de Supabase

### 1. Aplicar las migraciones

Las migraciones son idempotentes y deben aplicarse **en orden**:

| Orden | Archivo | Contenido |
| --- | --- | --- |
| 1 | `20260101000000_schema.sql` | Tablas, tipos, restricciones, triggers, índices |
| 2 | `20260101000100_rls.sql` | Row Level Security, permisos y tablas sensibles revocadas |
| 3 | `20260101000200_rpc.sql` | Funciones RPC de emergencia, citas y pedidos |
| 4 | `20260101000300_seed.sql` | Datos demo: hospitales, ambulancias, doctores, tratamientos y medicamentos |

Con la CLI de Supabase (si el proyecto aún no tiene `supabase/config.toml`,
ejecuta `supabase init` y conserva las migraciones):

```bash
supabase link --project-ref <project-ref>
supabase db push
```

O pegando cada archivo, en orden, en el **SQL Editor** del panel de Supabase.

### 2. Configurar Auth

- Habilita el proveedor **Email**.
- Si quieres registro inmediato sin correo de confirmación, desactiva
  *Confirm email* en **Authentication → Providers → Email**.
- El trigger `handle_new_user` crea automáticamente la fila en `profiles`.

### 3. Verificar

```sql
select public.nearby_hospitals(4.7110, -74.0721, 50, 5);
```

Debe devolver los hospitales del seed ordenados por distancia. Si devuelve
vacío, revisa el orden de las migraciones y que el seed se haya ejecutado.

---

## Arquitectura feature-first

El código se organiza **por funcionalidad**, no por tipo de archivo. Cada feature
contiene sus propias capas `data` / `domain` / `presentation` y solo depende de
`core` y de sus propias capas. Las pantallas consumen **interfaces**, nunca
implementaciones concretas de Supabase.

```text
lib/
├── main.dart                     # Inicializa Supabase y arranca la app
├── app.dart                      # Inyección de dependencias (Provider) y MaterialApp.router
│
├── core/                         # Código compartido, sin lógica de negocio de una feature
│   ├── config/
│   │   ├── env.dart              # Lectura de --dart-define
│   │   └── app_constants.dart    # Nombre, teléfono de emergencia, intervalos, claves locales
│   ├── errors/
│   │   └── app_exception.dart    # Excepción de dominio con mensaje para el usuario
│   ├── models/
│   │   └── user_location.dart    # Coordenadas + dirección legible
│   ├── network/
│   │   └── supabase_client.dart  # Acceso tipado al cliente de Supabase
│   ├── router/
│   │   └── app_router.dart       # Rutas, shell de 4 pestañas y fallbacks
│   ├── services/
│   │   ├── location_service.dart # Permisos y GPS (geolocator + geocoding)
│   │   ├── speech_service.dart   # Voz a texto y texto a voz
│   │   ├── prefs_service.dart    # device_id, incidente activo, preferencias
│   │   └── phone_service.dart    # Llamadas al 123 y a hospitales
│   ├── theme/
│   │   ├── app_colors.dart       # Tokens de color
│   │   └── app_theme.dart        # Tema claro/oscuro
│   ├── utils/                    # Formatters, validators, feedback (snackbars)
│   └── widgets/                  # Botones, SOS, pills, layout y mapa reutilizables
│
└── features/
    ├── shell/                    # Barra de navegación inferior persistente
    ├── home/                     # Inicio: SOS, accesos rápidos y consejos
    │
    ├── emergency/                # Reporte y seguimiento de emergencias
    │   ├── data/
    │   │   ├── datasources/      # RPC create/get/append/dispatch/cancel
    │   │   ├── models/           # Mapeo de filas SQL a entidades
    │   │   └── repositories/     # Implementación del repositorio
    │   ├── domain/
    │   │   ├── entities/         # Incidente, evento, ambulancia, hospital, sesión
    │   │   └── repositories/     # Contrato de emergencias
    │   └── presentation/
    │       ├── controllers/      # Intake (GPS + creación) y tracking (sondeo)
    │       ├── pages/            # Intake, chat y seguimiento
    │       └── widgets/          # Tarjetas de estado y timeline
    │
    ├── ai_chat/                  # Agente de triaje
    │   ├── data/
    │   │   ├── datasources/      # Supabase Edge Function + fallback local
    │   │   ├── prompt_builder.dart
    │   │   └── repositories/     # Orquesta Gemini con red de seguridad
    │   ├── domain/
    │   │   ├── entities/         # Mensajes, contexto y resultado del turno
    │   │   └── repositories/     # Contrato del asistente
    │   └── presentation/
    │       ├── controllers/      # Conversación, voz, despacho y ubicación
    │       └── widgets/          # Burbujas, indicador de escritura, chips
    │
    ├── auth/                     # Registro e inicio de sesión
    │   ├── data/repositories/
    │   ├── domain/               # Perfil del paciente y contrato de auth
    │   └── presentation/         # Login, registro, AuthGate y AuthController
    │
    ├── appointments/             # Citas, cirugías y tratamientos
    │   ├── data/repositories/
    │   ├── domain/entities/      # Appointment, Doctor, Treatment, BookingTarget
    │   └── presentation/         # Servicios, agendar y mis citas
    │
    ├── pharmacy/                 # Farmacia y pedidos
    │   ├── data/repositories/
    │   ├── domain/entities/      # Medicine, CartItem, PharmacyOrder
    │   └── presentation/         # Catálogo, carrito, pedidos y controladores
    │
    ├── hospitals/                # Hospitales cercanos
    │   ├── data/repositories/
    │   ├── domain/entities/
    │   └── presentation/
    │
    └── profile/                  # Perfil clínico del usuario
        └── presentation/
```

### Convenciones

- **`domain`** no importa Flutter ni Supabase: entidades y contratos puros.
- **`data`** implementa los contratos y traduce filas SQL / respuestas HTTP a
  entidades, con mensajes de error en español.
- **`presentation`** contiene `ChangeNotifier`s y widgets; depende de interfaces.
- **`core`** solo aloja lo verdaderamente transversal. Si algo se usa en una sola
  feature, vive en esa feature.

### Rutas principales

| Ruta | Pantalla |
| --- | --- |
| `/` | Inicio (pestaña) |
| `/servicios` | Servicios: especialistas, cirugías y tratamientos |
| `/farmacia` | Farmacia (pestaña) |
| `/perfil` | Perfil (pestaña) |
| `/emergencia` | Intake del SOS |
| `/emergencia/chat` | Chat de triaje (requiere `EmergencySession`) |
| `/emergencia/seguimiento` | Seguimiento del incidente |
| `/citas`, `/citas/agendar` | Mis citas y agendamiento |
| `/carrito`, `/pedidos` | Carrito y pedidos |
| `/hospitales` | Hospitales cercanos |
| `/login`, `/registro` | Autenticación |

Las rutas que reciben estado por `extra` muestran una pantalla de recuperación si
la app se abrió sin ese contexto (por ejemplo, tras una recarga en web).

---

## Flujo de emergencia

```text
SOS
 └─> EmergencyIntakePage
      ├─ pide permisos y captura GPS
      ├─ create_emergency(...)  ──> { incident, access_token, conversation_id }
      ├─ guarda token + device_id en SharedPreferences
      └─> EmergencyChatPage
           ├─ Vera abre la conversación con un saludo local (sin tokens)
           ├─ cada turno: Gemini (o protocolo local) responde
           ├─ reenvía la ubicación cada ~24 s (append_emergency_location)
           ├─ si hace falta: dispatch_emergency(...)  (idempotente)
           └─> EmergencyTrackingPage
                ├─ sondeo cada 10 s (get_emergency_status)
                └─ estado, hospital, ambulancia, eventos y llamada al 123
```

Estados del incidente:

```text
created → triaging → dispatched → en_route → on_scene → transporting → resolved
                                                                └────→ cancelled
```

Puntos clave de seguridad:

- El agente tiene instrucciones estrictas: no diagnostica, no receta, no promete
  resultados, no pide datos innecesarios y **despacha en el primer turno** ante
  signos de riesgo vital.
- El despacho es **idempotente** en SQL: repetir la llamada devuelve el estado
  actual en lugar de duplicar ambulancias.
- Si Gemini falla o no hay red, el protocolo local responde con contención,
  primeros auxilios y despacho. La emergencia siempre avanza.
- La ubicación se sigue enviando mientras el incidente esté activo, incluso si
  el usuario no interactúa con el chat.

---

## Modelo de seguridad del modo anónimo

El rol `anon` **no tiene acceso directo** a `emergency_incidents`,
`emergency_locations` ni `emergency_incident_events`. Todo pasa por funciones
`security definer` que exigen un token por incidente:

1. `create_emergency` genera un token aleatorio y devuelve **una sola vez** el
   texto plano junto al `incident_id`.
2. El cliente guarda ambos en `SharedPreferences` y los envía en cada llamada.
3. La base de datos almacena solo `encode(digest(token, 'sha256'), 'hex')` y
   compara hashes.
4. Todas las RPC de emergencia validan `incident_id + token` (helper
   `_assert_emergency_access`) antes de leer o escribir.
5. `device_id` anónimo refuerza la correlación sin exigir cuenta.

Consecuencias:

- Adivinar un `incident_id` no permite leer la ubicación de nadie.
- El token no se puede recuperar desde la base de datos (solo se compara).
- Perder el dispositivo o limpiar los datos implica perder el acceso a ese
  incidente; el seguimiento deja de estar disponible, pero la emergencia ya
  despachada continúa del lado operativo.

Las tablas sensibles se crean con `enable row level security` y se revocan los
permisos de `anon`/`authenticated`; solo las RPC expuestas tienen `grant execute`.

---

## Autenticación: primero invitado

Staydoct es **guest-first**:

| Acción | Requiere cuenta |
| --- | --- |
| Reportar una emergencia, chatear y enviar ubicación | No |
| Ver hospitales cercanos y llamar | No |
| Explorar el catálogo de farmacia | No |
| Agendar cita, cirugía o tratamiento | Sí |
| Comprar medicamentos y ver pedidos | Sí |
| Editar perfil clínico | Sí |

`AuthGate` envuelve las acciones protegidas y muestra el login solo cuando hace
falta. La emergencia nunca se bloquea por autenticación.

---

## Contratos RPC

Definidos en [`supabase/migrations/20260101000200_rpc.sql`](supabase/migrations/20260101000200_rpc.sql).

| RPC | Rol | Entrada | Salida |
| --- | --- | --- | --- |
| `create_emergency` | anon, authenticated | descripción, severidad, lat/lng, dirección, device_id, contacto | `{incident, access_token, conversation_id}` |
| `get_emergency_status` | anon, authenticated | `incident_id`, `access_token` | `{incident, hospital, ambulance, events}` |
| `append_emergency_location` | anon, authenticated | `incident_id`, `access_token`, lat/lng, precisión, dirección | `{ok}` |
| `dispatch_emergency` | anon, authenticated | `incident_id`, `access_token`, severidad, resumen, recomendaciones | `{incident, hospital, ambulance, events}` (idempotente) |
| `log_ai_message` | anon, authenticated | `incident_id`, `access_token`, rol, texto, metadatos | `{message}` |
| `cancel_emergency` | anon, authenticated | `incident_id`, `access_token` | `{ok, status}` |
| `nearby_hospitals` | anon, authenticated | lat, lng, radio km, límite | setof hospitales |
| `book_appointment` | authenticated | doctor, tratamiento, fecha, motivo, tipo, hospital | `{appointment}` |
| `cancel_appointment` | authenticated | `appointment_id` | `{ok}` |
| `place_order` | authenticated | items JSONB, dirección, método de pago | `{order, items}` |

`place_order` valida existencias, calcula el total en el servidor, descuenta
stock y registra el pedido y sus líneas en una sola transacción.

---

## Modelo de datos

Quince tablas en `public`:

| Grupo | Tablas |
| --- | --- |
| Identidad | `profiles` |
| Red de servicios | `hospitals`, `ambulances`, `doctors`, `treatments`, `medicines` |
| Citas | `appointments` |
| Farmacia | `orders`, `order_items`, `prescriptions` |
| Emergencias | `emergency_incidents`, `emergency_locations`, `emergency_incident_events` |
| IA | `ai_conversations`, `ai_messages` |

Detalles relevantes:

- `profiles` se crea con el trigger `handle_new_user` al registrarse.
- `appointments` usa el tipo `appointment_type` (`consultation`, `surgery`,
  `treatment`) y el estado `appointment_status`.
- `prescriptions` marca qué medicamentos requieren receta; el catálogo y los
  pedidos guardan la referencia.
- `emergency_incidents` guarda severidad, estado, resumen, recomendaciones y el
  hash del token de acceso.
- Triggers `set_updated_at` mantienen `updated_at` en las tablas mutables.

---

## IA conversacional y voz

### Gemini

- Gemini se invoca desde una Supabase Edge Function; la clave nunca se incluye
  en el cliente Android.
- Function calling con una única herramienta, `dispatch_emergency_services`
  (`severity`, `summary`, `recommendations`, `needs_ambulance`).
- El prompt del sistema vive en
  [`prompt_builder.dart`](lib/features/ai_chat/data/prompt_builder.dart) y
  incluye reglas de primeros auxilios y de seguridad.
- Antes del primer mensaje se pregunta si se permite enviar el chat a Gemini;
  sin consentimiento, se usa solo el protocolo local. La ubicación GPS no se
  añade a la solicitud Gemini. Al usar el micrófono con Gemini, Flutter pide
  un token temporal a la Edge Function y transmite audio PCM mono de 16 kHz a
  Gemini Live; reproduce las respuestas PCM mono de 24 kHz. El micrófono se
  cierra al detener la sesión.
- El chat escrito conserva el timeout de 30 s y el protocolo local como
  alternativa. Si Live no conecta, la app informa el problema y recurre al
  dictado estándar.

### Protocolo local de respaldo

`LocalTriageAssistant` es un motor de reglas que detecta patrones críticos
(dolor de pecho, dificultad respiratoria, sangrado, inconsciencia, derrame,
convulsión, parto, trauma, ideación suicida) y responde con contención,
instrucciones seguras y una solicitud de despacho. Garantiza que el flujo de
emergencia funcione incluso sin clave, sin red o con cuota agotada.

### Voz

`GeminiLiveAudioDataSource` transmite audio PCM directamente entre el micrófono
y Gemini; `SpeechService` mantiene el dictado local de respaldo y el TTS para
respuestas escritas:

- dictado en español (`es_ES`) con cierre por pausa de 4 s;
- lectura en voz alta de las respuestas de la IA (recortadas a 900 caracteres);
- si el dispositivo no soporta voz, la app sigue funcionando por texto.

---

## Mapas

`EmergencyMap` muestra un mapa de Google con marcadores del incidente, hospital y
ambulancia. Si no hay clave, renderiza un panel informativo con las coordenadas
en lugar de un mapa vacío.

| Plataforma | Configuración |
| --- | --- |
| Android | `-PGOOGLE_MAPS_API_KEY=...` → placeholder `com.google.android.geo.API_KEY` en el manifest |
| iOS | `GOOGLE_MAPS_API_KEY` en `ios/Flutter/Debug.xcconfig` y `Release.xcconfig` → `GMSApiKey` en `Info.plist` |
| Web | Descomentar el `<script>` de Maps en `web/index.html` y poner la clave |

Permisos ya declarados:

- Android: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION`,
  `ACCESS_COARSE_LOCATION`, `RECORD_AUDIO`.
- iOS: `NSLocationWhenInUseUsageDescription`,
  `NSLocationAlwaysAndWhenInUseUsageDescription`,
  `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`.

---

## Pruebas y calidad

```bash
flutter analyze   # 0 errores, 0 warnings, 0 infos
flutter test      # 21 pruebas
```

La suite cubre formateo, validaciones, el carrito (incluido el límite de stock)
y el parseo JSON de entidades (medicinas, hospitales, pedidos, citas y
tratamientos). El análisis estático está limpio.

> En este entorno el binario de Flutter está en
> `/home/princesa/Escritorio/flutter/bin/flutter` (no está en `PATH`).

---

## Cumplimiento, privacidad y límites

- **Staydoct no es un dispositivo médico** y no sustituye la valoración de un
  profesional. La IA ofrece orientación de primeros auxilios, no diagnósticos.
- **Distribución por GitHub**: al entregar un APK directamente no se completa
  la declaración de salud de Play Console. Si luego se publica en Play, esa
  declaración es obligatoria también para pruebas cerradas; selecciona las
  categorías que correspondan a emergencias, servicios de salud y farmacia.
- **Datos de ubicación**: son datos sensibles. El modo anónimo los protege con
  token por incidente, hash SHA-256 y RLS; no se exponen por la API REST.
- **Datos enviados a proveedores**: los mensajes y la descripción de la
  emergencia se procesan con Gemini para generar respuestas. La ubicación se
  envía a Supabase para gestionar el incidente, pero no se incluye en la
  solicitud a Gemini. Antes del primer envío del chat se informa al usuario y
  se le permite continuar con Gemini o usar solo el protocolo local. La
  conversación también se almacena en el registro del incidente de Supabase.
  Al usar voz con Gemini, el audio se envía en tiempo real a Google y las
  transcripciones se almacenan en el registro de la conversación; Staydoct no
  guarda el audio crudo en Supabase. Al usar el modo local, el audio se procesa
  con el servicio de dictado del dispositivo. Declara ambos tratamientos en
  la política de privacidad y en Seguridad de datos.
- **Política de privacidad**: publica una URL accesible y no autenticada que
  describa datos recogidos, ubicación, micrófono/dictado, historial, Gemini,
  Supabase, conservación, contacto del responsable y eliminación de datos.
  Si se publica en Play, añade esa URL en Play Console y completa Seguridad de
  datos con información coherente con la política y el comportamiento real.
- **Cuenta y eliminación de datos**: el perfil actual solo permite cerrar
  sesión. Para Play, implementa la eliminación de cuentas/datos desde la app y
  publica un enlace web para solicitarla. No declares que hay eliminación
  hasta que el flujo funcione.
- **Identificador Android**: los APK ahora usan `app.staydoct.mobile`. Si luego
  publicas en Google Play, confirma que ese ID esté disponible y no lo cambies
  después de distribuir la app.
- **Recetas**: el esquema marca `prescriptions.requires_prescription`, pero el
  checkout actual **no bloquea** la compra de medicamentos que la requieren.
  Antes de un despliegue real hay que:
  1. validar la receta en `place_order`, y
  2. revisar la normativa farmacéutica aplicable (por ejemplo, INVIMA en
     Colombia).
- **Consentimiento y retención**: define política de retención de incidentes y
  conversaciones, y avisa al usuario de que su ubicación se comparte con los
  servicios de emergencia.
- **Claves**: `GEMINI_API_KEY` debe permanecer como secreto de Supabase.
  `GOOGLE_MAPS_API_KEY` es una clave de cliente y debe restringirse en Google
  Cloud al ID de paquete y a las APIs usadas.

---

## Roadmap

- [ ] Validación de receta y cumplimiento farmacéutico en `place_order`.
- [ ] Notificaciones push para cambios de estado de la emergencia y del pedido.
- [ ] Panel operativo (despachador) para hospitales y ambulancias.
- [ ] Historial clínico y adjuntar documentos al perfil.
- [ ] Integración con pasarela de pagos real.
- [ ] Localización de la UI (español/inglés) con `flutter_localizations`.
- [ ] Pruebas de integración del flujo SOS completo.
- [ ] Integración con el sistema local de emergencias (más allá de la llamada
      al 123).
