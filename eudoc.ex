#!/usr/bin/env eui

--
-- Standard Documentation Tool for Euphoria
--

include std/sequence.e as seq
include std/search.e
include std/regex.e as re
include std/filesys.e
include std/io.e
include std/os.e
include std/map.e as map
include std/cmdline.e
include std/text.e
include std/convert.e

include common.e
include parsers.e as p

constant re_output = re:new(`%%output=.*\n`)
constant APP_VERSION = "1.0.0"
global integer verbose = 0, single_file = 0, wrap_len = 78
object dir_strip_cnt = 0, assembly_fname = 0, output_file = 0
sequence files -- files to parse (in order)

procedure extra_help()
	puts(1, `
______________Note: The files named in the assembly file are processed
              after any extra files supplied on the command line.
              `
		)
end procedure

procedure parse_args()
	sequence opts = {
		{ "o", "output",   "Output file",    { MANDATORY, HAS_PARAMETER, "filename",ONCE } },
		{ "a", "assembly", "Assembly file",  { HAS_PARAMETER, "filename", ONCE } },
		{  0,  "strip",    "Strip n leading directory names from output filename", { HAS_PARAMETER, "n", ONCE } },
		{  0,  "wrap",     "Wrap long signatures to <chars> characters", { HAS_PARAMETER, "chars", ONCE } },
		{  0,  "single",   "Do not include file seperators", { NO_PARAMETER, ONCE } },
		{  0,  "verbose",  "Verbose output", { NO_PARAMETER } },
		{ "v", "version",  "Display program version", { VERSIONING, "eudoc v" & APP_VERSION } },
		{  0,   0,         "Additional input filenames can also be supplied.",    0 }
	}

	map:map o      = cmd_parse(opts, { HELP_RID, routine_id("extra_help") })
	assembly_fname = map:get(o, "assembly", 0)
	dir_strip_cnt  = map:get(o, "strip", 0)
	output_file    = map:get(o, "output", 0)
	single_file    = map:get(o, "single", 0)
	verbose        = map:get(o, "verbose", 0)
	files          = map:get(o, OPT_EXTRAS, {})

	if sequence(map:get(o, "wrap", 78)) then
		wrap_len = to_number(map:get(o, "wrap"))
	else
		wrap_len = map:get(o, "wrap", 78)
	end if

	if sequence(dir_strip_cnt) then
		dir_strip_cnt = to_number(dir_strip_cnt)
	end if
end procedure

function fullpath(sequence fname)
	ifdef WIN32 then
		if length(fname) >= 2 and fname[2] = ':' then
			return dirname(fname)
		end if
	elsifdef UNIX then
		if length(fname) >= 1 and fname[1] = '/' then
			return dirname(fname)
		end if
	end ifdef

	sequence parts = split_any(current_dir(), "/\\") & split_any(dirname(fname), "/\\")
	sequence new_path = {}

	for i = 1 to length(parts) do
		if equal(parts[i], "..") then
			new_path = new_path[1..$-1]
		elsif equal(parts[i], ".") then
			-- do nothing
		else
			new_path &= {parts[i]}
		end if
	end for

	return join(new_path, SLASH)
end function

procedure main()
	object parsed
	sequence fname, out_fname, complete = {}

	-- setup
	parse_args()

	if atom(output_file) then
		puts(1, "You must specify the output file using -o OUTPUT_FILE\n")
		abort(1)
	end if

	complete = "%%disallow={camelcase}\n"

	-- read the assembly file
	if sequence(assembly_fname) then
		files &= read_lines(assembly_fname)
		base_path = fullpath(assembly_fname)
	else
		base_path = current_dir()
	end if

	ifdef WINDOWS then
		base_path = match_replace('/', base_path, SLASH)
	end ifdef
	if base_path[$] = SLASH then
		base_path = base_path[1 .. $-1]
	end if

	if verbose then
		puts(1, "Base path: '" & base_path & "'\n")
	end if

	-- process each file
	for file_idx = 1 to length(files) do
		object ns_name
		integer opti
		sequence opts
		integer nowiki

		fname = files[file_idx]
		if length(fname) = 0 or match("#", fname) = 1 then
			continue -- skip blank lines and comment lines
		elsif fname[1] = ':' then
			-- Inline code, add it to the output
			if single_file = 0 or begins("%%output=", fname[2..$]) = 0 then
				complete &= fname[2..$] & "\n"
			end if

			continue
		end if

		nowiki = 0
		opti = find('<', fname)
		if opti != 0 then
			opts = stdseq:split(fname[opti + 1 .. $])
			fname = fname[1 .. opti - 1]

			nowiki =  (find("nowiki", opts) != 0)
		end if
		fname = trim(fname)
		ifdef WINDOWS then
			fname = match_replace('/', fname, SLASH)
		end ifdef
		if verbose then
			printf(1, "Processing file '%s'  ... ", { fname })
		end if

		if dir_strip_cnt > 0 then
			out_fname = seq:split(fname, SLASH)
			if length(out_fname) >= dir_strip_cnt then
				out_fname = out_fname[dir_strip_cnt..$]
			end if
			out_fname[$] = filebase(out_fname[$])
			out_fname = join(out_fname[dir_strip_cnt..$], "_")
		else
			out_fname = fname
		end if

		-- If using an assembly file, then all files are relative to the
		-- location of that assembly file.
		if sequence(assembly_fname) then
			if not absolute_path(fname) then
				parsed = p:parse(join({base_path, fname}, SLASH), {nowiki})
			else
				parsed = p:parse(fname, {nowiki})
			end if
		else
			parsed = p:parse(fname, {nowiki})
		end if

		switch parsed[1] do
			case ERROR then
				puts(1, parsed[2] & "\n")
				abort(1)

			case CREOLE then
				parsed = parsed[2]
				ns_name = 0

			case API then
				ns_name = parsed[3]
				parsed = parsed[2]
		end switch

		complete &= sprintf("\n!!CONTEXT:%s\n", { fname })

		if sequence(ns_name) then
			complete &= sprintf("!!namespace:%s\n", { ns_name })
		end if

		if single_file = 0 then
			complete &= sprintf("%%%%output = %s\n\n", { out_fname })
		else
			parsed = re:find_replace(re_output, parsed, "")
		end if

		complete &= parsed

		if verbose then
			puts(1, "done\n")
		end if
	end for	

	if length(complete) then
		if write_file(output_file, complete) = 0 then
			puts(1, "could not write output\n")
			abort(2)
		end if
	else
		puts(1, "\nNo content to write\n")
	end if
end procedure

main()
