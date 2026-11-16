# Forge: tu sistema operativo personal de transformación

App nativa para iPhone hecha con **SwiftUI + SwiftData + Swift Charts** (iOS 17+). Sin cuenta, sin servidores: todo queda en tu teléfono.

## Diseño

Paleta "papel y tinta": fondo crema claro, tarjetas blancas, texto casi negro y un único acento verde salvia. Tipografía SF Pro (livianos en los números). Animaciones suaves: las tarjetas entran con fade, los anillos y barras se llenan al aparecer, los números cambian con transición. Para cambiar el color de toda la app: `Design/Theme.swift` (`orange`, `deepOrange`, `yellow` — los nombres vienen de la primera versión).

## Cómo correrla en tu iPhone

Necesitás una Mac con **Xcode 16 o superior** (gratis en la App Store) y un cable para el iPhone.

1. Descomprimí el zip y abrí `Forge.xcodeproj`.
2. Elegí el target **Forge** > pestaña **Signing & Capabilities**.
   - Marcá *Automatically manage signing*.
   - En **Team** elegí tu Apple ID (si no aparece: Xcode > Settings > Accounts > `+`).
   - Cambiá el **Bundle Identifier** a algo único, por ejemplo `com.tunombre.forge`.
3. Conectá el iPhone, desbloquealo y tocá *Confiar*. Elegilo como destino arriba en Xcode.
4. En el iPhone activá **Ajustes > Privacidad y seguridad > Modo desarrollador** y reiniciá.
5. Apretá **Run (▶)**. La primera vez, en el iPhone: *Ajustes > General > VPN y gestión de dispositivos* > confiá en tu Apple ID.

Con un Apple ID gratuito la app vence a los 7 días: se reinstala con ▶ y **no perdés los datos** si no la borrás del teléfono. Para que no venza hace falta el Apple Developer Program (US$ 99/año).

**Probar sin iPhone:** elegí un simulador (iPhone 15/16) y apretá ▶. La cámara no existe en el simulador, pero la galería sí.

**Si usás Xcode 15:** el proyecto usa carpetas sincronizadas (Xcode 16). Creá un proyecto nuevo *iOS > App* (SwiftUI, Storage: None), borrá `ContentView.swift` y `…App.swift`, arrastrá todo el contenido de la carpeta `Forge/` al proyecto, y en el target poné iOS 17.0. Agregá en *Info* las claves de cámara, Face ID y fotos (ver abajo).

Alternativa: `brew install xcodegen && xcodegen` genera el proyecto desde `project.yml`.

## Sin Mac: compilar en GitHub y instalar desde Windows

1. Creá una cuenta en github.com y un repositorio nuevo (privado está bien).
2. Subí **el contenido** de esta carpeta (que `Forge.xcodeproj` y `.github` queden en la raíz del repo). En la web: *Add file > Upload files*, arrastrando todo. Si no sube `.github`, creá a mano el archivo `.github/workflows/build-ipa.yml` con *Add file > Create new file* y pegá su contenido.
3. Pestaña **Actions** > *Build IPA* > **Run workflow**. Tarda unos 5-10 minutos.
4. Cuando termine, entrá a la corrida y bajá el artefacto **Forge-ipa** (zip con `Forge.ipa` adentro).
5. Instalá **Sideloadly** en la PC (con iTunes e iCloud de la web de Apple, no de la Microsoft Store), conectá el iPhone, arrastrá `Forge.ipa`, poné tu Apple ID y tocá *Start*.
6. En el iPhone: *Ajustes > General > VPN y gestión de dispositivos* > confiá en tu Apple ID, y activá el Modo desarrollador.

Se reinstala cada 7 días. Si el build falla, bajá el artefacto `build-log` y pasáselo a Claude.

## Qué incluye

