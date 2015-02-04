include std/sequence.e
include std/text.e
include std/io.e
include std/filesys.e
include std/types.e
include std/error.e
include std/search.e
include std/console.e

include euphoria/tokenize.e

include common.e

-- std, euphoria, one or more user supplied include prefix
-- so ../include/xyz/eio.e wiil display include xyz/eio.e
-- needs to be creole.opts option add to or replace std,euphoria

sequence include_prefix = split("std,euphoria", ",")

-- Comment status: No, Source, File
enum C_NO = 0, C_SOURCE, C_FILE

-- eudoc testing filename index
integer eucode_test_idx, eucode_test_failed
sequence current_filename

-- Setup parser tokenizer
keep_newlines(TRUE)
keep_comments(TRUE)
string_numbers(TRUE)

function split_signature(sequence s, integer width = 78)
	if length(s) < width then
		return s
	end if

	integer i = 1, nested = 0, in_str = 0, check_point = 0, char_count = 0
	while i < length(s) do
		char_count += 1

		if char_count > width and check_point != 0 then
			s = splice(s, "\n       ", check_point + 1)
			char_count = i - check_point
			check_point = 0
		end if

		if find(s[i], "\"'`") then
			if in_str > 0 and in_str = s[i] and s[i-1] != '\\' then
				in_str = 0
			else
				in_str = s[i]
			end if
		elsif find(s[i], "({") then
			nested += 1
		elsif find(s[i], "})") then
			nested -= 1
		end if

		if s[i] = ',' and nested < 2 and in_str = 0 then
			check_point = i
		end if

		i += 1
	end while

	return s
end function

object tokens, tok
integer idx = 0

function next_token()
	idx += 1
	if idx > length(tokens[1]) then
		return 0
	end if

	tok = tokens[1][idx]
	return 1
end function

function peek_next_token()
	if idx + 1 > length(tokens[1]) then
		return T_EOF
	end if

	return tokens[1][idx + 1]
end function

procedure putback_token()
	if idx > 1 then
		idx -= 1
	end if
	tok = tokens[1][idx]
end procedure

function read_routine_sig()
	sequence result = ""
	integer hit_paren = 0, parens = 0

	while next_token() do
		if tok[TTYPE] = T_LPAREN then
			hit_paren = 1
			parens += 1
		elsif tok[TTYPE] = T_RPAREN then
			parens -= 1
		end if

		if find(tokens[1][idx - 1][TTYPE], { T_IDENTIFIER, T_KEYWORD, T_EQ, T_PLUSEQ,
			T_MINUSEQ, T_MULTIPLYEQ, T_DIVIDEEQ, T_LTEQ, T_GTEQ, T_NOTEQ, T_CONCATEQ,
			T_PLUS, T_MINUS, T_MULTIPLY, T_DIVIDE, T_LT, T_GT, T_NOT, T_CONCAT, T_QPRINT }) and
			not find(tok[TTYPE], { T_LPAREN, T_RPAREN, T_COMMA })
		then
			result &= ' '
		end if

		if tok[TTYPE] = T_CHAR then
			result &= '\''
		elsif tok[TTYPE] = T_STRING then
			result &= '"'
		end if

		result &= tok[TDATA]

		if find(tok[TTYPE], { T_COMMA }) then
			result &= ' '
		elsif tok[TTYPE] = T_CHAR then
			result &= '\''
		elsif tok[TTYPE] = T_STRING then
			result &= '"'
		end if

		if parens = 0 and hit_paren then
			exit
		end if
	end while

	return split_signature(result, wrap_len)
end function

