let s:concat_seqs = 1
let s:debug = 0
let s:packrat_enabled = 1
let s:grammar_cache = {}
let s:inline_nonterminals = 2
let s:indent_stack = [-1]

" ------------------------------------------------
"  pretty print function for arbitrary types:

fu! s:pprint(thing)
	let f = s:format(a:thing, 0)
	let bla = 0
	for line in f
		unlet bla
		let bla = line
		call append(line('$'), string(bla))
	endfor
endf

fu! s:print(string, indent)
	return repeat(' ', a:indent) . a:string
endf

fu! s:format(thing, indent)
	let ls = []
	if type(a:thing) == type({})
		call add(ls, s:print('{', a:indent))
		for key in keys(a:thing)
			call add(ls, s:print(key, a:indent+2) . ':')
			let res = s:format(a:thing[key], a:indent+4)
			let ls += res
		endfor
		call add(ls, s:print('}', a:indent))
	elseif type(a:thing) == type([])
		call add(ls, s:print('[', a:indent))
		for item in a:thing
			let res = s:format(item, a:indent+4)
			let ls += res
			unlet item
		endfor
		call add(ls, s:print(']', a:indent))
	else
		call add(ls, s:print(a:thing, a:indent))
	endif
	return ls
endf

fu! s:print_state(thing, ...)
	let rest = a:0 ? ' --- ' . join(a:000, ' --- ') : ''
	"let msg = '> '.a:function . ', '.string(a:arg).', Pos: ' . s:pos . rest
	let msg = '> ' . string(a:thing).', Pos: ' . s:pos . rest . ' --- ' . expand('<sfile>')
	call append(line('$'), msg)
endf

fu! s:print_indentation_stack()
	let msg = '- indendation stack: '.string(s:indent_stack)
	call append(line('$'), msg)
endf

function! s:print_result(fu, outcome)
	if s:debug
		let msg = '< ' . a:fu . ' ' .string(a:outcome)
		call append(line('$'), msg)
	endif
endfunction

" -----------------------------------------------------
"some transformation functions:

function! s:strip(string)
  let res = substitute(a:string, '^\s\+', '', '')
  return substitute(res, '\s\+$', '', '')
endfunction

function! s:tag(string, tag, ...)
	if a:0
		return '<'.a:tag.' ' . a:1 . '>'.a:string.'</'.a:tag.'>\n'
	else
		return '<'.a:tag.'>'.a:string.'</'.a:tag.'>\n'
	endif
endfunction

fu! s:replace(origin, target)
	return a:target
endf

fu! s:surround(string, before, after)
	return a:before . a:string . a:after
endf



function! s:concat(listofstrings)
	return join(a:listofstrings, '')
endfunction

function! s:join(listofstrings, sep)
	return join(a:listofstrings, a:sep)
endfunction

function! s:skip(string)
	return ''
endfunction

function! s:split(thing)
	return a:thing
endfunction

fu! s:indent_gt_stack(whitespaces)
	if g:peggi_debug >= 1 | call s:print_indentation_stack() | endif
	return strdisplaywidth(a:whitespaces, 0) > s:indent_stack[-1] ? a:whitespaces : g:fail
endf

fu! s:indent_ge_stack(whitespaces)
	if g:peggi_debug >= 1 | call s:print_indentation_stack() | endif
	return strdisplaywidth(a:whitespaces, 0) >= s:indent_stack[-1] ? a:whitespaces : g:fail
endf


fu! s:trLiteral(string)
	let str = s:strip(a:string)
	let str = str[1:-2]
	let str = escape(str, '.*[]\^$')
	let str = '\s*'.str
	return ['regexp', str]
endf

fu! s:trRegexp(string)
	let str = s:strip(a:string)
	let str = str[1:-2]
	let str = substitute(str, '\\/', '/', 'g')
	let str = '\s*'.str
	return ['regexp', str]
endf

fu! s:trNonterminal(list)
	let str = s:strip(a:list[0])
	return ['nonterminal', str]
endf

