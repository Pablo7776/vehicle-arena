# Vehicle Arena — Cazá al jabalí

Juego multijugador en red hecho con **Godot 4.7** y **GD-Sync**, para PC, Android y Web.

Hasta 4 jugadores manejan karts por una arena y compiten para **cazar a un jabalí** controlado por IA. Tienen **3 minutos**: el primero que lo caza gana. Si se acaba el tiempo, **el jabalí se escapa** y pierden todos.

---

## Cómo se juega

1. Un jugador **crea una sala** con un nombre y los demás **se unen** escribiendo el mismo nombre.
2. En la **sala de espera** cada uno escribe su nombre y marca **Listo**. Cuando están todos listos (mínimo 2), el host aprieta **Empezar**.
3. Cada jugador aparece en su propio punto de la arena. Arranca el reloj de **3:00**.
4. El jabalí deambula, **huye** cuando un kart se acerca y a veces **embiste** para sacarte de posición. Hay que dispararle hasta bajarle la vida a 0.
5. El que da el **último golpe** lo caza y gana. Si el reloj llega a 0, el jabalí se escapa.
6. El host aprieta **Volver a la sala** y vuelven todos a la sala de espera para otra ronda.

Los karts **no se hacen daño entre ellos**: la competencia es por llegar primero al jabalí. Hay un **ítem de munición** (+15 balas) que reaparece en puntos al azar.

### Controles

| Acción | PC | Android |
|---|---|---|
| Acelerar | `W` | Tocar y mantener la pantalla (fuera del joystick) |
| Frenar / marcha atrás | `S` (al detenerse, sigue en reversa) | **Doble toque y mantener** |
| Girar | `A` / `D` | Inclinar el celular (acelerómetro) |
| Disparar | `Espacio` (hacia adelante) | Joystick derecho (apuntar y soltar) |

---

## Cómo ejecutarlo

1. Instalá **Godot 4.7.2**.
2. Abrí el proyecto (`vehicle-arena/project.godot`) desde el administrador de proyectos.
3. Verificá que los plugins estén activados en **Proyecto → Configuración del proyecto → Plugins**: GD-Sync, Settings & Menus. LimboAI es una extensión y carga sola.
4. Para probar en red: **Depurar → Personalizar ejecución de instancias → 2** (o más) y ejecutá. Una instancia crea la sala y las otras se unen con el mismo nombre.
5. El botón **Test** del menú (solo aparece al ejecutar desde el editor) arranca la arena sin conexión, para probar rápido sin red.
6. **F1** o el botón **LOG** (arriba a la derecha) muestran en pantalla los mensajes de la consola.

---

## Flujo de la partida

```
Menú ──Crear / Unirse──▶ Sala de espera ──todos Listo + host Empezar──▶ Partida (3:00)
  ▲                          ▲                                              │
  └──── Salir de la sala ────┘◀──────── host: Volver a la sala ◀── Resultado ┘
```

Al empezar, el host **cierra la sala** (nadie más entra con la partida en curso). Al volver, la **reabre** y todos quedan en "no listo".

---

## Cómo funciona la red

Se usa **GD-Sync**, que maneja la conexión, las salas (lobbies), la sincronización de propiedades y las llamadas remotas. Toda la lógica de red del juego está en el autoload **`NetworkManager`**: las pantallas (menú, sala de espera) solo llaman a sus funciones y escuchan sus señales.

### La regla de autoridad

- **El host decide el estado del mundo**: el jabalí, su vida, quién lo cazó, el ítem de munición, el reloj y el resultado.
- **El dueño de cada kart decide su propio kart**: su movimiento y sus disparos. Así su kart responde sin retraso en su pantalla.

### Qué decide cada uno y cómo viaja

| Qué | Quién decide | Cómo viaja |
|---|---|---|
| Posición y giro de cada kart | El **dueño** del kart | `PropertySynchronizer` (*When Owner*, interpolado) |
| IA, posición y estado del jabalí | El **host** (la IA solo corre ahí) | `PropertySynchronizer` (*When Host*, interpolado) |
| Vida del jabalí | El **host** | `PropertySynchronizer` del `HealthComponent` (*When Host*) |
| Disparo | El **dueño** del kart | `call_func` a todos: cada uno crea su copia de la bala |
| Daño de una bala | La **detecta** quien disparó; el **host** la **valida y aplica** | `call_func_on(host, [daño, atacante])` + `DamageValidator` |
| Recoger el ítem de munición | El **host** (solo él detecta, con un flag); las balas se las suma el **dueño** del kart | `call_func` con el punto de reaparición + `call_func_on(dueño, balas)` |
| Embestida del jabalí | La **decide** el host; la **ejecuta** el dueño del kart | `call_func_on(dueño, impulso)` |
| Quién cazó al jabalí / fin por tiempo | El **host** | `call_func` a todos con el resultado |
| Cuenta regresiva | Todos la **muestran**; solo el reloj del **host** termina la partida | — |
| Nombre y "Listo" de cada jugador | Cada **jugador** los suyos | Datos del jugador (`player_set_username`, `player_set_data`) |
| Empezar / volver a la sala | El **host** | `call_func` + `lobby_close` / `lobby_open` |
| Punto de aparición | Nadie: todos lo **calculan igual** (IDs ordenados) | — |