function read_var_sig()
	integer multiSig = 0
	integer id = 0         -- Can have up to 3 (global sequence name)
	integer assignment = 0 -- Can have 1
	integer value = 0      -- Can have 1
	integer nesting = 0
	sequence result = ""

	while next_token() do
		-- Figure context
		if find(tok[TTYPE], { T_KEYWORD, T_IDENTIFIER }) then
			id += 1

			if id > 4 and value = 0 then
				putback_token()
				exit
			end if
		elsif tok[TTYPE] = T_DOLLAR then
			-- do nothing
		elsif find(tok[TTYPE], { T_EQ }) then
			if assignment then
				putback_token()
				exit
			else
				assignment = 1
			end if
		elsif find(tok[TTYPE], { T_NUMBER, T_STRING, T_CHAR, T_IDENTIFIER }) then
			value += 1
			if value > 1 then
				putback_token()
				exit
			end if
		elsif find(tok[TTYPE], { T_COMMA }) and nesting = 0 then
			multiSig = 1
			exit
		elsif find(tok[TTYPE], { T_LPAREN, T_LBRACKET, T_LBRACE }) then
			if value > 0 then
				value -= 1
			end if
			nesting += 1
		elsif find(tok[TTYPE], { T_PLUS, T_MINUS, T_MULTIPLY, T_DIVIDE, T_LT, T_GT, T_NOT, T_CONCAT, T_LPAREN,
				T_LBRACE, T_LBRACKET, T_COMMA })
		then
			if value > 0 then
				value -= 1
			end if

		elsif find(tok[TTYPE], { T_RPAREN, T_RBRACE, T_RBRACKET }) then
			value += 1
			nesting -= 1

		elsif tok[TTYPE] = T_COMMENT and begins("--**", tok[TDATA]) then
			if not nesting then
				putback_token()
				exit
			end if

		elsif (id and assignment and value) or (id and not assignment) then
			putback_token()
			exit
		end if

		-- Append/Format
		if assignment then
			-- Do nothing, do not append the actual value onto the docs

		elsif tok[TTYPE] = T_DOLLAR then
			exit

		elsif find(tok[TTYPE], { T_KEYWORD, T_IDENTIFIER, T_EQ, T_NUMBER, T_STRING, T_CHAR }) or
		      tok[TTYPE] >= T_DELIMITER
		then
			if find(tokens[1][idx - 1][TTYPE], { T_IDENTIFIER, T_KEYWORD, T_EQ, T_PLUSEQ,
						T_MINUSEQ, T_MULTIPLYEQ, T_DIVIDEEQ, T_LTEQ, T_GTEQ, T_NOTEQ, T_CONCATEQ,
						T_PLUS, T_MINUS, T_MULTIPLY, T_DIVIDE, T_LT, T_GT, T_NOT, T_CONCAT, T_QPRINT }) and
					not find(tok[TTYPE], { T_LPAREN, T_RPAREN, T_COMMA })
			then
				result &= ' '
			elsif find(tok[TTYPE], { T_RBRACE }) then
				result &= ' '
			end if

			if tok[TTYPE] = T_CHAR then
				result &= '\''
			elsif tok[TTYPE] = T_STRING then
				result &= '"'
			end if

			result &= tok[TDATA]

			if tok[TTYPE] = T_CHAR then
				result &= '\''
			elsif tok[TTYPE] = T_STRING then
				result &= '"'
			elsif find(tok[TTYPE], { T_COMMA, T_LBRACE }) then
				result &= ' '
			end if
		elsif tok[TTYPE] = T_NEWLINE then
			-- do nothing
		else
			exit
		end if
	end while

	return { multiSig, result }
end function

function read_sig()
	sequence result = ""

	while next_token() do
		if find(tok[TDATA], { "global", "export", "public", "override" }) then
			result = tok[TDATA]
		elsif find(tok[TDATA], { "procedure", "function", "type" }) then
			result &= ' ' & tok[TDATA]
			result &= read_routine_sig()
			exit
		elsif tok[TTYPE] = T_NEWLINE then
			-- Do nothing
		else
			putback_token()
			sequence varSig = read_var_sig()
			result &= varSig[2]
			exit
		end if
	end while

	return trim(result)
end function

