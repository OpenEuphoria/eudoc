include std/sequence.e
include std/text.e
include std/io.e
include std/filesys.e
include std/types.e
include std/error.e
include std/search.e

include euphoria/tokenize.e

include common.e

-- Comment status: No, Source, File
enum C_NO = 0, C_SOURCE, C_FILE

-- Setup parser
et_keep_blanks(TRUE)
et_keep_comments(TRUE)
et_string_numbers(TRUE)
                                
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

procedure putback_token()
	idx -= 1
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
	
	return result
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
				result &= '\"'
			end if

			result &= tok[TDATA]
			
			if tok[TTYPE] = T_CHAR then
				result &= '\''
			elsif tok[TTYPE] = T_STRING then
				result &= '\"'
			elsif find(tok[TTYPE], { T_COMMA, T_LBRACE }) then
				result &= ' '
			end if
		elsif tok[TTYPE] = T_BLANK then
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
		if find(tok[TDATA], { "global", "export", "public" }) then
			result = tok[TDATA]
		elsif find(tok[TDATA], { "procedure", "function", "type" }) then
			result &= ' ' & tok[TDATA]
			result &= read_routine_sig()
			exit
		elsif tok[TTYPE] = T_BLANK then
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
	sequence block = ""
	integer in_eucode = 0

	while next_token() do
		if tok[TTYPE] = T_COMMENT then
			if match("<eucode>", tok[TDATA]) then
				in_eucode = 1
			elsif match("</eucode>", tok[TDATA]) then
				in_eucode = 0
			end if

			if length(tok[TDATA]) < 3 then
				block &= '\n'
			elsif in_eucode then
				block &= tok[TDATA][4..$] & '\n'
			else
				block &= trim(tok[TDATA][3..$]) & '\n'
			end if
		else
			putback_token()
			exit
		end if
	end while

	if in_eucode then
		printf(1,"eucode was not ended (ln %d, col %d)\n"
                 ,{  tok[ET_ERR_LINE], tok[ET_ERR_COLUMN] 
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
	integer pos
	sequence path_data
	
	
	path_data = pathinfo(fname, '/')
	ifdef not UNIX then
		path_data = lower(path_data)
	end ifdef
	 
	
	if ends("/std", path_data[PATH_DIR]) then
		pos = length(path_data[PATH_DIR]) - 3
		
	else
		pos = match("/std/", path_data[PATH_DIR])
	end if
	
	if pos != 0 then
		include_filename = path_data[PATH_DIR][pos + 1 .. $] & '/' & path_data[PATH_FILENAME]
	else
		include_filename = path_data[PATH_FILENAME]
	end if
		
	-- Parse source file
	idx = 0
	tokens = et_tokenize_file(fname)

	-- Any errors during parsing?
	if tokens[2] then
		return {ERROR, sprintf("(ln %d, col %d) %s"
	                              , {tokens[ET_ERR_LINE], tokens[ET_ERR_COLUMN] 
	                              , et_error_string(tokens[2])})
      	       }
	end if

	while next_token() do
		if find(tok[TDATA], { "global", "public", "export", "override" }) then
			-- These are items that do not have a comment associated with them
			-- but we want them listed anyway, as they are exported in some fashion

			sequence visibility = tok[TDATA]

			if not next_token() then
				crash("Unexpected end of the file")
			end if

			sequence varSigPrefix = trim(visibility & " " & tok[TDATA])

			if find(tok[TDATA], { "function", "procedure", "type" }) then
				putback_token()
				putback_token()

				signature = read_sig()
				if length(signature) > 0 then
					tmp = "Signature:\n" &
						"include " & include_filename & "\n" &
						signature & "\n\n" &
						"Description:\n" & tmp
					content &= convert_api_block(tmp) & "\n\n"
					tmp = ""
				end if
			elsif find(tok[TDATA], { "include" }) then
				-- Do nothing with a public include

			else
				-- Must be a global, public or exported variable/constant of some type
				sequence var_sig = { 0, 0 }
				loop do
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
					elsif tok[TTYPE] = T_BLANK then
						-- do nothing
						continue
					else
						putback_token()
					end if

					var_sig = read_var_sig()
					var_sig[2] = trim(var_sig[2])
					if length(var_sig[2]) > 0 then
						tmp = "Signature:\n" &
							"include " & include_filename & "\n" &
							varSigPrefix & " " & var_sig[2] & "\n\n" &
							"Description:\n" & tmp & "\n\n"
						content &= convert_api_block(tmp) & "\n\n"
					end if
				until var_sig[1] = 0
				tmp = ""

				putback_token()
			end if
		elsif tok[TTYPE] = T_COMMENT or in_comment then
			if in_comment then
				putback_token()
				tmp = read_comment_block()
				
				if in_comment = C_SOURCE and not has_signature(tmp) then
					-- Look for the signature
					signature = read_sig()
					if length(signature) > 0 then					
						tmp = "Signature:\n" &
							"include " & include_filename & "\n" &
							signature & "\n\n" &
							"Description:\n" & 
							"  " & tmp
					end if
					-- We need to find the signature
				end if

				content &= convert_api_block(tmp) & "\n\n"
				tmp = ""
				
				in_comment = C_NO
				
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
	
	return {API, content}
end function
