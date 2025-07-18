import re
import math
import datetime
import hashlib
import random
from typing import Any, Dict, List

"""
NOTE: This is the original preprocessor written in python. Do not use this.
It has some features that havene't been pulled over to the gdscript version yet so keeping it around.


Gdscript preprocessor

Features:

- Some hardcoded macros to make typing some keywords easier. See keywords_map for the full list of keywords.
	Ex: 'fn' instead of 'func'.
	Note that these act like keywords so you cannot use these words in your code as variable or function names, they are reserved for the compiler.

- Improved static typing syntax that looks more like C typing for declaring variables
	For example instead of doing `var test_var: int = 999` you can now do `int test_var = 999`.
	Or `int test_var` would be `var test_var: int`.
	This will work for all types, even user defined ones and container types like Array[String].

- Same static typing rules for typing loop variables.
	For example `for int i in range(5)` compiles to `for i: int in range(5)`

- Same static typing rules for typing function parameters.
	For example `func something(int p1, int p2)` compiles to `func something(p1: int, p2: int)`

- Using ':' at the end of most statements is now optional instead of required.
	This includes the keywords if/elif/else, func, class, while, for, and match. Multiline statements will still require a colon.

- Multi line comments with /* and */.
	For this to work start a line with /*. All other lines until a line that has */ is found will be commented out.

- Multi line documentation comments using triple quotes just like how they work in python.

- In block comments using /* and */ work.
	This allows you to comment out only a part of a line, which isn't possible with gdscript.
	Example: `int test_doc_comment_var /* = 999 */ = 500` would compile to `var test_doc_comment_var: int = 500`

- Easier to write `@export` and  `@onready` notation
	Example: `export String string_export` gets compiled to `@export var string_export: String`
			 `onready int ready_int_number = 5` gets compiled to `@onready var ready_int_number: int = 5`

- Adds a keyword: "new" that can be used to write `new Object` instead of `Object.new()`. This works for any object type that .new() gets called on.

- Adds a keyword: "free" that can be used to write `free obj` instead of `obj.free()`. This works for any object type that .free() gets called on.

- Adds a keyword: "qfree" that can be used to write `qfree node` instead of `node.queue_free()`. This works for any node type that .queue_free() gets called on.

- "constexpr" keyword for variables that can have their values computed at compile time and are then made const for use in gdscript.
	The expression after the = operator in a constexpr variable declaration gets sent into the python exec() function.
	So any code that is valid python can go there.
	The python exec function imports the following python modules before executing any constant expressions: math, datetime, hashlib, random

- "consteval" keyword that works the same as constexpr variables except their value will instead be inlined directly everywhere it is used.
	This way you can precompute values at compile time and also have them not use any memory at run time.
	consteval variables will not exist as variables in the resulting gdscript, everywhere they are referenced they will be replaced with their value at compile time.

- C style conditional compilation using constant expressions using #if/#else/#endif preprocessor statements
	The expression after the preprocessor statement can be any constant expressions, any kind of python code or constexpr/consteval variables will work.

- C style preprocessor #include statements that can be used to paste the contents of another file directly where the #include is found.

- Everything that works in gdscript also works in gdp. So some code can use the new features while normal gdscript can be in the same file with no issues.

IMPORTANT: The preprocessor isn't a proper compiler, it is entirely based on vibes.

It doesn't do hardly any error checking but you can open the resulting compiled gdscript file in the editor to see if there are any errors.
There may also be bugs with the output if the compiler determines the vibes in your script aren't right.
There is a lot of gdscript syntax and getting 100% of it to transpile without any edge cases is tough.

"""

keywords_map: Dict[str, str] = {
    "yes": "true",
    "no": "false",
    "fn": "func",
    "vec2": "Vector2",
    "vec3": "Vector3",
    "vec4": "Vector4",
    "ivec2": "Vector2i",
    "ivec3": "Vector3i",
    "ivec4": "Vector4i",
    "Map": "Dictionary",
}

preprocessor_statements: List[str] = ["#if", "#else", "#endif", "#include"]

var_pattern: str = r"([A-Za-z_0-9]\w*)"
type_pattern: str = r"([A-Za-z_0-9]\w*(?:\[[^\[\]]+\])?)"
var_declaration_patter: str = rf"{type_pattern}\s+{var_pattern}\s+=(.*)"

memnew_pattern = re.compile(rf"new\s+{var_pattern}")
memfree_pattern = re.compile(rf"free\s+{var_pattern}")
memqueue_free_pattern = re.compile(rf"qfree\s+{var_pattern}")
static_type_pattern = re.compile(var_declaration_patter)

constexpr_var_pattern = re.compile(rf"constexpr\s+{var_declaration_patter}")
consteval_var_pattern = re.compile(rf"consteval\s+{var_declaration_patter}")

