Vehicle Arena

Juego multijugador de combate de vehículos hecho con Godot 4.7. Los jugadores manejan vehículos en una arena, se disparan entre sí y gana el último que queda con vida.

Tecnologías y créditos
Godot Engine 4.7.2
GD-Sync: plugin que se usa para todo el multijugador (lobbies, sincronización de propiedades y llamadas remotas).
Godot Settings and Menu System de selodev: plugin que se usa para los menús y la configuración del juego.

Cómo jugar
Un jugador crea la sala y los demás se unen.
Cada jugador maneja su vehículo y dispara a los demás.
Si la vida llega a 0, el vehículo queda fuera de combate.
Gana el último vehículo que quede vivo. Al terminar, cada jugador ve ¡VICTORIA! o DERROTA.
Hay ítems de curación que reaparecen en puntos al azar de la arena.

Cómo ejecutarlo
Instalá Godot 4.7.2.
Abrí el proyecto desde el administrador de proyectos de Godot.
Verificá que los plugins estén activados en Proyecto → Configuración del proyecto → Plugins.
Ejecutá el juego. Para probar el multijugador, abrí dos instancias (Depurar → Ejecutar múltiples instancias) o exportá una build.
Cómo funciona la red

El host tiene la autoridad sobre la vida y sobre quién gana. El dueño (owner) de cada vehículo controla su movimiento y sus disparos.

Qué	Quién decide	Cómo se comunica
Vida (current)	El host	PropertySynchronizer
Daño recibido	El cliente avisa, el host lo valida y lo aplica	call_func_on al host + DamageValidator
Movimiento y disparo	El owner del vehículo	Solo él ejecuta la lógica
Balas	Cada peer crea su copia	call_func (solo viaja posición y dirección del disparo)
Recoger un ítem	Quien lo recoge	call_func (evento)
Ganador	El host	call_func a todos

Regla para recordar
Un valor que cambia y todos deben tener igual → PropertySynchronizer.
Algo que pasa una sola vez (un disparo, recoger un ítem) → call_func.
Detalle importante de GD-Sync en este proyecto

Con la versión usada, los parámetros de call_func / call_func_on llegan empaquetados en un solo Array al receptor. Por eso las funciones remotas reciben data y lo desarman (data[0], data[1]...).



Componentes reutilizables
HealthComponent: vida del objeto. Incluye su propio PropertySynchronizer y un DamageValidator opcional. Se puede usar en vehículos, en el TargetDummy o en cualquier objeto.
Hurtbox: zona que recibe golpes y los reenvía al HealthComponent. Tiene un multiplicador de daño configurable.
Hitbox: base de las balas. Detecta el Hurtbox y le envía el golpe.
DamageValidator: el host limita el daño máximo y la cadencia de golpes.
GameManager: vive en la arena. El host revisa cuántos vehículos quedan vivos y avisa el resultado a todos.
