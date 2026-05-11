# Jornada

Menú bar app de control horario para macOS. Registra jornadas laborales por día con segmentos de tiempo, proyectos, y estadísticas semanales.

## Características

- **Temporizador** con control iniciar/pausar/reanudar y progreso visual
- **Periodos por día** almacenados como componentes hora/minuto (sin problemas de timezone)
- **Proyectos por periodo** — cada segmento puede tener un proyecto distinto
- **Editor semanal** — vista de 7 días para editar, añadir o borrar periodos manualmente
- **Gráfico semanal** con barras trabajadas vs línea del horario programado
- **Alertas configurables** con sonido al acercarse al fin de la jornada
- **Horario semanal configurable** (horas por día, días laborables)
- **Persistencia en JSON** — datos almacenados en `~/Library/Application Support/Jornada/entries.json`
- **Importar/Exportar CSV** para backup o migración
- **Validaciones** — solapamiento de periodos, fin posterior a inicio, duración futura = 0

## Requisitos

- macOS 14.0+
- Xcode 15+ o Swift 5.9+ (`swift build`)

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
- **Iniciar** — comienza un nuevo periodo
- **Pausar** — detiene el periodo actual (el tiempo cuenta hasta el momento de pausa)
- **Reanudar** — continúa el periodo anterior
- **Finalizar** — detiene el periodo y no permite reanudar sin crear uno nuevo

### Editor de periodos

Desde el popover principal, pulsa el icono de expandir (esquina superior derecha de "Periodos de hoy") para abrir el editor semanal. Aquí puedes:

- Ver todos los días de la semana con sus periodos
- Editar horas de inicio y fin de cada periodo
- Añadir nuevos periodos con el botón `+`
- Asignar proyecto a cada periodo
- Borrar periodos con el botón ✗
- Navegar entre semanas con las flechas

### Gestión de periodos futuros

Puedes añadir periodos en el futuro (ej: una reunión prevista a las 15:00). Cuando el temporizador real alcance ese horario y se detenga, el periodo futuro que solape con el tramo real se eliminará automáticamente para evitar duplicidad.

## Estructura del proyecto

```
Sources/Jornada/
├── Design/DS.swift              # Constantes de diseño (espaciado, fuentes, colores)
├── Models/
│   ├── TimeEntry.swift          # WorkSegment (hora/minuto) y TimeEntry
│   └── ScheduleConfig.swift     # Configuración de horario semanal
├── Services/
│   └── StorageService.swift     # Persistencia JSON + import/export CSV
├── Managers/
│   ├── TimerManager.swift       # Lógica del temporizador y edición
│   └── ScheduleManager.swift    # Gestión del horario
└── Views/
    ├── MenuBarPopover.swift     # Punto de entrada con tabs
    ├── TimerView.swift          # Temporizador + periodos de hoy
    ├── PeriodEditorView.swift   # Editor semanal de periodos
    ├── HistoryView.swift        # Gráfico semanal + import/export
    └── SettingsView.swift       # Horario, alertas, borrar datos
```

## Licencia

MIT
