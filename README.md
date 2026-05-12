# Jornada

Menú bar app de control horario para macOS. Registra jornadas laborales por día con segmentos de tiempo, proyectos, y estadísticas semanales.

## Características

- **Temporizador** con control iniciar/detener y progreso visual
- **Periodos por día** como segmentos independientes — cada "Iniciar" crea un tramo nuevo
- **Proyectos por periodo** — cada segmento puede tener un proyecto distinto
- **Editor semanal** — vista de 7 días para editar, añadir o borrar periodos manualmente
- **Gráfico semanal** con barras trabajadas vs línea del horario programado
- **Alertas configurables** con sonido al acercarse al fin de la jornada
- **Horario semanal configurable** (horas por día, días laborables)
- **Persistencia JSON atómica** — escritura temp → backup → main, con restauración automática desde backup
- **Importar/Exportar CSV** para backup o migración
- **Internacionalización** — español e inglés, con detección automática del idioma del sistema
- **Accesibilidad** — etiquetas VoiceOver en temporizador, progreso y botones
- **Validaciones** — solapamiento de periodos, fin posterior a inicio, cruce de medianoche

## Requisitos

- macOS 14.0+
- Swift 5.10+ (`swift build`) o Xcode 16+

## Instalación

### Desde DMG

1. Descarga `Jornada.dmg` del [último release](https://github.com/fracergu/jornada/releases)
2. Abre el DMG y arrastra Jornada a Applications
3. La primera vez macOS puede bloquear la app: ve a Ajustes > Privacidad y seguridad y pulsa "Abrir de todos modos"

### Desde código

```bash
git clone https://github.com/fracergu/jornada.git
cd jornada
swift build -c release
./build.sh
```

## Uso

### Control del temporizador

- **Click izquierdo** en el icono de la barra de menú → abre el popover
- **Click derecho** → menú contextual con Iniciar/Detener
- **Iniciar** — comienza un nuevo segmento de trabajo
- **Detener** — finaliza el segmento actual
- Cada segmento es independiente: puedes iniciar y detener tantas veces como quieras

### Editor de periodos

Desde el popover principal, pulsa el icono de expandir (esquina superior derecha de "Periodos de hoy") para abrir el editor semanal. Aquí puedes:

- Ver todos los días de la semana con sus periodos
- Editar horas de inicio y fin de cada periodo
- Añadir nuevos periodos con el botón `+`
- Asignar proyecto a cada periodo
- Borrar periodos completados con el botón ✗
- Navegar entre semanas con las flechas

## Tests

```bash
swift test
```

Ejecuta 11 tests unitarios del modelo de datos (WorkSegment, TimeEntry, ScheduleConfig, EntryRepository) usando swift-testing.

## Estructura del proyecto

```
Sources/Jornada/
├── Design/DS.swift              # Constantes de diseño (espaciado, fuentes, colores)
├── Models/
│   ├── TimeEntry.swift          # WorkSegment (hora/minuto con fecha base) y TimeEntry
│   └── ScheduleConfig.swift     # Configuración de horario semanal
├── Services/
│   ├── EntryRepository.swift    # Protocolo EntryRepository + JSONFileRepository atómico
│   ├── StorageService.swift     # Sólo utilidades CSV (import/export)
│   └── AlertService.swift       # Lógica de alertas sonoras
├── Managers/
│   ├── TimerController.swift    # Máquina de estados del temporizador
│   ├── EntryEditor.swift        # Edición de entradas históricas
│   └── ScheduleManager.swift    # Gestión del horario semanal
└── Views/
    ├── MenuBarPopover.swift     # Punto de entrada con tabs
    ├── TimerView.swift          # Temporizador + periodos de hoy
    ├── PeriodEditorView.swift   # Editor semanal de periodos
    ├── HistoryView.swift        # Gráfico semanal + import/export
    └── SettingsView.swift       # Horario, alertas, borrar datos
```

## Licencia

MIT
