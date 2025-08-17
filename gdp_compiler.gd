extends MainLoop

var constexpr_var_pattern: RegEx
var consteval_var_pattern: RegEx
var type_alias_pattern: RegEx

var is_compilation_enabled: bool = true

var is_compilation_enabled_stack: Array[bool] = []
var macro_dict: Dictionary[String, Variant] = {}
var constexpr_variables: Dictionary[String, Variant] = {}
var consteval_variables: Dictionary[String, Variant] = {}
var type_aliases: Dictionary[String, String] = {}

func whitespace_split(p_string: String, p_splitter: String = " ") -> PackedStringArray:
	var ret: PackedStringArray
	var inside_quote: bool = false
	var quote_type: bool = false
	var current_word: String
	var comment_started: bool = false

	for i in p_string.length():
		if (p_string[i] == '#' && !inside_quote && !comment_started):
			comment_started = true
		elif (p_string[i] == '\n' && comment_started):
			comment_started = false
		elif (!comment_started):
			if (p_string[i] == '"' && !inside_quote):
				inside_quote = true
				quote_type = true
				current_word += p_string[i]
			elif (p_string[i] == '"' && inside_quote && quote_type):
				inside_quote = false
				current_word += p_string[i]
			elif (p_string[i] == '\'' && !inside_quote):
				inside_quote = true
				quote_type = false
				current_word += p_string[i]
			elif (p_string[i] == '\'' && inside_quote && !quote_type):
				inside_quote = false
				current_word += p_string[i]
			elif (p_string[i] == p_splitter && !inside_quote):
				if (!current_word.is_empty()):
					ret.push_back(current_word)
					current_word = ""
			else:
				current_word += p_string[i]

	if (!current_word.is_empty()):
		ret.push_back(current_word)

	return ret

func compile_regex() -> void:
	var var_pattern: String = r"([A-Za-z_0-9]\w*)"
	var type_pattern: String = r"([A-Za-z_0-9]\w*(?:\[[^\[\]]+\])?)"
	var simple_keyword_pattern_fmt: String = r"%s\s+%s"

	var var_declaration_pattern_fmt: String = r"%s:\s+%s\s+=(.*)"
	var var_declaration_pattern: String = var_declaration_pattern_fmt % [var_pattern, type_pattern]

	var constant_expression_fmt = r"%s\s+%s"
	constexpr_var_pattern = RegEx.new()
	constexpr_var_pattern.compile(constant_expression_fmt % ["constexpr", var_declaration_pattern])

	consteval_var_pattern = RegEx.new()
	consteval_var_pattern.compile(constant_expression_fmt % ["consteval", var_declaration_pattern])

	type_alias_pattern = RegEx.new()
	type_alias_pattern.compile(r"using\s+{type_pattern}\s+=\s+{type_pattern}".format({"type_pattern": type_pattern}))

func exec_and_return(expression: String): 
	var expr := Expression.new()
	expr.parse(expression)
	var result: Variant = expr.execute() 
	if (expr.has_execute_failed()):
		print("Error executing expression: ", expression)
	return result

func replace_consteval_vars(line_tokens: PackedStringArray) -> PackedStringArray:
	for variable in consteval_variables:
		var iter_idx: int = 0
		for token in line_tokens:
			if token == variable:
				line_tokens[iter_idx] = var_to_str(consteval_variables[variable])
			iter_idx += 1

	return line_tokens

func replace_constexpr_vars(line_tokens: PackedStringArray) -> PackedStringArray:
	for variable in constexpr_variables:
		var iter_idx: int = 0
		for token in line_tokens:
			if token == variable:
				line_tokens[iter_idx] = var_to_str(constexpr_variables[variable])
			iter_idx += 1

	return line_tokens

func get_indentation_level(line: String) -> int:
	var level: int = 0
	for char in line:
		if char == "\t" or char == "    ":
			level += 1
		else:
			break

	return level

