local type_hover = {}

local hover_method = "textDocument/hover"
local type_definition_method = "textDocument/typeDefinition"
local definition_method = "textDocument/definition"
local floating_window_focus_id = "type_hover"
local maximum_shown_declarations = 3
local maximum_declaration_lines = 30
local maximum_window_width = 100
local maximum_window_height = 40

local kinds_by_node_type = {
  interface_declaration = "interface",
  type_alias_declaration = "type alias",
  class_declaration = "class",
  abstract_class_declaration = "abstract class",
  class = "class",
  enum_declaration = "enum",
  function_declaration = "function",
  function_signature = "function",
  generator_function_declaration = "generator function",
  function_expression = "function",
  arrow_function = "function",
  internal_module = "namespace",
  module = "module",
  type_parameter = "type parameter",
  object = "object literal",
  object_type = "object type",
}

local type_declaration_node_types = {
  interface_declaration = true,
  type_alias_declaration = true,
  class_declaration = true,
  abstract_class_declaration = true,
  enum_declaration = true,
  internal_module = true,
  type_parameter = true,
}

local alias_shapes_by_node_type = {
  union_type = "union",
  intersection_type = "intersection",
  object_type = "object",
  function_type = "function",
  constructor_type = "constructor",
  tuple_type = "tuple",
  array_type = "array",
  literal_type = "literal",
  template_literal_type = "template literal",
  conditional_type = "conditional",
  generic_type = "generic",
  lookup_type = "indexed access",
  index_type_query = "keyof",
  type_query = "typeof",
  predefined_type = "primitive",
}

local function read_lines_of(file_path)
  local buffer = vim.fn.bufnr(file_path)
  if buffer ~= -1 and vim.api.nvim_buf_is_loaded(buffer) then
    return vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  end
  local is_readable, lines = pcall(vim.fn.readfile, file_path)
  return is_readable and lines or nil
end

local function find_parser_language_for(file_path)
  local filetype = vim.filetype.match({ filename = file_path })
  return filetype and vim.treesitter.language.get_lang(filetype) or nil
end

local function parse_syntax_tree(lines, language)
  if not language then
    return nil
  end
  local has_parser, parser = pcall(vim.treesitter.get_string_parser, table.concat(lines, "\n"), language)
  if not has_parser then
    return nil
  end
  return parser:parse()[1]
end

local function find_declaration_node(syntax_tree, row, column)
  local node = syntax_tree:root():named_descendant_for_range(row, column, row, column)
  while node do
    if kinds_by_node_type[node:type()] then
      return node
    end
    node = node:parent()
  end
  return nil
end

local function get_node_text(node, lines)
  local start_row, start_column, end_row, end_column = node:range()
  if start_row ~= end_row then
    return nil
  end
  return lines[start_row + 1]:sub(start_column + 1, end_column)
end

local function describe_kind_of(declaration_node)
  local kind = kinds_by_node_type[declaration_node:type()]
  if declaration_node:type() ~= "type_alias_declaration" then
    return kind
  end
  local aliased_type = declaration_node:field("value")[1]
  local alias_shape = aliased_type and alias_shapes_by_node_type[aliased_type:type()]
  return alias_shape and (kind .. " · " .. alias_shape) or kind
end

local function find_name_of(declaration_node, lines)
  local name_node = declaration_node:field("name")[1]
  return name_node and get_node_text(name_node, lines) or nil
end

local function include_export_keywords(declaration_node)
  local parent = declaration_node:parent()
  if parent and (parent:type() == "export_statement" or parent:type() == "ambient_declaration") then
    return include_export_keywords(parent)
  end
  return declaration_node
end

local function remove_shared_indentation(lines)
  local shared_indentation = nil
  for _, line in ipairs(lines) do
    if line:find("%S") then
      local indentation = #line:match("^%s*")
      shared_indentation = math.min(shared_indentation or indentation, indentation)
    end
  end
  local dedented_lines = {}
  for _, line in ipairs(lines) do
    table.insert(dedented_lines, line:sub((shared_indentation or 0) + 1))
  end
  return dedented_lines