function read_comment_block()
	sequence block = "", eucode_block = "", fail_msg = ""
	integer in_eucode = 0

	while next_token() do
		if tok[TTYPE] = T_COMMENT then
			if match("<eucode>", tok[TDATA]) then
				in_eucode = 1
				fail_msg = ""
				eucode_block = "include " & canonical_path(current_filename) & "\n"
			elsif match("</eucode>", tok[TDATA]) then
				in_eucode = -1

                if length(eucode_block) and test_eucode then
					eucode_test_idx += 1
					eucode_tested += 1
					sequence test_filename = sprintf("%s_%d.e", {
							canonical_path(work_path) & SLASH & filebase(current_filename),
							eucode_test_idx
						})
					write_file(test_filename, eucode_block)
					sequence test_cmd = sprintf("eui -test -batch %s  > %s.log", { 
							test_filename, test_filename })
					if system_exec(test_cmd) != 0 then
						printf(2, "F")
						eucode_test_failed += 1

						fail_msg = "\n\n**FAILED**\n\n{{{\n" & 
							read_file(test_filename & ".log") & 
							"\n}}}\n\n"
					else
						eucode_passed += 1
						if verbose then
							printf(2, ".")
						end if

						delete_file(test_filename)
						delete_file(test_filename & ".log")
					end if

                    eucode_block = ""
                end if
			elsif in_eucode and test_eucode and length(tok[TDATA]) > 3 then
            	eucode_block &= trim(tok[TDATA][4..$]) & '\n'
            end if

			if length(tok[TDATA]) < 3 then
				block &= '\n'
			elsif in_eucode = 1 then
				block &= tok[TDATA][4..$] & '\n'
			else
				block &= trim(tok[TDATA][3..$]) & '\n'
				if in_eucode = -1 then
					in_eucode = 0

					if length(fail_msg) then
						block &= fail_msg
					end if
				end if
			end if
		elsif tok[TTYPE] = T_NEWLINE then
			object nxt = peek_next_token()
			if atom(nxt) or nxt[TTYPE] != T_COMMENT then
				putback_token()
				exit
			end if
		else
			putback_token()
			exit
		end if
	end while

	if in_eucode then
		printf(1, "eucode was not ended (ln %d, col %d)\n", {
			tok[ET_ERR_LINE], tok[ET_ERR_COLUMN]
		})

		abort(1)
	end if

	return block
end function

