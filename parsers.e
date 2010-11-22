--
-- Return formatted HTML from various file formats
--

include std/io.e
include std/filesys.e

include common.e
include euparser.e   -- Euphoria source parser
include genparser.e  -- Generic source parser

function parse_creole_file(sequence fname, object opts, object extras)
	object content = read_file(fname, TEXT_MODE)

	if atom(content) then
		return {ERROR, sprintf( "Could not read file \'%s\' ", { fname } )}
	end if

	if sequence(extras) then
		if extras[1] then
			-- nowiki
			content = "{{{\n" & content & "}}}\n"
		end if
	end if
	return {CREOLE, content}
end function

sequence parsers = {
    -- Raw Creole Sources
	{ { "txt", "creole" },  
	  routine_id("parse_creole_file"), {} },
	
	-- Euphoria Sources
	{ { "e", "ed", "eu", "ew", "ex", "exd", "exu", "exw" },
	  routine_id("parse_euphoria_source"), {} },

	-- C sources
	{ { "c", "cpp", "c++", "h", "hpp" },
	  routine_id("parse_generic_source"), {"/*", "*/" } }
}

function get_parser(sequence fname)
	sequence ext = fileext(fname)

	for i = 1 to length(parsers) do
		if find(ext, parsers[i][1]) then
			return i
		end if
	end for

	return -1
end function

export function parse(sequence fname, object parse_opts = {})
	integer parser_id = get_parser(fname)
	
	if parser_id = -1 then
		return {ERROR, "Unknown file type '" & fname & "'"}
	end if

	start_new_file(fname)

	return call_func(parsers[parser_id][2], {fname, parsers[parser_id][3], parse_opts})
end function
