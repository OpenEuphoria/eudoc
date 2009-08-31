--
-- Standard Documentation Tool for Euphoria
--

include std/sequence.e
include std/search.e
include std/regex.e as re
include std/filesys.e
include std/io.e
include std/os.e
include std/map.e as map
include std/cmdline.e

include common.e
include parsers.e as p

global integer verbose = 0
object assembly_fname = 0, output_file = 0, template = 0
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
		{ "v", "verbose",  "Verbose output", {NO_PARAMETER}},
		{ "a", "assembly", "Assembly file",  {HAS_PARAMETER, "filename", ONCE} },
		{ "o", "output",   "Output file",    {MANDATORY, HAS_PARAMETER, "filename",ONCE} },
		{ "t", "template", "Template file",  {HAS_PARAMETER, "filename",ONCE}},
		{  0,   0,         "Additional input filenames can also be supplied.",    0 }
	}

	map:map o = cmd_parse(opts, routine_id("extra_help"))
	verbose = map:get(o, "verbose", 0)
	assembly_fname = map:get(o, "assembly", 0)
	output_file = map:get(o, "output", 0)
	template = map:get(o, "template", 0)
	files = map:get(o, "extras", {})

	if sequence(template) then
		template = read_file(template, TEXT_MODE)
		if atom(template) then
			printf(1, "Could not read template file '%s'\n", { map:get(o, "template") })
			abort(1)
		end if
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
	sequence fname, complete = {}

	-- setup
	parse_args()

	if atom(output_file) then
		puts(1, "You must specify the output file using -o OUTPUT_FILE\n")
		abort(1)
	end if

	complete = "%%disallow={camelcase}\n"
	if atom(template) then
		template = "<html>\n" &
			"<head>\n" &
			"<link rel=\"stylesheet\" href=\"eudoc.css\">\n" &
			"<title>${TITLE}</title>\n" &
			"</head>\n" &
			"<body>${BODY}</body>\n" &
			"</html>\n"
	end if

	-- read the assembly file
	if sequence(assembly_fname) then
		files &= read_lines(assembly_fname)
		base_path = fullpath(assembly_fname)
	else
		base_path = current_dir()
	end if

	if verbose then
		puts(1, "Base path: '" & base_path & "'\n")
	end if
	
	-- process each file
	for file_idx = 1 to length(files) do
		fname = files[file_idx]
		if length(fname) = 0 or match("#", fname) = 1 then
			continue -- skip blank lines and comment lines
		elsif match(":", fname) = 1 then
			-- Inline code, add it to the output
			complete &= fname[2..$] & "\n"
			continue
		end if

		if verbose then
			printf(1, "Processing file %s... ", { fname })
		end if

		-- If using an assembly file, then all files are relative to the
		-- location of that assembly file.
		if sequence(assembly_fname) then
			parsed = p:parse(join({base_path, fname}, SLASH), template)
		else
			parsed = p:parse(fname, template)
		end if

		switch parsed[1] do
			case ERROR then
				puts(1, parsed[2] & "\n")
				abort(1)

			case CREOLE then
				parsed = parsed[2]

			case API then
				parsed = parsed[2]
		end switch

		complete &= sprintf("\n!!CONTEXT:%s\n\n%s", {fname, parsed})

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
