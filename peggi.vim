let s:concat_seqs = 1
let s:debug = 0
let s:packrat_enabled = 1
let s:grammar_cache = {}
let s:output_to_buffer = 1
tabnew
set nowrap

let g:peggi_additional_state = []

" ------------------------------------------------
"  pretty print function for arbitrary types:

fu! s:pprint(thing)
	let f = s:format(a:thing, 0)
	let bla = 0
	for line in f
		unlet bla
		let bla = line
		if s:output_to_buffer
			call append(line('$'), string(bla))
		else
			echom string(bla)
		endif
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


" -----------------------------------------------------
"some transformation functions:

function! s:strip(string)
  let res = substitute(a:string, '^\s\+', '', '')
  return substitute(res, '\s\+$', '', '')
endfunction

function! s:tag(tag, string)
	return '<'.a:tag.'>'.a:string.'</'.a:tag.'>\n'
endfunction

fu! s:replace(target, origin)
	return a:target
endf

fu! s:surround(before, after, string)
	return a:before . a:string . a:after
endf



function! s:concat(listofstrings)
	return join(a:listofstrings, '')
endfunction

function! s:join(sep, listofstrings)
	return join(a:listofstrings, a:sep)
endfunction

function! s:skip(string)
	return ''
endfunction

function! s:split(thing)
	return a:thing
endfunction


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
	return [nt, a:list[2]]
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
		call add(good_args, a)
	endfor
	return [funk] + good_args
endf

fu! s:trFunction(list)
	let funk = a:list[0]
	let arg = a:list[2]
	return ['function', [funk, arg]]
endf

fu! s:appendTransforms(list)
	return a:list[0] + a:list[1]
endf

fu! s:makeGrammar(lists)
	let grammar = {}
	for lst in a:lists
		let grammar[lst[0]] = lst[1]
	endfor
	return grammar
endf


" ------------------------------------------------
"  the following defines the raw grammar for the nice grammar


let s:peggi_grammar = {
\ 'peggrammar' : ['oneormore', ['nonterminal', 'pegdefinition'], ['s:makeGrammar']],
\ 'pegdefinition' : ['sequence', [['nonterminal', 'pegidentifier'], ['nonterminal','pegassignment'], ['nonterminal','pegexpression']], ['s:trDefinition']],
\ 'pegexpression' : ['sequence', [['nonterminal','pegsequence'], ['zeroormore',['sequence',[['regexp','\s*|\s*'], ['nonterminal','pegsequence']]]]], ['s:trChoice']],
\ 'pegsequence' : ['zeroormore', ['nonterminal', 'pegprefix'], ['s:trSequence']],
\ 'pegprefix' : ['sequence', [['optional',['choice',[['regexp','\s*&\s*'], ['regexp','\s*!\s*']]]], ['nonterminal','pegsuffix']], ['s:trPrefix']],
\ 'pegsuffix' : ['sequence', [['nonterminal','pegprimary'], ['optional',['choice',[['regexp','\s*?\s*'],['regexp','\s*\*\s*'],['regexp','\s*+\s*']]]]], ['s:trSuffix']],
\ 'pegprimary' : ['sequence', [['choice',[['nonterminal','pegregexp'], ['nonterminal','pegliteral'], ['nonterminal', 'pegfunction'], ['sequence', [['nonterminal','pegidentifier'], ['not', ['nonterminal','pegassignment']]], ['s:trNonterminal']], ['sequence',[['regexp','\s*(\s*'],['nonterminal','pegexpression'],['regexp','\s*)\s*']], ['s:takeSecond']]]], ['zeroormore', ['nonterminal','pegtransform']] ], ['s:appendTransforms']],
\ 'pegtransform' : ['sequence', [['regexp', '\.'], ['regexp', '[a-zA-Z0-9_:]\+'], ['regexp', '('], ['zeroormore', ['regexp', '\s*"\%(\\.\|[^"]\)*"\s*,\?\s*']], ['regexp', '\s*)']], ['s:trTransform']],
\ 'pegfunction' : ['sequence', [['regexp', '[sg]:[a-zA-Z0-9_]\+'], ['regexp', '('], ['nonterminal', 'pegexpression'], ['regexp', '\s*)']], ['s:trFunction']],
\ 'pegidentifier' : ['regexp', '\s*[a-zA-Z_][a-zA-Z0-9_]*\s*', ['s:strip']],
\ 'pegregexp' : ['regexp', '\s*/\%(\\.\|[^/]\)*/\s*', ['s:trRegexp']],
\ 'pegliteral' : ['regexp', '\s*"\%(\\.\|[^"]\)*"\s*', ['s:trLiteral']],
\ 'pegassignment' : ['regexp', '\s*=']
\ }






fu! s:print_state(thing, ...)
	let rest = a:0 ? ' --- ' . join(a:000, ' --- ') : ''
	"let msg = '> '.a:function . ', '.string(a:arg).', Pos: ' . s:pos . rest
	let msg = '> ' . string(a:thing).', Pos: ' . s:pos . rest . ' --- ' . expand('<sfile>')
	if s:output_to_buffer
		call append(line('$'), msg)
	else
		echom msg
	endif
endf

function! s:print_result(fu, outcome)
	if s:debug
		let msg = '< ' . a:fu . ' ' .string(a:outcome)
		if s:output_to_buffer
			call append(line('$'), msg)
		else
			echom msg
		endif
	endif
