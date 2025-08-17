func global_function_test() -> void:
	print("Hello World!") # Hi

# Alias
var another_dict: Dictionary[String, String] = {"1": "22", "3": "2"}

const constexpr_test: float = 1.4142135623730951
const constexpr_test2: float = 2.8284271247461903

var really_long_variable_name_that_is_very_long: int = 0

var thing1: int = 0

var THING: int = 0

func constexpr_usage_test_func(x: int) -> int:
	var value: int = constexpr_test2 + x
	return value

func consteval_usage_test_func(x: int) -> int:
	var value: int = 4096.0 + x
	return value

func test_union_alias() -> Array:
	return Array()

func test_union_alias2() -> Variant:
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