fu! s:trSuffix(list)
	let suffix = s:strip(a:list[1])
	let thing = a:list[0]
	if suffix == '?' | return ['optional', thing] | endif
	if suffix == '+' | return ['oneormore', thing] | endif
	if suffix == '*' | return ['zeroormore', thing] | endif
	return thing
endf

fu! s:trPrefix(list)
	let prefix = s:strip(a:list[0])
	let thing = a:list[1]
	if prefix == '&' | return ['and', thing] | endif
	if prefix == '!' | return ['not', thing] | endif
	return thing
endf

fu! s:trSequence(list)
	if len(a:list) == 1
		return a:list[0]
	endif
	return ['sequence', a:list]
endf

fu! s:trChoice(list)
	if empty(a:list[1])
		return a:list[0]
	endif
	let trseq = [a:list[0]]
	for seq in a:list[1]
		call add(trseq, seq[1])
	endfor
	return ['choice', trseq]
endf

fu! s:trDefinition(list)
	let nt = s:strip(a:list[0])
	let is_indentation_nt = (a:list[1] != '')
	return [nt, is_indentation_nt, a:list[3]]
endf

fu! s:takeSecond(list)
	return a:list[1]
endf

fu! s:trTransform(list)
	let funk = a:list[1]
	if funk !~ '^[gsavlbwt]:'
		let funk = 's:'.funk
	endif

	let good_args = []
	for arg in a:list[3]
		let a = substitute(arg, '^\s*"', '', '')
		let a = substitute(a, '"\s*,\?\s*$', '', '')
		let a = substitute(a, '\\"', '"', 'g')
		call add(good_args, a)
	endfor
	return [funk] + good_args
endf

fu! s:trIndentGT(string)
	return ['regexp', '\s*', ['s:indent_gt_stack']]
endf

fu! s:trIndentGE(string)
	return ['regexp', '\s*', ['s:indent_ge_stack']]
endf

fu! s:appendTransforms(list)
	return a:list[0] + a:list[1]
endf

fu! s:replace_nts(rule, indentation_nts)
	if a:rule[0] == 'nonterminal'
		if index(a:indentation_nts, a:rule[1]) > -1
			return ['nonterminal_indent'] + a:rule[1:]
		endif
		return a:rule
	elseif a:rule[0] == 'regexp'
		return a:rule
	elseif a:rule[0] == 'sequence' || a:rule[0] == 'choice'
		let result = []
		for subitem in a:rule[1]
			call add(result, s:replace_nts(subitem, a:indentation_nts))
		endfor
		return [a:rule[0]] + [result] + a:rule[2:]
	else
		return [a:rule[0]] + [s:replace_nts(a:rule[1], a:indentation_nts)] + a:rule[2:]
	endif
endf

fu! s:makeGrammar(list_of_definitions)
	let grammar = {}
	let s:indentation_nts = []
	for defi in a:list_of_definitions
		let grammar[defi[0]] = defi[2]
		if defi[1]
			call add(s:indentation_nts, defi[0])
		endif
	endfor
	for key in keys(grammar)
		let grammar[key] = s:replace_nts(grammar[key], s:indentation_nts)
	endfor
	return grammar
endf

" ------------------------------------------------
" nonterminal inlining stuff


function! s:nts_on_right_side(rule)
	if a:rule[0] == 'nonterminal'
		return [a:rule[1]]
	elseif a:rule[0] == 'regexp' || a:rule[0] == 'nonterminal_indent'
		return []
	elseif a:rule[0] == 'sequence' || a:rule[0] == 'choice'
		let result = []
		for subitem in a:rule[1]
			let subitem_references = s:nts_on_right_side(subitem)
			for reference in subitem_references
				if index(result, reference) == -1
					call add(result, reference)
				endif
			endfor
		endfor
		return result
	else
		return s:nts_on_right_side(a:rule[1])
	endif
endfunction

