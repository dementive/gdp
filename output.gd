@icon("res://path/to/optional/icon.svg")

# (optional) class definition:
class_name MyClass

# Inheritance:
extends Node



func global_function_test() -> void:
	print("Hello World!") # Hi


@export var int_number: int = 5
@export var string_export: String

@onready var ready_int_number: int = 5
@onready var health_bar: ProgressBar = get_node("UI/LifeBar")

@onready var runtime_number: int = 9000

# Member variables.
var a = 5 # hmm
var s = "Hello"
var arr = [1, 2, 3]
var dict = {"key": "value", 2: 3}

var other_dict: Dictionary[String, int] = {"1": 22, "3": 2}

var another_dict: Dictionary[String, String] = {"1": "22", "3": "2"}

var milliseconds: int = 10
var seconds: int:
	get:
		return milliseconds / 1000
	set(value):
		milliseconds = value * 1000

var minutes: int = 60:
	get:
		return milliseconds / 10000
	set(value):
		milliseconds = value * 10000

var typed_var: int
var static_typed_var: int
var new_typed_var: int = 0

var typed_var2: int
var inferred_type := "String"

static var static_typed_var_2: int
static var typed_var2_2: int
static var new_typed_var_2: int = 0
static var inferred_type_2 := "String"

const new_typed_var_23: int = 0
static var new_typed_var_234: int = 0

const constexpr_test: float = 1.4142135623730951
const constexpr_test2: float = 2.8284271247461903

var really_long_variable_name_that_is_very_long: int = 0


var thing1: int = 0
var THING: int = 0

func macro_func() -> void:
	var x: int = 999 
	for i: int in range(x): 
		print(i) 
	var y = 9999

	print(x - y)

func macro_func2() -> void:
	var x: int = 999 
	for i: int in range(x): 
		print(i) 
	var y = 9999

	print(x + y)

func constexpr_usage_test_func(x: int) -> int:
	var value: int = constexpr_test2 + x
	return value

func consteval_usage_test_func(x: int) -> int:
	var value: int = 4096.0 + x
	return value

func test_union_alias() -> Array:
	return Array()

func test_union_alias() -> Variant:
	if 1:
		return String()
	else:
		return null

# Conditional compilation with constant expressions
func normal_non_debug_function() -> void:
	print("I like dogs")

const cond_comp_var: int = 0
const cond_comp_var_two: int = 4


func get_favorite_animal() -> String:
	return "Rabbits are cool"

const x: String = "Hello World !"
const y: Vector3 = Vector3(5, 5, 5)
const z: int = 999


# Constants.
const ANSWER: int = 42
const THE_NAME = "Charly"
const ANSWER_2: int = 999

# Enums.
enum {UNIT_NEUTRAL, UNIT_ENEMY, UNIT_ALLY}
enum Named {THING_1, THING_2, ANOTHER_THING = -1}

func some_function(param1: int, param2: int, param3: int) -> int:
	const local_const = 5
	var is_thing_enabled: bool = false

	if true:
		pass

	if param1 < local_const:
		print(param1)
	elif param2 > 5:
		print(param2)
	else:
		print("Fail!")

	for i in range(20):
		print(i)

	for i: int in range(10):
		print(i)

	if param1 < local_const and 1 > 0:
		print(param1)

	var next_state = "idle" if true != false else "fall"

	var angle_degrees: int = 135
	var quadrant: String = (
		"northeast" if angle_degrees <= 90
		else "southeast" if angle_degrees <= 180
		else "southwest" if angle_degrees <= 270
		else "northwest"
	)

	var position := Vector2(250, 350)
	if (
		position.x > 200 and position.x < 400
		and position.y > 300 and position.y < 400
	):
		pass

	while param2 != 0:
		param2 -= 1

	match param3:
		3:
			print("param3 is 3!")
		_:
			print("param3 is not 3!")

	var local_var: int = param1 + 3
	return local_var


# fn something(int p1, p2: int):
# 	super(p1, p2)


# fn other_something(String p1 = "Hello", int p2 = 50):
# 	super.something(p1, p2)

func test_thing(p_thing: int = 1, vec_thing := Vector2(0, 0)) -> float:
	return 1.0

static func test_static() -> void:
	pass

static func test_static2(x: int = 999) -> void:
	pass

class Item:
	var a: int = 10

func add(reference: Item, amount: int) -> Item:
	reference.add(amount)
	return reference

var vehicles: Array[Node] = [$Car, $Plane]
var items: Array[Item] = [Item.new()]
var array_of_arrays: Array[Array] = [[], []]

# Constructor
func _init():
	print("Constructed!")
	var lv = Object.new()
	print(lv.a)

	var custom_node: Node = Node.new()
	custom_node.queue_free()

	var obj: Object = Object.new()
	obj.free()

@abstract class ABClassTest:
	@abstract func ab_test() -> void
	@abstract func ab_test2(x: int = 999) -> void