export function parse_euphoria_source(sequence fname, object params, object extras)
	integer in_comment = C_NO
	object tmp
	sequence content = "", signature
	sequence include_filename
	integer pos, ignore_next = 0
	sequence path_data
	object ns_name = 0
	sequence ns_stmt = "", ns_stmt2 = ""

	eucode_test_idx = 0
	eucode_test_failed = 0

	path_data = pathinfo(fname, '/')
	ifdef not UNIX then
		path_data = lower(path_data)
	end ifdef
	include_filename = path_data[PATH_FILENAME]

	for x = 1 to length(include_prefix) do

		if ends("/"&include_prefix[x], path_data[PATH_DIR]) then
			pos = length(path_data[PATH_DIR]) - length(include_prefix[x])

	else
			pos = match("/"&include_prefix[x]&"/", path_data[PATH_DIR])
	end if

	if pos != 0 then
		include_filename = path_data[PATH_DIR][pos + 1 .. $] & '/' & path_data[PATH_FILENAME]
			exit
	end if
	end for

	-- Parse source file
	idx = 0
	tokens = tokenize_file(fname)

	current_filename = fname

	-- Any errors during parsing?
	if tokens[2] then
		return { ERROR, sprintf("(file %s ln %d, col %d) %s", {
				fname, tokens[ET_ERR_LINE], tokens[ET_ERR_COLUMN], error_string(tokens[2])
			})
		}
	end if
	tmp = ""
	
	while next_token() do
		if equal(tok[TDATA], "namespace") then
			if not next_token() then
				crash("Unexpected end of the file")
			end if

			ns_name = tok[TDATA]
			ns_stmt = "namespace " & ns_name & "\n"
		elsif find(tok[TDATA], { "global", "public", "export", "override" }) then
			-- These are items that do not have a comment associated with them
			-- but we want them listed anyway, as they are exported in some fashion

			sequence visibility = tok[TDATA]

	label "try_next_token"
			if not next_token() then
				crash("Unexpected end of the file")
			end if

			if tok[TTYPE] = T_NEWLINE then
				goto "try_next_token"
			end if

			sequence varSigPrefix = trim(visibility & " " & tok[TDATA])
		
			if ignore_next then
				ignore_next = 0
			elsif find(tok[TDATA], { "function", "procedure", "type" }) then
				putback_token()
				putback_token()

				signature = read_sig()
				if length(signature) > 0 then
					tmp = "Signature:\n<eucode>\n" &
						"include " & include_filename & "\n" &
						ns_stmt &
						signature & "\n</eucode>\n\n" &
						"Description:\n" & tmp
					content &= convert_api_block(tmp, ns_name) & "\n\n"
					tmp = ""
				end if
			elsif find(tok[TDATA], { "include" }) then
				-- Do nothing with a public include

			else
				-- Must be a global, public or exported variable/constant of some type
				sequence var_sig = { 0, 0 }
				loop do
			label "try_varsig_again"
					tmp = ""

					-- See if we have a comment block
					if not next_token() then
						crash("Unexpected end of the file")
					end if

					if tok[TTYPE] = T_COMMENT and begins("--**", tok[TDATA]) then
						if begins("--****", tok[TDATA]) then
							tmp = tok[TDATA][7..$]
						else
							tmp = tok[TDATA][5..$]
						end if
						tmp &= read_comment_block()
					elsif tok[TTYPE] = T_NEWLINE then
						-- do nothing
						goto "try_varsig_again"
					else
						putback_token()
					end if

					-- Check for an enum by
					next_token()
					if tok[TTYPE] = T_KEYWORD and find(tok[TDATA], {"by", "type"}) then
						-- skip the next token also (by XYZ)
						next_token()

						if length(tok[TDATA]) and find(tok[TDATA][1], "+-/*") then
							next_token()
						end if
						goto "try_varsig_again"
					else
						putback_token()
					end if

					var_sig = read_var_sig()
					if not match("@nodoc@", tmp) then
                        -- Normally, the comments that come before the declaration of something in
                        -- the source are supposed to appear after the declaration title in the
                        -- documentation. Here, we check to see whether we have a title comment, in
                        -- which case we should put it before the declaration. Ticket: 265
						if begins("=", tmp) then
							content &= tmp
							tmp = ""
						end if
					
						var_sig[2] = trim(var_sig[2])
						if length(var_sig[2]) > 0 then
							tmp = "Signature:\n<eucode>\n" &
								"include " & include_filename & "\n" &
								ns_stmt &
								varSigPrefix & " " & var_sig[2] & "\n</eucode>\n\n" &
								"Description:\n" & tmp & "\n\n"
							content &= convert_api_block(tmp, ns_name) & "\n\n"
						end if
					end if
					
					until var_sig[1] = 0 
				end loop
				tmp = ""

				putback_token()
			end if
		elsif tok[TTYPE] = T_COMMENT or in_comment then
			if in_comment then
				putback_token()
				tmp = read_comment_block()
				if match("@nodoc@", tmp) then
					ignore_next = 1
					in_comment = C_NO
					tmp = ""
				else
					if in_comment = C_SOURCE and not has_signature(tmp) then
						-- Look for the signature
						signature = read_sig()
						if length(signature) > 0 then
							tmp = "Signature:\n<eucode>\n" &
								"include " & include_filename & "\n" &
								ns_stmt &
								signature & "\n</eucode>\n\n" &
								"Description:\n" &
								"  " & tmp
						end if
						-- We need to find the signature
					end if
	
					content &= convert_api_block(tmp, ns_name) & "\n\n"
					tmp = ""
	
					in_comment = C_NO
				end if
				
			elsif begins("--****", tok[TDATA]) then
				-- Start of file comment
				in_comment = C_FILE
				tmp = ""

			elsif begins("--**", tok[TDATA]) then
				-- Start of source comment
				in_comment = C_SOURCE
				tmp = ""

			end if
		end if
	end while

	if test_eucode then
		printf(2, " passed %d of %d ", { eucode_test_idx - eucode_test_failed, eucode_test_idx })
	end if

	return {API, content, ns_name}
end function