function! s:substitute_nt_by_right_side(rule, nt, right_side)
	if a:rule[0] == 'nonterminal'
		if a:rule[1] ==# a:nt
			return a:right_side + a:rule[2:]
		endif
		return a:rule
	elseif a:rule[0] == 'regexp' || a:rule[0] == 'nonterminal_indent'
		return a:rule
	elseif a:rule[0] == 'sequence' || a:rule[0] == 'choice'
		let result = []
		for subitem in a:rule[1]
			call add(result, s:substitute_nt_by_right_side(subitem, a:nt, a:right_side))
		endfor
		return [a:rule[0]] + [result] + a:rule[2:]
	else
		return [a:rule[0]] + [s:substitute_nt_by_right_side(a:rule[1], a:nt, a:right_side)] + a:rule[2:]
	endif
endfunction


"optimizes the grammar a bit by replacing nonterminals on the right side of a
"grammar definition by its right side. Of course, this works only if a NT
"doesn't reference itself
function! s:inline_nts(grammar, start)
	let new_grammar = a:grammar
	"call s:pprint(a:grammar)
	"for every NT, collect all NTs it references
	let nt_references = {}
	for nt in keys(a:grammar)
		let nt_references[nt] = s:nts_on_right_side(a:grammar[nt])
	endfor
	for nt in keys(a:grammar)
		if nt ==# a:start || index(s:indentation_nts, nt) > -1 | continue | endif
		let cycle_detected = 0
		let references = nt_references[nt]
		if !empty(references)
			let idx = 0
			while 1
				if references[idx] ==# nt
					let cycle_detected = 1
					break
				endif
				for subnt in nt_references[references[idx]]
					if index(references, subnt) == -1
						call add(references, subnt)
					endif
				endfor
				if idx == len(references) - 1
					break
				endif
				let idx += 1
			endwhile
		endif
		if cycle_detected | continue | endif

		let right_side = remove(new_grammar, nt)
		for rule in keys(new_grammar)
			let new_grammar[rule] = s:substitute_nt_by_right_side(new_grammar[rule], nt, right_side)
		endfor
	endfor

	return new_grammar
endfunction


" ------------------------------------------------
"  the following defines the raw grammar for the nice grammar