| Área | Qué hay |
|---|---|
| **Home** | Fecha, saludo, mensaje diario, versículo del día, anillos de calorías/proteína/agua, acciones rápidas (comida, peso, entrenar, foto, agua, hábito, sueño), widget del Transformation Score, entrenamiento de hoy, hábitos, peso, resumen semanal |
| **Nutrición** | Desayuno/almuerzo/cena/snack, búsqueda en ~65 alimentos de referencia, alimentos propios, gramos o porciones, entrada manual, editar/borrar, comidas favoritas, macros + fibra, metas por objetivo (ganar / mantener / perder), agua con botones rápidos, historial semanal |
| **Training** | Rutinas por día, plantillas (hipertrofia, fuerza, rugby, MMA, lucha, cardio, acondicionamiento), sesión rápida de gym (series, reps, kg, calentamiento, notas, temporizador de descanso con notificación), récords, volumen, historial y gráfico por ejercicio |
| **Movilidad** | 8 rutinas guiadas con temporizador (mañana, noche, cuello, hombros, caderas, isquios, espalda, recuperación), rutinas propias, registro manual, constancia semanal |
| **Progreso** | Peso y 8 medidas con gráficos, **fotos** (cámara o galería, frente/perfil/espalda, notas, colecciones, línea de tiempo, **comparador antes/después con slider**, exportar, borrar) |
| **Hábitos y suplementos** | 8 hábitos por defecto + propios, rachas, estadística semanal, hábitos que se completan solos desde otros datos, suplementos con dosis, días y recordatorio |
| **Biblia** | 40 versículos reales (versión KJV, dominio público) con referencia y reflexión corta, favoritos, biblioteca por tema, historial |
| **Diario** | Entradas diarias con ánimo, logros, mejoras, reflexión, prompts opcionales, favoritas, calendario y búsqueda |
| **Hitos** | Metas medibles (suben o bajan), progreso automático (peso, mejor levantamiento, entrenos del mes), galería de completados, animación sobria |
| **Transformation Score** | 0–100 diario/semanal/mensual, anillos por área, "necesita atención", evolución, personalizable |
| **Calendario y reportes** | Navegás por días pasados y ves todo; reportes semanal y mensual con 7 gráficos |
| **Perfil / Privacidad** | Onboarding, metas editables, recordatorios locales, bloqueo con Face ID, exportar todo a `.zip` (JSON + fotos), borrar todo |

Cómo se calcula el score: partial credit, el 90 % de una meta cuenta como completa, y los períodos mezclan nivel promedio (70 %) con días consistentes (30 %, un día ≥ 60 es consistente). Es una medida de constancia personal, no de salud.

## Arquitectura

```
Forge/
  App/        ForgeApp (contenedor SwiftData), RootView (onboarding / bloqueo / tabs), AppState
  Design/     Theme (paleta, tipografía, claro/oscuro), Components (tarjetas, anillos, botones…)
  Models/     @Model de SwiftData (sin relaciones; se enlazan por UUID → compatible con CloudKit)
  Services/   ScoreEngine, PhotoStore, NotificationService, AppLock, BackupService, datos semilla, Biblia
  Features/   Home, Nutrition, Training, Progress, Profile, Habits, Bible, Journal, Milestones, Score, Calendar
```

- Los datos viven en SwiftData (SQLite en Application Support). Las fotos son archivos JPEG en `Application Support/ProgressPhotos` (nunca en caché), así que sobreviven a reinicios.
- Las listas de alimentos y los versículos son contenido de referencia; no hay datos de usuario falsos. Los valores nutricionales son aproximados: revisá las etiquetas o creá un alimento propio.

## Permisos

Se piden solo cuando hacés la acción: cámara (foto de progreso), Face ID (bloqueo opcional), notificaciones (recordatorios), y guardar en fotos (si exportás una imagen). Elegir de la galería usa `PhotosPicker` y no pide permiso.

## iCloud (opcional)

Requiere cuenta de pago. En Xcode: *Signing & Capabilities > + Capability > iCloud > CloudKit*, creá un contenedor, y poné `enableCloudKitSync = true` en `App/AppState.swift`. Las copias de seguridad cifradas del iPhone/iCloud ya incluyen la app aunque no actives esto.

## Importante: estado de verificación

El código fue escrito sin poder compilar (el entorno de desarrollo no tiene Xcode): se revisó la **sintaxis** de los 35 archivos Swift, pero **no se compiló ni se probó en un dispositivo**. Es probable que Xcode marque algún error de tipos al primer Build. Son arreglos de una línea: pegale el mensaje a Claude y se corrige.

## Lo que queda para una próxima versión

- **HealthKit** (pasos, sueño, peso desde Salud): previsto, no incluido.
- **Widget de pantalla de inicio** (WidgetKit): el widget del score existe dentro de la app, no en la pantalla de inicio.
- **Restaurar un backup** importando el `.zip`: hoy se exporta, pero no se reimporta.
- Unidades imperiales (lb / in): hoy kg y cm.
- Búsqueda de alimentos online / código de barras: la base es local y limitada.
- Ícono y nombre definitivos (el ícono es provisional).
