# GDscript Preprocessor

Preprocessor for godot 4.5 gdscript. Adds some nice features that aren't possible in gdscript.

## Features

- Use `fn` instead of `func`

- Improved static typing syntax that looks more like C typing for declaring variables
	For example instead of doing `var test_var: int = 999` you can now do `int test_var = 999`.
	Or `int test_var` would be `var test_var: int`.
	This will work for all types, even user defined ones and container types like Array[String].
	Makes it easier to translate code from gdscript to C#/C++.

- Same static typing rules for typing loop variables.
	For example `for int i in range(5)` compiles to `for i: int in range(5)`

- Same static typing rules for typing function parameters.
	For example `func something(int p1, int p2)` compiles to `func something(p1: int, p2: int)`

- Same static typing rules for setget syntax.

- Easier to write `@export` and  `@onready` notation
	Example: `export String string_export` gets compiled to `@export var string_export: String`
			 `onready int ready_int_number = 5` gets compiled to `@onready var ready_int_number: int = 5`

- Adds a keyword: `new` that can be used to write `new Object` instead of `Object.new()`. This works for any object type that .new() gets called on.

- Adds a keyword: `free` that can be used to write `free obj` instead of `obj.free()`. This works for any object type that .free() gets called on.

- Adds a keyword: `qfree` that can be used to write `qfree node` instead of `node.queue_free()`. This works for any node type that .queue_free() gets called on.

- `constexpr` keyword for variables that can have their values computed at compile time and are then made const for use in gdscript.
	The expression after the = operator in a constexpr variable declaration gets evaluated as a godot [Expression](https://docs.godotengine.org/en/stable/classes/class_expression.html).
	So any code that is a valid Expression can go there and anything in [@GlobalScope](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html) can be used in a constant expression.

- `consteval` keyword that works the same as constexpr variables except their value will instead be inlined directly everywhere it is used.
	This way you can precompute values at compile time and also have them not use any memory at run time.
	consteval variables will not exist as variables in the resulting gdscript, everywhere they are referenced they will be replaced with their value at compile time.


- C style conditional compilation using constant expressions using #if/#else/#endif preprocessor statements
	The expression after the preprocessor statement can be any constant expressions, [Expression](https://docs.godotengine.org/en/stable/classes/class_expression.html) or constexpr/consteval variables will work.

- `export if` and `onready if` notation that allows conditional compilation of export and onready variables.
	For example: `export if DEBUG_ENABLED: int export_var_name = 999` will exclude the export variable line from the output if DEBUG_ENABLED is true.

- C style preprocessor #include statements that can be used to paste the contents of another file directly where the #include is found.

- C style preprocessor `#define` statements that define simple macros. Multiline macros are also supported. Unlike C macros, there is no way to take in any parameters as I want to prevent issues caused by creating unsearchable tokens with token pasting. Can also use `#undef` to undefine a macro that was previously defined.

- C++ style type aliases with `using CustomAliasName = String` syntax.

- Everything that works in gdscript also works in gdp. So some code can use the new features while normal gdscript can be in the same file with no issues.

To see everything the preprocessor can do check out `test.gdp` and compare it to the gdscript it gets compiled to in `output.gd`.

## Snippet

Here is a snippet of some cool stuff you can do:


```gdscript
consteval bool DEBUG_ENABLED = false

export if DEBUG_ENABLED: int debug_number = 999
onready if not DEBUG_ENABLED: int runtime_number = 9000

constexpr float constexpr_test = sqrt(2)
constexpr float constexpr_test2 = constexpr_test + sqrt(2)

#define TEST_MACRO really_long_variable_name_that_is_very_long
int TEST_MACRO = 0

fn test_func(int x) -> void:
	Node custom_node = new Node
	qfree custom_node

#define TEST_MULTI_LINE_MACRO \
	int x = 999 \
	for int i in range(x): \
		print(i) \
	var y = 9999

fn macro_func() -> void:
	TEST_MULTI_LINE_MACRO
	print(x - y)

fn macro_func2() -> void:
	TEST_MULTI_LINE_MACRO
	print(x + y)

consteval float consteval_test = pow(2, 12)
fn consteval_usage_test_func(int x) -> int:
	int value = consteval_test + x
	return value

using Optional[String] = Variant
fn test_union_alias() -> Optional[String]:
	if 1:
		return String()
	else:
		return null

# Conditional compilation with constant expressions

#if DEBUG_ENABLED
fn super_secret_debug_function() -> void:
	print("I like cats")
#else
fn normal_non_debug_function() -> void:
	print("I like dogs")
#endif

class Item:
	int a = 10

Array[Node] vehicles = [$Car, $Plane]
Array[Item] items = [new Item]
Array[Array] array_of_arrays = [[], []]
```

After running through the preprocessor the above code gets transformed into this:

```gdscript
@onready var runtime_number: int = 9000

const constexpr_test: float = 1.4142135623730951
const constexpr_test2: float = 2.8284271247461903

var really_long_variable_name_that_is_very_long: int = 0

func test_func(x: int) -> void:
	var custom_node: Node = Node.new()
	custom_node.queue_free()


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

func consteval_usage_test_func(x: int) -> int:
	var value: int = 4096.0 + x
	return value

func test_union_alias() -> Variant:
	if 1:
		return String()
	else:
		return null

# Conditional compilation with constant expressions
func normal_non_debug_function() -> void:
	print("I like dogs")

class Item:
	var a: int = 10

var vehicles: Array[Node] = [$Car, $Plane]
var items: Array[Item] = [Item.new()]
var array_of_arrays: Array[Array] = [[], []]

```

Still somewhat experimental, there are likely some edge cases that can result in broken output. The compiler also doesn't report hardly any errors, it mostly just passes everything straight to gdscript. Please make an issue if you find any bugs.