endfunction



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
	let cache_key = s:pos . 'regexp' . a:thing[1] . string(g:peggi_additional_state)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let npos = matchend(s:string, '^'.a:thing[1], s:pos)
		if npos == s:pos
			let result = ''
		elseif npos != -1
			let result = s:string[s:pos : npos-1]
			let s:pos = npos
		else
			let result = g:fail
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, g:peggi_additional_state] | endif
	endif

	call s:print_result('regexp', outcome)
	return outcome
endf

"Tries to match the arg (without consuming) and applies the given function on
"the result
fu! s:parse_function(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . 'function' . string(a:thing[1]) . string(g:peggi_additional_state)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let old_pos = s:pos
		let arg = s:parse_{a:thing[1][1][0]}(a:thing[1][1])
		let s:pos = old_pos
		let result = s:parse_regexp(['regexp', call(a:thing[1][0], [arg])])

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, g:peggi_additional_state] | endif
	endif

	call s:print_result('function', outcome)
	return outcome
endf


"Returns: a list of whatever the subitems return or Fail (if one of them fails)
fu! s:parse_sequence(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . 'sequence' . string(a:thing[1]) . string(g:peggi_additional_state)
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
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, g:peggi_additional_state] | endif
	endif
	call s:print_result('sequence', outcome)
	return outcome
endf

"Returns: whatever the element behind the nonterminal returns
fu! s:parse_nonterminal(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . 'nonterminal' . string(a:thing[1]) . string(g:peggi_additional_state)
	let outcome = a:thing[1] == 'listbullet' || a:thing[1] == 'listnumber' ? s:cache_fail : s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let thing = s:grammar[a:thing[1]]
		let result = s:parse_{thing[0]}(thing)

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, g:peggi_additional_state] | endif
	endif
	call s:print_result('nonterminal: '.string(a:thing[1]), outcome)
	return outcome
endf

"Returns: whatever the first matching subelement returns, or Fail if all items fail
fu! s:parse_choice(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . 'choice' . string(a:thing[1]) . string(g:peggi_additional_state)
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
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, g:peggi_additional_state] | endif
	endif
	call s:print_result('choice', outcome)
	return outcome
endf

"Returns: whatever the subelement returns, or '' if it fails
fu! s:parse_optional(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . 'optional' . string(a:thing[1]) . string(g:peggi_additional_state)
	let outcome = s:query_cache(cache_key)
	if s:cache_fail(outcome)

		let old_pos = s:pos
		let result = s:parse_{a:thing[1][0]}(a:thing[1])
		if s:isfail(result)
			let s:pos = old_pos
			let result = ''
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, g:peggi_additional_state] | endif
	endif
	call s:print_result('optional', outcome)
	return outcome
endf

"Returns: a (possibliy empty) list of whatever the subitem returns, as long as it matches
fu! s:parse_zeroormore(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . 'zeroormore' . string(a:thing[1]) . string(g:peggi_additional_state)
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
		if s:concat_seqs
			let res_string = join(result, '')
			unlet result
			let result = res_string
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, g:peggi_additional_state] | endif
	endif
	call s:print_result('zeroormore', outcome)
	return outcome
endf

"Returns: a list of whatever the subitem returns, as long as it matches, or Fail if doesn't match
fu! s:parse_oneormore(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . 'oneormore' . string(a:thing[1]) . string(g:peggi_additional_state)
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
			if s:concat_seqs
				let result = first . join(rest, '')
			else
				let result = [first] + rest
			endif
		endif

		unlet outcome | let outcome = s:apply_transformations(result, a:thing[2:])
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, g:peggi_additional_state] | endif
	endif
	call s:print_result('oneormore', outcome)
	return outcome
endf

"Returns: '' if the given item matches, Fail otherwise
"does not consume any chars of the parsed string
fu! s:parse_and(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let cache_key = s:pos . 'and' . string(a:thing[1]) . string(g:peggi_additional_state)
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
		if s:packrat_enabled | let s:cache[cache_key] = [s:pos, outcome, g:peggi_additional_state] | endif
	endif
	call s:print_result('and', outcome)
	return outcome
endf

"Returns: '' if the given item matches not, Fail otherwise
"does not consume any chars of the parsed string
fu! s:parse_not(thing)
	if s:debug | call s:print_state(a:thing) | endif
	let result = s:parse_and(['and'] + a:thing[1:])
	if s:isfail(result)
		call s:print_result('not', '')
		return ''
	else
		call s:print_result('not', g:fail)
		return g:fail
	endif
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
				if s:output_to_buffer
					call append(line('$'), msg)
				else
					echom msg
				endif
			endif
			let g:peggi_additional_state = cache_content[2]
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
		if funk[0] =~ '[gs]:\l' && s:isfail(result)
			return g:fail
		endif
		unlet res
		let res = call(function(funk[0]), funk[1:] + [result])
		unlet result
		let result = res
	endfor
	return result
endf


fu! g:parse_begin(grammar, string, start)
	unlet! s:grammar

	if has_key(s:grammar_cache, a:grammar)
		let s:users_grammar = s:grammar_cache[a:grammar]
	else
		let s:debug = 0
		let s:cache = {}
		let s:pos = 0
		let s:grammar = s:peggi_grammar
		let s:concat_seqs = 0
		let s:string = a:grammar
		let s:users_grammar = s:parse_nonterminal(['nonterminal', 'peggrammar'])
		let s:grammar_cache[a:grammar] = s:users_grammar
	endif

	let s:packrat_enabled = 1
	if exists('g:peggi_debug') && g:peggi_debug >= 2
		call s:pprint(s:users_grammar)
	endif
	if exists('g:peggi_debug') && g:peggi_debug >= 1
		let s:debug = 1
	endif
	"return

	let s:cache = {}
	let s:pos = 0
	let s:grammar = s:users_grammar
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