func process_line(line: String, file: FileAccess) -> void:
	# Store lines with only comments
	if line.begins_with("#"):
		file.store_line(line)
		return

	# Macro definition
	if line.begins_with("@define"):
		var macro_tokens: PackedStringArray = line.split(" ")
		var current_macro_value: String = ""

		macro_tokens.remove_at(0)
		var current_macro_key: String = macro_tokens[0]

		for i in macro_tokens:
			if i != current_macro_key:
				current_macro_value = current_macro_value + " " + i

		if not current_macro_value.is_empty():
			macro_dict[current_macro_key] = current_macro_value.strip_edges()

		return

	# Macro removal
	if line.begins_with("@undef"):
		var macro_tokens: PackedStringArray = line.split(" ")
		macro_tokens.remove_at(0)

		var current_macro_key: String = macro_tokens[0]
		macro_dict.erase(current_macro_key)
		return

	var indentation_level: int = get_indentation_level(line)
	line = line.strip_edges()
	var line_tokens: PackedStringArray = whitespace_split(line)

	# Replace consteval variables with their values
	line_tokens = replace_consteval_vars(line_tokens)
	for variable in consteval_variables:
		line = line.replacen(variable, var_to_str(consteval_variables[variable]))

	# Conditional compilation
	if line.begins_with("@if"):
		var expression: String = line.replace("@if", "")
		var expression_result = exec_and_return(expression.strip_edges())
		if (expression_result is bool or expression_result is int):
			is_compilation_enabled = expression_result
			is_compilation_enabled_stack.append(is_compilation_enabled)
		else:
			print("Wrong type for @if preprocessor statement. Must be a bool or int.")

		return

	if line.begins_with("@else"):
		is_compilation_enabled = not is_compilation_enabled
		return

	if line.begins_with("@endif"):
		if is_compilation_enabled_stack.size() > 0:
			is_compilation_enabled = is_compilation_enabled_stack.pop_back()
		else:
			is_compilation_enabled = true

		if is_compilation_enabled_stack.size() <= 0:
			is_compilation_enabled = true

		return

	# Type aliases
	if line.begins_with("using"):
		var alias_var_match: RegExMatch = type_alias_pattern.search(line)
		if alias_var_match:
			var groups: PackedStringArray = alias_var_match.strings
			type_aliases[groups[1]] = groups[2]
		else:
			print("Invalid type alias on line: ", line)
			print_stack()

		return

	var iter_idx: int = 0
	var alias_token: String = ""

	for token in line_tokens:
		# Apply type aliases
		for alias in type_aliases:
			if token.ends_with(",") or token.ends_with("]"):
				alias_token += token
			if token.ends_with("]:"):
				alias_token += token.replace(":", "")
			if token == alias:
				line_tokens[iter_idx] = type_convert(type_aliases[alias], TYPE_STRING)
				alias_token = ""

			if type_aliases.has(alias_token):
				var full_line_str: String = " ".join(line_tokens)
				full_line_str = full_line_str.replace(alias_token, type_convert(type_aliases[alias_token], TYPE_STRING))
				line_tokens = whitespace_split(full_line_str)

		# Apply macros
		for macro in macro_dict:
			if token == macro or (token.ends_with(":") and token.left(-1) == macro):
				if token.ends_with(":"):
					line_tokens[iter_idx] = type_convert(macro_dict[macro], TYPE_STRING) + ":"
				else:
					line_tokens[iter_idx] = type_convert(macro_dict[macro], TYPE_STRING)
		
		iter_idx += 1


	# Split comments that are on the end of a line
	var line_split: PackedStringArray = line.split("#")
	var comment_string: String = ""
	if line_split.size() > 1:
		comment_string = line_split[1]

	if (line_tokens.is_empty()):
		file.store_line("")
		return

	var first_token: String = line_tokens[0]

	# Ignore line if an ifdef has disabled compilation of this line 
	if not is_compilation_enabled:
		return

	# Constexpr variables
	if first_token == "constexpr":
		line_tokens = replace_constexpr_vars(line_tokens)
		var line_str: String = " ".join(line_tokens)

		var constexpr_var_match: RegExMatch = constexpr_var_pattern.search(line_str)
		if !constexpr_var_match:
			print("Compile error while parsing constexpr variable on line: ", line)
			print_stack()
			return

		var groups: PackedStringArray = constexpr_var_match.strings
		var var_name: String = groups[1]
		var expression: String = groups[3].strip_edges()
		var expression_result: Variant = exec_and_return(expression)
		constexpr_variables[var_name] = expression_result

		var idx: int = 0
		var should_replace: bool = false
		var new_tokens: PackedStringArray
		for token in line_tokens:
			if !should_replace and token == "=":
				should_replace = true
				new_tokens.append(token)
			if token == "constexpr":
				token = "const"
			if !should_replace:
				new_tokens.append(token)

			idx += 1

		line_tokens = new_tokens
		line_tokens.append(var_to_str(expression_result))

	if first_token == "consteval":
		line_tokens = replace_constexpr_vars(line_tokens)

		var line_str: String = " ".join(line_tokens)
		var consteval_var_match: RegExMatch = consteval_var_pattern.search(line_str)
		if !consteval_var_match:
			print("Compile error while parsing consteval variable on line: ", line)
			print_stack()
			return

		var groups: PackedStringArray = consteval_var_match.strings
		var var_name: String = groups[1]
		var expression: String = groups[3].strip_edges()
		var expression_result = exec_and_return(expression)
		consteval_variables[var_name] = expression_result

		return

	var line_str: String = " ".join(line_tokens)

	for level in range(indentation_level):
		line_str = "\t" + line_str

	if comment_string:
		line_str += " #" + comment_string

	file.store_line(line_str)


func compile(input_file_name: String, output_file_name: String) -> void: 
	var file := FileAccess.open(input_file_name, FileAccess.READ)
	var out_file := FileAccess.open(output_file_name, FileAccess.WRITE)
	while not file.eof_reached():
		var line: String = file.get_line()

		if line.strip_edges().begins_with("@include"):
			var include_path: PackedStringArray = line.split("@include")
			var include_path_str: String = include_path[1].strip_edges().replace('"', "")

			var include_file := FileAccess.open(include_path_str, FileAccess.READ)
			line = include_file.get_as_text()
			var lines: PackedStringArray = line.split("\n")
			for included_line in lines:
				if included_line.is_empty():
					continue
				process_line(included_line, out_file)

		process_line(line, out_file)
	file.close()

func _init(): 
	compile_regex()
	compile("test.gdp", "output.gd")