### Tres reglas que usamos

- **Estado** (algo que todos tienen que ver igual y que cambia): lo escribe **uno solo** y viaja con un `PropertySynchronizer`.
- **Evento** (algo que pasa una vez: un disparo, recoger un ítem, el resultado): `call_func`.
- **Intención** del jugador que cambia el mundo (le pegué al jabalí): se le **pide al host**, que valida y decide.

### Detalle de GD-Sync

`call_func` y `call_func_on` reciben los parámetros como *variadic*: si se pasa un Array (`[pos, dir]`), al receptor le llega **un solo** Array. Por eso las funciones remotas reciben `data` y lo desarman (`data[0]`, `data[1]`...).

---

## Decisiones de diseño

- **Sin daño entre karts.** Las balas solo detectan la capa del jabalí (los karts están en otra capa). La partida es una carrera por cazarlo, no un deathmatch.
- **Sin muerte ni respawn de jugadores.** Nadie queda afuera mirando: todos juegan los 3 minutos.
- **La embestida empuja pero no quita vida**, porque los karts no tienen vida que perder. El empujón te saca de posición y te hace perder tiempo.
- **Solo el host vuelve a la sala**, para que todos vuelvan juntos y nadie quede con una partida vieja mientras empieza otra.
- **La munición no viaja por red.** La lleva cada dueño en su máquina: es información propia y nadie más la necesita.
- **No se puede entrar con la partida empezada**, porque la sala se cierra. Así nadie se encuentra un ítem o un jabalí en un estado que no conoce.
- **Las funciones remotas que deciden cosas solo las puede llamar el host** (`expose_func(..., EXPOSE_PERMISSION.HOST)`): un cliente no puede anunciar un resultado, empezar la partida ni darse balas.
- **Si el host se va**, GD-Sync elige otro y el juego sigue: la IA del jabalí, el reloj y el botón "Volver a la sala" pasan al nuevo host.

---

## Estructura del proyecto

```
vehicle-arena/
├── autoloads/        NetworkManager (red y salas) y ConsolaPantalla (log en pantalla)
├── ai/               Tareas y árbol de comportamiento del jabalí (LimboAI)
├── scenes/
│   ├── arena/        La arena: terreno, puntos de aparición, ítem, límites
│   ├── game/         game_manager: reglas de la partida, reloj y resultado
│   ├── main/         La partida: arena + jabalí + navegación + luces
│   ├── player/       Lo del jugador humano: cámara, controles, cartel, apuntado
│   ├── vehicle/      El kart: física, freno/reversa, entrada
│   ├── target_dummy/ El jabalí
│   ├── components/   Componentes reutilizables (vida, golpes, arma)
│   ├── bullets/      La bala
│   ├── items/        Ítem de munición
│   ├── hud/          HUD de munición y joystick
│   ├── sala_espera/  Sala de espera (lobby)
│   ├── camera/  audio/  debug/  entorno/  pasto/
│   └── menu.tscn     Escena principal
├── assets/           Modelos, texturas, fuentes y audio
└── addons/           GD-Sync, LimboAI, Settings & Menus
```

Cada script vive al lado de la escena que lo usa.

### Componentes reutilizables

- **HealthComponent**: vida de un objeto. Incluye su propio `PropertySynchronizer` (*When Host*) y guarda en el host quién dio el último golpe (`ultimo_atacante`). Lo usan los karts y el jabalí.
- **Hurtbox**: zona que recibe golpes y se los pasa al `HealthComponent`, junto con quién los dio. Tiene un multiplicador de daño.
- **Hitbox**: base de las balas. Detecta un `Hurtbox` y le envía el golpe.
- **DamageValidator**: el host limita el daño máximo y la cadencia de golpes de cada atacante.
- **Weapon**: arma del kart. Es la única que crea balas (teclado y joystick llaman a `shoot()`) y maneja la munición y la cadencia.

---

## Limitaciones conocidas

- La cuenta regresiva corre en cada máquina, así que puede diferir en una fracción de segundo. No afecta el resultado: lo decide el reloj del host.
- Como el host decide sobre el ítem de munición, el jugador que no es host nota un mínimo retraso entre tocarlo y verlo desaparecer.
- En PC solo se dispara hacia adelante; el apuntado libre está en el joystick de Android.
- El menú principal todavía usa el plugin Settings & Menus.

---

## Tecnologías y créditos

- **Godot Engine 4.7.2**, con física **Jolt**.
- **GD-Sync** 1.0.2: conexión, lobbies, sincronización de propiedades y llamadas remotas.
- **[LimboAI](https://github.com/limbonaut/limboai)** 1.8.1: árboles de comportamiento para la IA del jabalí.
- **Godot Settings and Menu System** (selodev) 1.8.1: menú principal y configuración.
- Assets: *Hypno's Fantasy Village Pack* (escenario), modelo de kart, modelo de llave ajustable, fuentes *Badaboom*, *A Dripping Marker* y *From Cartoon Blocks*.
- Tutoriales consultados: [`docs/extras/tutorialesUsados.md`](vehicle-arena/docs/extras/tutorialesUsados.md).