static_type_no_equals_pattern = re.compile(rf"{type_pattern}\s+{var_pattern}\n")
static_type_func_no_equals_pattern = re.compile(rf"{type_pattern}\s+{var_pattern},?")
annotation_pattern = re.compile(rf"^(export|onready)\s+{type_pattern}\s+{var_pattern}(.*)")

block_comment_pattern = re.compile(r"/\*.*?\*/", flags=re.DOTALL)

typed_for_pattern = re.compile(rf"for\s+{type_pattern}\s+{var_pattern}")
typed_function_pattern = re.compile(rf"func\s+{var_pattern}\(")

is_in_multiline_comment: bool = False
is_in_multiline_doc_comment: bool = False
is_inside_open_paren: bool = False
is_compilation_enabled: bool = True

is_compilation_enabled_stack: List[bool] = []

constexpr_variables: Dict = {}
consteval_variables: Dict = {}


def exec_and_return(expression: str) -> Any:
    exec_locals = {}
    exec(
        f"""
from math import *
from datetime import *
import hashlib
import random
value = {expression}
""",
        None,
        exec_locals,
    )
    return exec_locals["value"]


def process_line(line: str, outfile) -> None:
    global is_compilation_enabled_stack, is_in_multiline_comment, is_in_multiline_doc_comment, is_inside_open_paren, is_compilation_enabled

    stripped_line: str = line.strip()

    if stripped_line.startswith("#else"):
        is_compilation_enabled = not is_compilation_enabled
        return

    if stripped_line.startswith("#endif"):
        if len(is_compilation_enabled_stack) > 0:
            is_compilation_enabled = is_compilation_enabled_stack.pop()
        else:
            is_compilation_enabled = True

        if len(is_compilation_enabled_stack) <= 0:
            is_compilation_enabled = True

        return

    if not is_compilation_enabled:
        return

    # Macros that I think are nice
    for keyword in keywords_map:
        line = re.sub(rf"\b^{keyword}\b", keywords_map[keyword], line)

    # Multi line documentation comments
    if stripped_line.startswith('"""'):
        if not is_in_multiline_doc_comment:
            is_in_multiline_doc_comment = True
        else:
            is_in_multiline_doc_comment = False

        return

    if is_in_multiline_doc_comment:
        outfile.write("## " + line)
        return

    # Ignore empty
    if not stripped_line:
        outfile.write(line)
        return

    # Ignore comments
    if stripped_line.startswith("#"):
        if not any([x for x in preprocessor_statements if stripped_line.startswith(x)]):
            outfile.write(line)
            return

    # Multi line comments
    if stripped_line.startswith("/*"):
        is_in_multiline_comment = True
        line = line.replace("/*", "#")
        stripped_comment_line: str = line.strip()
        if stripped_comment_line == "#":
            return  # return if no other words on the line but the comment character
        else:
            outfile.write(line)
            return

    if is_in_multiline_comment and stripped_line.startswith("*/") or stripped_line.endswith("*/"):
        is_in_multiline_comment = False
        if stripped_line.startswith("*/"):
            line = line.replace("*/", "#")
        else:
            line = "# " + line.replace("*/", "")
        stripped_comment_line: str = line.strip()

        if stripped_comment_line == "#":
            return  # return if no other words on the line but the comment character
        else:
            outfile.write(line)
            return

    # Inline block comments
    if not is_in_multiline_comment and stripped_line.__contains__("*/"):
        line = re.sub(block_comment_pattern, "", line)

    comment_string: str = ""
    line_split: List[str] = line.split("#")
    split_line: str = line_split[0]

    # Replace consteval variables with their values
    for variable in consteval_variables:
        line = re.sub(rf"\b{variable}\b", str(consteval_variables[variable]), line)

    # Constexpr variables
    constexpr_var_match = re.search(constexpr_var_pattern, line)
    consteval_var_match = re.search(consteval_var_pattern, line)

    if constexpr_var_match:
        # Replace exisitng constexpr variables with their values in constant expressions
        for variable in constexpr_variables:
            line = re.sub(rf"\b{variable}\b", str(constexpr_variables[variable]), line)

        constexpr_var_match = re.search(constexpr_var_pattern, line)
        if not constexpr_var_match:
            return

        var_name: str = constexpr_var_match.group(2)
        expression: str = constexpr_var_match.group(3).strip()
        expression_result: Any = exec_and_return(expression)
        constexpr_variables[var_name] = expression_result

        if type(expression_result) == str:
            expression_result = f'"{expression_result}"'
        line = line.replace(expression, str(expression_result))
        line = re.sub(r"\bconstexpr\b", "const", line)

    # Consteval variables
    if consteval_var_match:
        # Replace exisitng constexpr variables with their values in constant expressions
        for variable in constexpr_variables:
            line = re.sub(rf"\b{variable}\b", str(constexpr_variables[variable]), line)

        var_name: str = consteval_var_match.group(2)
        expression: str = consteval_var_match.group(3).strip()
        expression_result: Any = exec_and_return(expression)
        if type(expression_result) == str:
            expression_result = f'"{expression_result}"'
        consteval_variables[var_name] = expression_result
        return

    if stripped_line.startswith("#if"):
        for variable in constexpr_variables:
            line = re.sub(rf"\b{variable}\b", str(constexpr_variables[variable]), line)

        pp_split: List[str] = line.split()
        if len(pp_split) > 1:
            pp_split.pop(0)
            expression: str = " ".join(pp_split)
            expression_result: Any = exec_and_return(expression)
            if type(expression_result) in (bool, int):
                is_compilation_enabled = expression_result
                is_compilation_enabled_stack.append(is_compilation_enabled)
            else:
                print("Wrong type for preprocessor statement")

        return

    stripped_line: str = line.strip()  # Update after running preprocessing

    ends_with_colon: bool = stripped_line.endswith(":")
    starts_with_class_name: bool = stripped_line.startswith("class_name")

    ends_with_open_paren: bool = stripped_line.endswith("(")
    ends_with_closed_paren: bool = stripped_line.endswith(")") or stripped_line.endswith("):")
    if ends_with_open_paren:
        is_inside_open_paren = True

    if is_inside_open_paren and ends_with_closed_paren:
        is_inside_open_paren = False

    # Make it so you don't need to use colons when the compiler can figure out where one should go
    if (
        stripped_line.startswith("static func")
        or stripped_line.startswith("func")
        or stripped_line.startswith("for")
        or stripped_line.startswith("while")
        or stripped_line.startswith("class")
        or stripped_line.startswith("match")
        or stripped_line.startswith("else")
    ) and not (ends_with_colon or starts_with_class_name or is_inside_open_paren):
        if len(line_split) > 1:
            comment_string = "#" + line_split[1]
        line = split_line[:-1] + f": {comment_string}" + split_line[-1]

    if not stripped_line.endswith("\\") and not is_inside_open_paren and stripped_line.startswith("if") or stripped_line.startswith("elif"):
        if not split_line.__contains__(":"):
            comment_string = ""
            if len(line_split) > 1:
                comment_string = "#" + line_split[1]

            line = split_line[:-1] + f": {comment_string}" + split_line[-1]

    line = memnew_pattern.sub(r"\1.new()", line)  # Allow using "new Object" syntax in place of "Object.new()"
    line = memqueue_free_pattern.sub(r"\1.queue_free()", line)
    line = memfree_pattern.sub(r"\1.free()", line)

    # Typed function parameters
    typed_function_match = re.search(typed_function_pattern, line)
    if typed_function_match:
        if len(line_split) > 1:
            comment_string = "#" + line_split[1]

        no_equals_match = re.findall(static_type_func_no_equals_pattern, split_line)
        if len(no_equals_match) > 1:
            for match in no_equals_match:
                if no_equals_match and not match[0].startswith("func") and not match[0].startswith("static"):
                    split_line = split_line.replace(f"{match[0]} {match[1]}", f"{match[1]}: {match[0]}")
            line = split_line[:-1] + f": {comment_string}" + split_line[-1]

    # onready and export annotations
    annotation_match = re.search(annotation_pattern, line)
    if annotation_match:
        line = annotation_pattern.sub(r"@\1 var \3: \2\4", line)

    # Variable declarations
    static_type_var_declaration_match = re.search(static_type_pattern, line)
    if (
        static_type_var_declaration_match
        and not static_type_var_declaration_match.group(1) in ["var", "const"]
        and not stripped_line.startswith("func")
        or stripped_line.startswith("static func")
    ):
        line = static_type_pattern.sub(r"var \2: \1 =\3", line)

    # Variable definitions
    no_equals_match = re.search(static_type_no_equals_pattern, line)
    if no_equals_match and not (
        stripped_line.startswith("return")
        or stripped_line.startswith("extends")
        or stripped_line.startswith("class_name")
        or stripped_line.startswith("func")
        or stripped_line.startswith("static func")
    ):
        line = static_type_no_equals_pattern.sub(r"var \2: \1\n", line)

    # Cleanup the vibes
    if line.startswith("const"):
        line = line.replace("const var", "const")

    # Typed for loop
    typed_for_match = re.search(typed_for_pattern, line)
    if typed_for_match and typed_for_match.group(2) != "in":
        line = typed_for_pattern.sub(r"for \2: \1", line)

    if is_in_multiline_comment:
        line = "# " + line

    outfile.write(line)


def compile(input_filename, output_filename):
    with open(input_filename, "r") as infile, open(output_filename, "w") as outfile:
        for line in infile:
            if line.strip().startswith("#include"):
                include_path: List[str] = line.split("#include")
                include_path_str: str = include_path[1].strip().replace('"', "")
                with open(include_path_str, "r", encoding="utf-8") as file:
                    content: str = file.read()
                    line = content

                    lines: List[str] = line.split("\n")
                    for included_line in lines:
                        process_line(f"{included_line}\n", outfile)
                    continue

            process_line(line, outfile)


compile("gdp_compiler.gdp", "gdp_compiler.gd")
