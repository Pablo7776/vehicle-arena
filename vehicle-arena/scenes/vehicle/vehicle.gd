extends VehicleBody3D
# --- VARIABLES DE CÁMARA ---
@export var camara_principal_path: NodePath
@onready var camara_delantera = $CamaraDelantera
@onready var camara_principal = get_node(camara_principal_path) if camara_principal_path else null
@export var MAX_STEER = 0.7
@export var ENGINE_POWER = 300
@export var friccion_normal := 10.5
@export var friccion_derrape := 2.5 

#  VARIABLES PARA EL CELULAR 
@export var usar_acelerometro := false
@export var sensibilidad_volante := 1.0


@onready var rueda_trasera_izq = $VehicleWheel3D3
@onready var rueda_trasera_der = $VehicleWheel3D4

var giro_actual : float = 0.0

func _ready() -> void:
	# Autodetección: Si el juego arranca en Android o iOS, activa el acelerómetro
	if OS.has_feature("mobile"):
		usar_acelerometro = true
		
func _physics_process(delta: float) -> void:
	# Cambiar de cámara (Modo Toggle / Alternar)
	if Input.is_action_just_pressed("cambiar_camara"):
		if camara_delantera.current:
			# Si estamos en la delantera, volvemos a la principal
			if camara_principal:
				camara_principal.current = true
		else:
			# Si estamos en la principal, pasamos a la delantera
			camara_delantera.current = true
	var input_giro = 0.0
	 
	# 1. DECIDIR CÓMO LEER EL VOLANTE
	if usar_acelerometro:
		var accel = Input.get_accelerometer()
		# Leemos el acelerómetro y lo normalizamos (-1.0 a 1.0)
		input_giro = -(accel.x / 9.8) * sensibilidad_volante
		input_giro = clamp(input_giro, -1.0, 1.0)
	else:
		# Leemos los botones en pantalla o el teclado de PC
		input_giro = Input.get_axis("steer_right", "steer_left")
		 
	# 2. APLICAR EL GIRO 
	giro_actual = move_toward(giro_actual, input_giro * MAX_STEER, delta * 10)
	steering = giro_actual
	
	# 3. ACELERACIÓN
	var throttle = Input.get_axis("brake", "accelerate")
	engine_force = throttle * ENGINE_POWER
	# 4. DERRAPE
	var derrapando = Input.is_action_pressed("freno_mano")
	var friccion_actual = friccion_derrape if derrapando else friccion_normal
	
	if rueda_trasera_izq and rueda_trasera_der:
		rueda_trasera_izq.wheel_friction_slip = friccion_actual
		rueda_trasera_der.wheel_friction_slip = friccion_actual
		
func _on_button_button_down() -> void:
	Input.action_press("accelerate")


func _on_button_button_up() -> void:
	Input.action_release("accelerate")


func _on_button_2_button_down() -> void:
	Input.action_press("brake")


func _on_button_2_button_up() -> void:
	Input.action_release("brake")


func _on_button_3_button_down() -> void:
	Input.action_press("steer_left")


func _on_button_3_button_up() -> void:
	Input.action_release("steer_left")


func _on_button_4_button_down() -> void:
	Input.action_press("steer_right")


func _on_button_4_button_up() -> void:
	Input.action_release("steer_right")
