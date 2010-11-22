include std/sequence.e as s
include std/text.e
include std/regex.e as pre
include std/pretty.e

export sequence base_path = ""

export enum
	ERROR,
	CREOLE,
	API,
	HTML,
	SOURCE_COMMENT

constant
	pre_eucode_begin = pre:new(`\s*\<eucode\>\s*`),
	pre_eucode_end = pre:new(`^\s*\</eucode\>\s*$`),
	pre_header = pre:new(`\s*[\w\s0-9_]+:\s*$`),
	pre_item_name = pre:new(`\s*(\<built-in\>)?\s+((public|global|export)\s+)?(procedure|function|type|constant|enum|sequence|integer|atom|object)\s+([A-Za-z0-9_\?]+)`)

sequence processed_funcs = {}

export procedure start_new_file(sequence fname)
	processed_funcs = {}
end procedure

export function has_signature(sequence block)
	return eu:match("Signature:", block) > 0
end function

export function convert_api_block(sequence block, object namespace)
	object func_name, func_search, second = 0
	sequence line, lines = s:split( block, "\n"), new_block = {}
	integer in_eucode = 0, eustrip = 1, is_func = eu:match("Signature:", block), i = 1
	sequence kill_me

	while i <= length(lines) do
		line = lines[i]

		if pre:is_match(pre_eucode_begin, line) then
			in_eucode = 1
			eustrip = eu:match("<eucode>", line)
			new_block &= {"<eucode>"}
		elsif pre:is_match(pre_eucode_end, line) then
			new_block &= {"</eucode>"}
			in_eucode = 0
			eustrip = 1
		elsif pre:is_match(pre_header, line) then
			if eu:match("Signature:", line) then
				integer found_on = 0, builtin = 0
				for j = i to length(lines) do
					func_search = pre:find(pre_item_name, lines[j])
					if sequence(func_search) then
						found_on = j
						exit
					end if
				end for

				-- Signature should have been within 5 lines of the Signature: line
				if found_on = 0 or found_on > i + 5 then
					func_name = "BadSig: " & lines[i+1]
				else
					func_name = lines[found_on]
					builtin = func_search[2][1] != func_search[2][2]
					func_name = func_name[func_search[6][1]..func_search[6][2]]
					if eu:find(func_name, processed_funcs) then
						-- We've already processed this function
						-- This can happen because functions/constants/etc can be defined
						-- multiple times in an ifdef
						return ""
					end if

					processed_funcs &= { func_name }
				end if
				if builtin then
					new_block &= {"@[:eu:" & func_name & "|]" }
				elsif sequence(namespace) then
					new_block &= {"@[:" & namespace & ":" & func_name & "|]"}
				else					
					new_block &= {"@[:" & func_name & "|]" }
				end if
				new_block &= {"==== " & func_name}
			elsif match("Description:", line) then
				-- do nothing
			else
				new_block &= {"===== " & line}
			end if
		elsif in_eucode then
			if length(line) >= eustrip and eustrip > 0 then
				new_block &= {line[eustrip..$]}
			else
				new_block &= {line}
			end if
		else
			new_block &= {line}
		end if

		i += 1
	end while

	return join(new_block, "\n")
end function