" peggrammar = (pegdefinition+).s:makeGrammar()
" pegdefinition = (pegidentifier pegindentnt? pegassignment pegexpression).s:trDefinition()
" pegexpression = (pegsequence (/\s*|\s*/ pegsequence)*).s:trChoice()
" pegsequence = (pegprefix+).s:trSequence()
" pegprefix = ((/\s*&\s*/ | /\s*!\s*/)? pegsuffix).s:trPrefix()
" pegsuffix = (pegprimary (/\s*?\s*/ | /\s*\*\s*/ | /\s*+\s*/)).s:trSuffix()
" pegprimary = (( pegregexp | pegliteral | pegindentgreaterequal | pegindentgreater | (pegidentifier !pegindentnt !pegassignment).s:trNonterminal() | (/\s*(\s*/ pegexpression /\s*)\s*/).g:takeSecond() ) pegtransform*).s:appendTransforms()
" pegtransform = (/\./ /[a-zA-Z0-9_:]\+/ /(/ /\s*"\%(\\.\|[^"]\)*"\s*,\?\s*/ /\s*)/).s:trTransform()
" pegidentifier = /\s*[a-zA-Z_][a-zA-Z0-9_]*\s*/.s:strip()
" pegregexp = /\s*/\%(\\.\|[^/]\)*/\s*/.s:trRegexp()
" pegliteral = /\s*"\%(\\.\|[^"]\)*"\s*/.s:trLiteral()
" pegassignment = /\s*=/
" pegindentnt = /\s*\^/
" pegindentgreaterequal = /\s*>=/.s:trIndentGE()
" pegindentgreater = /\s*>/.s:trIndentGT()

let s:peggi_grammar = {
\ 'peggrammar' : ['oneormore', ['nonterminal', 'pegdefinition'], ['s:makeGrammar']],
\ 'pegdefinition' : ['sequence', [['nonterminal', 'pegidentifier'], ['optional', ['nonterminal','pegindentnt']], ['nonterminal','pegassignment'], ['nonterminal','pegexpression']], ['s:trDefinition']],
\ 'pegexpression' : ['sequence', [['nonterminal','pegsequence'], ['zeroormore',['sequence',[['regexp','\s*|\s*'], ['nonterminal','pegsequence']]]]], ['s:trChoice']],
\ 'pegsequence' : ['oneormore', ['nonterminal', 'pegprefix'], ['s:trSequence']],
\ 'pegprefix' : ['sequence', [['optional',['choice',[['regexp','\s*&\s*'], ['regexp','\s*!\s*']]]], ['nonterminal','pegsuffix']], ['s:trPrefix']],
\ 'pegsuffix' : ['sequence', [['nonterminal','pegprimary'], ['optional',['choice',[['regexp','\s*?\s*'],['regexp','\s*\*\s*'],['regexp','\s*+\s*']]]]], ['s:trSuffix']],
\ 'pegprimary' : ['sequence', [['choice',[['nonterminal','pegregexp'], ['nonterminal','pegliteral'], ['nonterminal', 'pegindentgreaterequal'], ['nonterminal', 'pegindentgreater'], ['sequence', [['nonterminal','pegidentifier'], ['not', ['nonterminal','pegindentnt']], ['not', ['nonterminal','pegassignment']]], ['s:trNonterminal']], ['sequence',[['regexp','\s*(\s*'],['nonterminal','pegexpression'],['regexp','\s*)\s*']], ['s:takeSecond']]]], ['zeroormore', ['nonterminal','pegtransform']] ], ['s:appendTransforms']],
\ 'pegtransform' : ['sequence', [['regexp', '\.'], ['regexp', '[a-zA-Z0-9_:]\+'], ['regexp', '('], ['zeroormore', ['regexp', '\s*"\%(\\.\|[^"]\)*"\s*,\?\s*']], ['regexp', '\s*)']], ['s:trTransform']],
\ 'pegidentifier' : ['regexp', '\s*[a-zA-Z_][a-zA-Z0-9_]*\s*', ['s:strip']],
\ 'pegregexp' : ['regexp', '\s*/\%(\\.\|[^/]\)*/\s*', ['s:trRegexp']],
\ 'pegliteral' : ['regexp', '\s*"\%(\\.\|[^"]\)*"\s*', ['s:trLiteral']],
\ 'pegassignment' : ['regexp', '\s*='],
\ 'pegindentnt' : ['regexp', '\s*\^'],
\ 'pegindentgreaterequal' : ['regexp', '\s*>=', ['s:trIndentGE']],
\ 'pegindentgreater' : ['regexp', '\s*>', ['s:trIndentGT']]
\ }









" ------------------------------------------------
"
" this is what some parse_* functions return if they don't match
let g:fail = 'fail'

let s:cache_fail = 'cache_fail'

fu! s:isfail(result)
	return type(a:result) == 1 && a:result == g:fail
endf

function! s:cache_fail(result)
	return type(a:result) == 1 && a:result == s:cache_fail
endfunction


" ------------------------------------------------
" the various parse functions for every element of a PEG grammar

"Returns: the matched string or Fail
fu! s:parse_regexp(thing)
	if s:debug | call s:print_state(a:thing, strpart(s:string, s:pos, 50)) | endif
	let cache_key = s:pos . string(a:thing) . string(s:indent_stack)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let npos = matchend(s:string, '\C^'.a:thing[1], s:pos)
		if npos == s:pos
			let result = ''
		elseif npos != -1
			let result = s:string[s:pos : npos-1]
			let s:pos = npos
		else
			let result = g:fail
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, s:indent_stack] | endif
	endif

	call s:print_result('regexp', outcome)
	return outcome
endf


"Returns: a list of whatever the subitems return or Fail (if one of them fails)
fu! s:parse_sequence(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . string(a:thing) . string(s:indent_stack)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let old_pos = s:pos
		let result = []
		let res = ''
		for thing in a:thing[1]
			unlet res  "necessary, because the type of the parse result may change
			let res = s:parse_{thing[0]}(thing)
			if s:isfail(res)
				let s:pos = old_pos
				unlet result | let result = g:fail
				break
			else
				call add(result, res)
			endif
		endfor
		if !s:isfail(result) && s:concat_seqs && !(len(a:thing) > 2 && a:thing[2][0] == "s:split")
			let res_string = join(result, '')
			unlet result
			let result = res_string
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, s:indent_stack] | endif
	endif
	call s:print_result('sequence', outcome)
	return outcome
endf

"like parse_nonterminal, but don't cache the output and push the current
"indentation on a stack when beginning the parsing and pop it when done
fu! s:parse_nonterminal_indent(thing)
	if s:debug | call s:print_state(a:thing) | endif

	call add(s:indent_stack, strdisplaywidth(matchstr(s:string, '^\s*', s:pos), 0))
	if g:peggi_debug >= 1 | call s:print_indentation_stack() | endif

	let thing = s:grammar[a:thing[1]]
	let result = s:parse_{thing[0]}(thing)

	let outcome = s:apply_transformations(result, a:thing[2:])

	call remove(s:indent_stack, -1)
	if g:peggi_debug >= 1 | call s:print_indentation_stack() | endif

	call s:print_result('indent_nonterminal: '.string(a:thing[1]), outcome)
	return outcome
endf

"Returns: whatever the element behind the nonterminal returns
fu! s:parse_nonterminal(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . string(a:thing) . string(s:indent_stack)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let thing = s:grammar[a:thing[1]]
		let result = s:parse_{thing[0]}(thing)

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, s:indent_stack] | endif
	endif
	call s:print_result('nonterminal: '.string(a:thing[1]), outcome)
	return outcome
endf

"Returns: whatever the first matching subelement returns, or Fail if all items fail
fu! s:parse_choice(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . string(a:thing) . string(s:indent_stack)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let old_pos = s:pos
		let result = g:fail
		let res = ''
		for thing in a:thing[1]
			unlet res
			let res = s:parse_{thing[0]}(thing)
			if !s:isfail(res)
				unlet result | let result = res
				break
			else
				let s:pos = old_pos
			endif
		endfor

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, s:indent_stack] | endif
	endif
	call s:print_result('choice', outcome)
	return outcome
endf

"Returns: whatever the subelement returns, or '' if it fails
fu! s:parse_optional(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . string(a:thing) . string(s:indent_stack)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let old_pos = s:pos
		let result = s:parse_{a:thing[1][0]}(a:thing[1])
		if s:isfail(result)
			let s:pos = old_pos
			let result = ''
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, s:indent_stack] | endif
	endif
	call s:print_result('optional', outcome)
	return outcome
endf

"Returns: a (possibliy empty) list of whatever the subitem returns, as long as it matches
fu! s:parse_zeroormore(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . string(a:thing) . string(s:indent_stack)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let result = []
		let res = ''
		while 1
			unlet res "necessary, because the type of the parse result may change
			let res = s:parse_{a:thing[1][0]}(a:thing[1])
			if s:isfail(res)
				break
			else
				call add(result, res)
			endif
		endwhile
		if s:concat_seqs && !(len(a:thing) > 2 && a:thing[2][0] == "s:split")
			let res_string = join(result, '')
			unlet result
			let result = res_string
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, s:indent_stack] | endif
	endif
	call s:print_result('zeroormore', outcome)
	return outcome
endf

"Returns: a list of whatever the subitem returns, as long as it matches, or Fail if doesn't match
fu! s:parse_oneormore(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . string(a:thing) . string(s:indent_stack)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let first = s:parse_{a:thing[1][0]}(a:thing[1])

		if s:isfail(first)
			let result = g:fail
		else
			let rest = []
			let res = ''
			while 1
				unlet res "necessary, because the type of the parse result may change
				let res = s:parse_{a:thing[1][0]}(a:thing[1])
				if s:isfail(res)
					break
				else
					call add(rest, res)
				endif
			endwhile
			if s:concat_seqs && !(len(a:thing) > 2 && a:thing[2][0] == "s:split")
				let result = first . join(rest, '')
			else
				let result = [first] + rest
			endif
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, s:indent_stack] | endif
	endif
	call s:print_result('oneormore', outcome)
	return outcome
endf

"Returns: '' if the given item matches, Fail otherwise
"does not consume any chars of the parsed string
fu! s:parse_and(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . string(a:thing) . string(s:indent_stack)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let old_pos = s:pos
		let res = s:parse_{a:thing[1][0]}(a:thing[1])
		let s:pos = old_pos
		if s:isfail(res)
			let result = g:fail
		else
			let result = ''
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, s:indent_stack] | endif
	endif
	call s:print_result('and', outcome)
	return outcome
endf

"Returns: '' if the given item matches not, Fail otherwise
"does not consume any chars of the parsed string
fu! s:parse_not(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . string(a:thing) . string(s:indent_stack)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let old_pos = s:pos
		let res = s:parse_{a:thing[1][0]}(a:thing[1])
		let s:pos = old_pos
		if s:isfail(res)
			let result = ''
		else
			let result = g:fail
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, s:indent_stack] | endif
	endif
	call s:print_result('not', outcome)
	return outcome
endf


"Calls the proper parse_* function for the given item
"afterwards, performs the transformation on the result
"
"We cache the input values (a:thing and s:pos) and the corresponding result
"this is called packrat parsing. At least I think so.
fu! s:query_cache(key)
	if s:packrat_enabled
		if has_key(s:cache, a:key)
			let cache_content = s:cache[a:key]
			let s:pos = cache_content[0]
			if s:debug
				let msg = "Yayyyyyyyyy, cache hit! -> " . a:key . " ----- " . string(cache_content)
				call append(line('$'), msg)
			endif
			let s:indent_stack = cache_content[2]
			return cache_content[1]
		endif
	endif
	return s:cache_fail
endfunction


fu! s:apply_transformations(result, transformations)
	if empty(a:transformations) | return a:result | endif
	let result = a:result
	let res = ''
	for funk in a:transformations
		if s:isfail(result)
			return g:fail
		endif
		unlet res
		let res = call(function(funk[0]), [result] + funk[1:])
		unlet result
		let result = res
	endfor
	return result
endf


fu! g:parse_begin(grammar, string, start)
	unlet! s:grammar

	if has_key(s:grammar_cache, a:grammar)
		let users_grammar = s:grammar_cache[a:grammar]
	else
		let s:debug = 0
		let s:cache = {}
		let s:pos = 0
		let s:grammar = s:peggi_grammar
		let s:concat_seqs = 0
		let s:string = a:grammar
		let users_grammar = s:parse_nonterminal(['nonterminal', 'peggrammar'])
		if (type(users_grammar) == type(g:fail) && users_grammar == g:fail) || strlen(s:string) > s:pos
			echom "Error: your grammar is malformed"
			return
		endif
		if s:inline_nonterminals == 1 || (s:inline_nonterminals == 2 && (!exists('g:peggi_debug') || g:peggi_debug == 0))
			let users_grammar = s:inline_nts(users_grammar, a:start)
		endif
		let s:grammar_cache[a:grammar] = users_grammar
	endif

	let s:packrat_enabled = 1
	if exists('g:peggi_debug') && g:peggi_debug >= 1
		let s:debug = 1
		"XXX hack
		let vimwiki_list = b:vimwiki_list
		tabnew
		let b:vimwiki_list = vimwiki_list
		set nowrap
	endif
	if exists('g:peggi_debug') && g:peggi_debug >= 2
		call s:pprint(users_grammar)
	endif
	"return

	let s:cache = {}
	let s:pos = 0
	let s:grammar = users_grammar
	let s:concat_seqs = 1
	let s:string = a:string

	return s:parse_nonterminal(['nonterminal', a:start])
endf

fu! g:parse(grammar, string, start)
	let result = g:parse_begin(a:grammar, a:string, a:start)
	if strlen(s:string) > s:pos
		return g:fail
	else
		return result
	endif
endf

fu! g:parse_file(grammar, file, start)
	return g:parse(a:grammar, join(readfile(a:file), "\r")."\r", a:start)
endf

fu! g:parse_file_begin(grammar, file, start)
	return g:parse_begin(a:grammar, join(readfile(a:file), "\r")."\r", a:start)
endf