end

local function slice_source(lines, start_row, start_column, end_row, end_column)
  local source_lines = vim.list_slice(lines, start_row + 1, end_row + 1)
  if #source_lines == 0 then
    return {}
  end
  source_lines[#source_lines] = source_lines[#source_lines]:sub(1, end_column)
  source_lines[1] = string.rep(" ", start_column) .. source_lines[1]:sub(start_column + 1)
  return remove_shared_indentation(source_lines)
end

local function to_byte_column(line, character, offset_encoding)
  return vim.str_byteindex(line or "", offset_encoding, character, false)
end

local function normalize_location(location, offset_encoding)
  return {
    uri = location.targetUri or location.uri,
    name_range = location.targetSelectionRange or location.range,
    whole_range = location.targetRange or location.range,
    offset_encoding = offset_encoding,
  }
end

local function list_locations(location_responses)
  local locations = {}
  local seen_locations = {}
  for client_id, response in pairs(location_responses) do
    local client = vim.lsp.get_client_by_id(client_id)
    local result = response.result
    if client and result then
      for _, location in ipairs(vim.islist(result) and result or { result }) do
        local normalized_location = normalize_location(location, client.offset_encoding)
        local location_key = normalized_location.uri .. ":" .. normalized_location.name_range.start.line
        if not seen_locations[location_key] then
          seen_locations[location_key] = true
          table.insert(locations, normalized_location)
        end
      end
    end
  end
  return locations
end

local function is_position_inside(range, position)
  local is_after_start = position.line > range.start.line
    or (position.line == range.start.line and position.character >= range.start.character)
  local is_before_end = position.line < range["end"].line
    or (position.line == range["end"].line and position.character <= range["end"].character)
  return is_after_start and is_before_end
end

local function open_source_at(location)
  local file_path = vim.uri_to_fname(location.uri)
  local lines = read_lines_of(file_path)
  if not lines then
    return nil
  end
  local name_start = location.name_range.start
  local language = find_parser_language_for(file_path)
  return {
    file_path = file_path,
    lines = lines,
    language = language,
    syntax_tree = parse_syntax_tree(lines, language),
    row = name_start.line,
    column = to_byte_column(lines[name_start.line + 1], name_start.character, location.offset_encoding),
  }
end

local function describe_declaration_node(source, declaration_node)
  return {
    kind = describe_kind_of(declaration_node),
    name = find_name_of(declaration_node, source.lines),
    file_path = source.file_path,
    line_number = declaration_node:range() + 1,
    language = source.language,
    source_lines = slice_source(source.lines, include_export_keywords(declaration_node):range()),
  }
end

local function describe_unparsed_range(source, whole_range)
  local last_line = source.lines[whole_range["end"].line + 1] or ""
  return {
    kind = "type",
    file_path = source.file_path,
    line_number = source.row + 1,
    language = source.language,
    source_lines = slice_source(source.lines, whole_range.start.line, 0, whole_range["end"].line, #last_line),
  }
end

---Describes the declaration a type definition location points at.
---@return { kind: string, name: string?, file_path: string, line_number: integer, language: string?, source_lines: string[] }?
function type_hover.describe_declaration_at(location)
  local source = open_source_at(location)
  if not source then
    return nil
  end
  local declaration_node = source.syntax_tree and find_declaration_node(source.syntax_tree, source.row, source.column)
  if declaration_node then
    return describe_declaration_node(source, declaration_node)
  end
  return describe_unparsed_range(source, location.whole_range)
end

local function find_named_type_node(type_node)
  local node_type = type_node and type_node:type()
  if node_type == "type_identifier" or node_type == "nested_type_identifier" then
    return type_node
  end
  if node_type == "generic_type" then
    return type_node:field("name")[1]
  end
  if node_type == "type_annotation" or node_type == "array_type" or node_type == "readonly_type" then
    return find_named_type_node(type_node:named_child(0))
  end
  return nil
end

---Looks at the symbol a definition location points at. A type declaration is
---described directly; a value with a type annotation yields the position of
---the annotated type's name, so its declaration can be looked up next.
---@return { declaration: table?, annotated_type: { buffer: integer, row: integer, column: integer, line: string }? }
local function inspect_definition_at(location)
  local source = open_source_at(location)
  if not source or not source.syntax_tree then
    return {}
  end
  local name_node =
    source.syntax_tree:root():named_descendant_for_range(source.row, source.column, source.row, source.column)
  local owner_node = name_node and name_node:parent()
  if not owner_node then
    return {}
  end
  if type_declaration_node_types[owner_node:type()] then
    return { declaration = describe_declaration_node(source, owner_node) }
  end
  local named_type_node = find_named_type_node(owner_node:field("type")[1])
  local buffer = vim.fn.bufnr(source.file_path)
  if not named_type_node or buffer == -1 or not vim.api.nvim_buf_is_loaded(buffer) then
    return {}
  end
  local _, _, end_row, end_column = named_type_node:range()
  return {
    annotated_type = { buffer = buffer, row = end_row, column = end_column - 1, line = source.lines[end_row + 1] },
  }
end

local function shorten_source(source_lines)
  if #source_lines <= maximum_declaration_lines then
    return source_lines
  end
  local shortened_lines = vim.list_slice(source_lines, 1, maximum_declaration_lines)
  table.insert(shortened_lines, "// … " .. (#source_lines - maximum_declaration_lines) .. " more lines")
  return shortened_lines
end

local function format_heading(declaration)
  local place = vim.fn.fnamemodify(declaration.file_path, ":~:.") .. ":" .. declaration.line_number
  local name = declaration.name and (" `" .. declaration.name .. "`") or ""
  return "**" .. declaration.kind .. "**" .. name .. " — " .. place
end

local function append_declaration(markdown_lines, declaration)
  if #markdown_lines > 0 then
    table.insert(markdown_lines, "---")
  end
  table.insert(markdown_lines, format_heading(declaration))
  table.insert(markdown_lines, "```" .. (declaration.language or ""))
  vim.list_extend(markdown_lines, shorten_source(declaration.source_lines))
  table.insert(markdown_lines, "```")
end

local function collect_hover_lines(hover_responses)
  local markdown_lines = {}
  for _, response in pairs(hover_responses) do
    local contents = response.result and response.result.contents
    local client_lines = contents and vim.lsp.util.convert_input_to_markdown_lines(contents) or {}
    if #client_lines > 0 then
      if #markdown_lines > 0 then
        table.insert(markdown_lines, "---")
      end
      vim.list_extend(markdown_lines, client_lines)
    end
  end
  return markdown_lines
end

local function is_declaration_under_cursor(location, cursor)
  return location.uri == cursor.uri and is_position_inside(location.name_range, cursor.position)
end

local function list_locations_away_from(cursor, responses)
  return vim.tbl_filter(function(location)
    return not is_declaration_under_cursor(location, cursor)
  end, list_locations(responses))
end

---Builds the Markdown shown in the hover window: the language servers' hover
---text, then each declaration of the symbol's type and what kind of type it is.
function type_hover.build_markdown_lines(hover_responses, declarations)
  local markdown_lines = collect_hover_lines(hover_responses)
  for index, declaration in ipairs(declarations) do
    if index > maximum_shown_declarations then
      table.insert(markdown_lines, "---")
      table.insert(markdown_lines, "… and " .. (#declarations - index + 1) .. " more declarations (`gy` lists them)")
      break
    end
    append_declaration(markdown_lines, declaration)
  end
  return markdown_lines
end

local function describe_declarations_at(locations)
  local declarations = {}
  for _, location in ipairs(locations) do
    local declaration = type_hover.describe_declaration_at(location)
    if declaration then
      table.insert(declarations, declaration)
    end
  end
  return declarations
end

local function has_client_supporting(buffer, method)
  return #vim.lsp.get_clients({ bufnr = buffer, method = method }) > 0
end

local function request_from_every_client(buffer, method, make_params, on_responses)
  if not has_client_supporting(buffer, method) then
    on_responses({})
    return
  end
  vim.lsp.buf_request_all(buffer, method, make_params, on_responses)
end

local function request_declarations_of_annotated_type(annotated_type, cursor, on_declarations)
  local function make_params(client)
    local character = vim.str_utfindex(annotated_type.line, client.offset_encoding, annotated_type.column, false)
    return {
      textDocument = vim.lsp.util.make_text_document_params(annotated_type.buffer),
      position = { line = annotated_type.row, character = character },
    }
  end
  request_from_every_client(annotated_type.buffer, definition_method, make_params, function(responses)
    on_declarations(describe_declarations_at(list_locations_away_from(cursor, responses)))
  end)
end

---Finds the declarations of the type of the symbol under the cursor. Language
---servers answer "type definition" for interfaces, classes and enums but not
---for aliases of unions or primitives, so those are reached through the
---symbol's own definition and its type annotation.
local function find_type_declarations(cursor, type_definition_responses, definition_responses, on_declarations)
  local declarations = describe_declarations_at(list_locations_away_from(cursor, type_definition_responses))
  if #declarations > 0 then
    on_declarations(declarations)
    return
  end
  for _, location in ipairs(list_locations(definition_responses)) do
    local definition = inspect_definition_at(location)
    if definition.annotated_type then
      request_declarations_of_annotated_type(definition.annotated_type, cursor, on_declarations)
      return
    end
    if definition.declaration and not is_declaration_under_cursor(location, cursor) then
      table.insert(declarations, definition.declaration)
    end
  end
  on_declarations(declarations)
end

---Shows hover documentation together with the definition of the symbol's type.
function type_hover.show()
  local buffer = vim.api.nvim_get_current_buf()
  local window = vim.api.nvim_get_current_win()
  if not has_client_supporting(buffer, type_definition_method) or not has_client_supporting(buffer, hover_method) then
    vim.lsp.buf.hover()
    return
  end

  local cursor_in_window = vim.api.nvim_win_get_cursor(window)
  local methods = { hover_method, type_definition_method, definition_method }
  local responses_by_method = {}

  local function make_position_params(client)
    return vim.lsp.util.make_position_params(window, client.offset_encoding)
  end

  local cursor = {
    uri = vim.uri_from_bufnr(buffer),
    position = make_position_params(vim.lsp.get_clients({ bufnr = buffer, method = hover_method })[1]).position,
  }

  local function is_cursor_still_in_place()
    return vim.api.nvim_get_current_buf() == buffer
      and vim.deep_equal(vim.api.nvim_win_get_cursor(window), cursor_in_window)
  end

  local function show_window(declarations)
    if not is_cursor_still_in_place() then
      return
    end
    local markdown_lines = type_hover.build_markdown_lines(responses_by_method[hover_method], declarations)
    if #markdown_lines == 0 then
      vim.notify("No information available")
      return
    end
    vim.lsp.util.open_floating_preview(markdown_lines, "markdown", {
      border = "rounded",
      focus_id = floating_window_focus_id,
      max_width = maximum_window_width,
      max_height = maximum_window_height,
    })
  end

  local function continue_when_every_method_answered()
    for _, method in ipairs(methods) do
      if not responses_by_method[method] then
        return
      end
    end
    find_type_declarations(
      cursor,
      responses_by_method[type_definition_method],
      responses_by_method[definition_method],
      show_window
    )
  end

  for _, method in ipairs(methods) do
    request_from_every_client(buffer, method, make_position_params, function(responses)
      responses_by_method[method] = responses
      continue_when_every_method_answered()
    end)
  end
end

return type_hover
