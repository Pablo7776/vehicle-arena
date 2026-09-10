# Vehicle Arena

Multiplayer 3D — Deathmatch vehicular. 2 a 4 jugadores online compiten en una arena cerrada para conseguir la mayor cantidad de eliminaciones antes de que termine el tiempo de partida.

## Ficha técnica

- **Género:** Multiplayer 3D — Deathmatch vehicular
- **Jugadores:** 2–4 online
- **Plataforma:** PC (posible adaptación futura a Android)
- **Motor:** Godot 4.7.2

## Requisitos

- [Godot Engine 4.7.2](https://godotengine.org/download) (versión estándar, sin .NET salvo que se decida usar C#)
- Git

## Cómo levantar el proyecto

1. Cloná el repositorio:
   ```bash
   git clone https://github.com/<usuario>/<repo>.git
   cd vehicle-arena
   ```
2. Abrí Godot 4.7.2 y usá **Import**, seleccionando el archivo `project.godot` en la raíz del proyecto.
3. Esperá a que el editor importe los assets (se genera la carpeta local `.godot/`, no versionada).
4. Corré el proyecto con F5. La escena principal se configura en Project Settings → Application → Run.

## Estructura de carpetas

```
vehicle-arena/
├── addons/              # Plugins de terceros
├── assets/              # Modelos, texturas, materiales, audio, fuentes
├── scenes/              # Escenas (.tscn) organizadas por área
│   ├── main/            # Escena principal / gestor de cambio de escenas
│   ├── menu/             # Menú y lobby (crear/unirse a partida)
│   ├── arena/            # Arena de juego
│   ├── vehicle/           # Vehículo del jugador
│   ├── weapons/           # Arma y proyectiles
│   ├── ui/                # HUD, scoreboard, pantalla de resultados
│   └── effects/           # Partículas, explosiones, etc.
├── scripts/              # Scripts sin escena asociada
│   ├── autoload/          # Singletons (NetworkManager, GameManager, etc.)
│   ├── vehicle/
│   ├── weapons/
│   ├── networking/         # RPCs y helpers de sincronización
│   └── ui/
├── resources/             # Recursos .tres (stats de vehículos, configs)
├── docs/                  # One-page, GDD y notas de diseño
└── builds/                # Exportaciones del juego (NO se versiona)
```

> Nota: cada escena vive junto a su script correspondiente dentro de `scenes/`. La carpeta `scripts/` se usa solo para autoloads (singletons) y utilidades sin escena propia.

## Flujo de juego

```
Menú → Crear/Unirse a partida → Arena → Combate → Fin de partida → Resultados
```

## Arquitectura de red

- API de multiplayer de alto nivel de Godot (`MultiplayerAPI`, `MultiplayerSynchronizer`, `MultiplayerSpawner`).
- Transporte: `ENetMultiplayerPeer`.
- Modelo host-peer: un jugador actúa como host/servidor con autoridad sobre daño, eliminaciones, puntuación y estado de partida.
- Los clientes envían input/acciones y reciben el estado sincronizado.

## Roadmap de implementación

1. Lobby básico + conexión de 2 jugadores (sin gameplay)
2. Movimiento del vehículo sincronizado (sin combate)
3. Disparo y daño con autoridad del servidor
4. Vida, destrucción y respawn
5. Puntuación, timer y pantalla de fin de partida
6. Arena final con obstáculos y pulido

## Documentación

El one-page de diseño y otras notas están en [`docs/`](./docs).

## Equipo

- Desarrollador 1 — Gameplay local (movimiento, cámara, disparo, arena, UI)
- Desarrollador 2 — Networking (sincronización, RPCs, lobby, estado de partida)