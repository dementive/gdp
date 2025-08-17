# GDscript Preprocessor

Preprocessor for godot 4.5 gdscript. Adds some nice features that aren't possible in gdscript.

## Features

- `constexpr` keyword for variables that can have their values computed at compile time and are then made const for use in gdscript.
	The expression after the = operator in a constexpr variable declaration gets evaluated as a godot [Expression](https://docs.godotengine.org/en/stable/classes/class_expression.html).
	So any code that is a valid Expression can go there and anything in [@GlobalScope](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html) can be used in a constant expression.

- `consteval` keyword that works the same as constexpr variables except the value will instead be inlined directly everywhere it is used.
	This way you can precompute values at compile time and also have them not use any memory at run time.
	consteval variables will not exist as variables in the resulting gdscript, everywhere they are referenced they will be replaced with their value at compile time.

- C style conditional compilation with @if/@else/@endif preprocessor statements. The expression after the preprocessor statement can be any constant [Expression](https://docs.godotengine.org/en/stable/classes/class_expression.html) or a constexpr/consteval variable.

- C++ style type aliases with `using CustomAliasName = String` syntax.

- C style preprocessor `@include` statements that can be used to paste the contents of another file directly where the `@include` is found. The argument must be in double quotes and it must be a valid path to a file that FileAccess::open can open.

- C style preprocessor `@define` statements that define simple macros. Can also use `@undef` to undefine a macro that was previously defined.


## Snippet

Here is a snippet of some cool stuff you can do:


```gdscript
# Alias
using StringDict = Dictionary[String, String]
var another_dict: StringDict = {"1": "22", "3": "2"}

constexpr constexpr_test: float = sqrt(2)
constexpr constexpr_test2: float = constexpr_test + sqrt(2)

@define TEST_MACRO really_long_variable_name_that_is_very_long
var TEST_MACRO: int = 0

@define THING var thing1: int = 0
THING

@undef THING
var THING: int = 0

func constexpr_usage_test_func(x: int) -> int:
	var value: int = constexpr_test2 + x
	return value

consteval consteval_test: float = pow(2, 12)
func consteval_usage_test_func(x: int) -> int:
	var value: int = consteval_test + x
	return value

using Union[String,int,float] = Array
func test_union_alias() -> Union[String,int,float]:
	return Array()

using Optional[String] = Variant
func test_union_alias2() -> Optional[String]:
	if 1:
		return String()
	else:
		return null

# Conditional compilation with constant expressions
@if DEBUG_ENABLED
func super_secret_debug_function() -> void:
	print("I like cats")
@else
func normal_non_debug_function() -> void:
	print("I like dogs")
@endif

constexpr cond_comp_var: int = 0
constexpr cond_comp_var_two: int = cond_comp_var + 4

consteval power_level: int = sqrt(9001 + sqrt(2) * pow(4, 9)) * 5000

@if power_level > 9000
func get_favorite_animal() -> String:
@if DEBUG_ENABLED
	return "Frogs are my favorite"
@else
	return "Rabbits are cool"
@endif
@endif

constexpr x: String = "Hello" + " World " + "!"
constexpr y: Vector3 = Vector3(5, 5, 5)
constexpr z: int = 999
consteval TEST: Vector2 = Vector2(0, 0)

@if TEST == Vector2(1, 0)
func test_test_test():
	print("hello")
@endif
```

After running through the preprocessor the above code will get transformed into the following gdscript code:

```gdscript
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
```

## Limitations

Still mostly experimental, there are likely some edge cases that can result in broken output.
The preprocessor also doesn't report hardly any errors, it mostly just passes everything straight to gdscript.
Please make an issue if you find any bugs.

Debuggablity also suffers a lot when compiling to gdscript. The line numbers do not line up perfectly in the compiled script due to things like conditional compilation. So when you get errors from the gdscript vm at runtime the line number they report might not be the same as the line number was before running the preprocessor. Usually the error gives enough information to figure out the bug but it might make it marginally harder to figure out where errors come from.

## Usage

To run the tests run godot with `godot --headless --script ./gdp_compiler.gd --quit`. This will compile `test.gdp` to `test.gd`. You can then copy `test.gd` into a godot project and open the compiled script in the editor.

Right now there isn't a proper API, only a `compile` function that takes a input file and an output file as parameters.
I think the ideal way to do it in the future would be to make an EditorPlugin and have it compile automatically on save in the code editor so you can get instant feedback from gdscript's parser and LSP.

The syntax highlighting will be pretty bad in most editors if you use the default gdscript syntax.
If you use Sublime Text you can install [SublimeGodot](https://github.com/dementive/SublimeGodot/tree/a18b34b0e8713899161c31d5522c5fc7603bd6d3/gdp) and use the `gdp` syntax, then if your files have the `gdp` extension you'll get correct highlighting for everything new.