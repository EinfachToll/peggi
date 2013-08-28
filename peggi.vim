let s:concat_seqs = 1
let s:debug = 0
let s:packrat_enabled = 1
let g:peggi_additional_state = 0

" ------------------------------------------------
"  pretty print function for arbitrary types:

fu! s:pprint(thing)
	let f = s:format(a:thing, 0)
	let bla = 0
	for line in f
		unlet bla
		let bla = line
		echom string(bla)
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
	return '<'.a:tag.'>'.a:string.'</'.a:tag.'>'
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

fu! s:trLiteral(string)
	let str = s:strip(a:string)
	let str = str[1:-2]
	let str = escape(str, '.*[]\^$')
	let str = '\s*'.str.'\s*'
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
	return ['function', [funk, a:list[2]]]
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
\ 'pegidentifier' : ['regexp', '\s*[a-zA-Z_][a-zA-Z0-9_]*\s*'],
\ 'pegregexp' : ['regexp', '\s*/\%(\\.\|[^/]\)*/\s*', ['s:trRegexp']],
\ 'pegliteral' : ['regexp', '\s*"\%(\\.\|[^"]\)*"\s*', ['s:trLiteral']],
\ 'pegassignment' : ['regexp', '\s*=']
\ }






fu! s:print_state(function, arg, ...)
	let rest = a:0 ? ' --- ' . join(a:000, ' --- ') : ''
	echom '> '.a:function . ', '.string(a:arg).', Pos: ' . s:pos . rest . ' --- ' . expand('<sfile>')
endf




" ------------------------------------------------
"
" this is what some parse_* functions return if they don't match
let g:fail = 'fail'

fu! s:isfail(result)
	return type(a:result) == 1 && a:result == g:fail
endf

" ------------------------------------------------
" the various parse functions for every element of a PEG grammar

"Returns: the matched string or Fail
fu! s:parse_regexp(regexp)
	if s:debug | call s:print_state('regexp', a:regexp, strpart(s:string, s:pos)) | endif
	let npos = matchend(s:string, '^'.a:regexp, s:pos)
	"echom '+++' . s:string . ' ^'.a:regexp . s:pos . ' ' . npos
	if npos == s:pos
		if s:debug | echom '>> regexp: '.string('') | endif
		return ''
	elseif npos != -1
		let result = s:string[s:pos : npos-1]
		let s:pos = npos
		if s:debug | echom '>> regexp: '.string(result) | endif
		return result
	else
		if s:debug | echom '>> regexp: '.string(g:fail) | endif
		return g:fail
	endif
endf

"Tries to match the arg (without consuming) and applies the given function on
"the result
fu! s:parse_function(funandargs)
	if s:debug | call s:print_state('function', string(a:funandargs)) | endif
	let old_pos = s:pos
	let res = s:parse_thing(a:funandargs[1])
	let s:pos = old_pos
	let value = call(a:funandargs[0], [res])
	if s:debug | echom '>> function: '.string(value) | endif
	return s:parse_regexp(value)
endf


"Returns: a list of whatever the subitems return or Fail (if one of them fails)
fu! s:parse_sequence(sequence)
	if s:debug | call s:print_state('sequence', a:sequence) | endif
	let old_pos = s:pos
	let result = []
	let res = ''
	for thing in a:sequence
		unlet res "necessary, because the type of the parse result may change
		let res = s:parse_thing(thing)
		if s:isfail(res)
			let s:pos = old_pos
			if s:debug | echom '>> sequence: '.string(g:fail) | endif
			return g:fail
		else
			call add(result, res)
		endif
	endfor
	if s:concat_seqs 
		let res_string = join(result, '')
		unlet result
		let result = res_string
	endif
	if s:debug | echom '>> sequence: '.string(a:sequence).": ".string(result) | endif
	return result
endf

"Returns: whatever the element behind the nonterminal returns
fu! s:parse_nonterminal(nonterminal)
	if s:debug | call s:print_state('nonterminal', a:nonterminal) | endif
	let nt = s:grammar[a:nonterminal]
	let result = s:parse_thing(nt)
	if s:debug | echom '>> nonterminal: '.string(a:nonterminal).": ".string(result) | endif
	return result
endf

"Returns: whatever the first matching subelement returns, or Fail if all items fail
fu! s:parse_choice(choices)
	if s:debug | call s:print_state('choice', a:choices) | endif
	let old_pos = s:pos
	let res = ''
	for thing in a:choices
		unlet res "necessary, because the type of the parse result may change
		let res = s:parse_thing(thing)
		if !s:isfail(res)
			if s:debug | echom '>> choices: '.string(res) | endif
			return res
		else
			let s:pos = old_pos
		endif
	endfor
	if s:debug | echom '>> choices: '.string(g:fail) | endif
	return g:fail
endf

"Returns: whatever the subelement returns, or '' if it fails
fu! s:parse_optional(thing)
	if s:debug | call s:print_state('optional', a:thing) | endif
	let old_pos = s:pos
	let res = s:parse_thing(a:thing)
	if s:isfail(res)
		let s:pos = old_pos
		if s:debug | echom '>> optional: '.string('') | endif
		return ''
	endif
	if s:debug | echom '>> optional: '.string(res) | endif
	return res
endf

"Returns: a (possibliy empty) list of whatever the subitem returns, as long as it matches
fu! s:parse_zeroormore(thing)
	if s:debug | call s:print_state('zeroormore', a:thing) | endif
	let result = []
	let res = ''
	while 1
		unlet res "necessary, because the type of the parse result may change
		let res = s:parse_thing(a:thing)
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
	if s:debug | echom '>> zom: '.string(result) | endif
	return result
endf

"Returns: a list of whatever the subitem returns, as long as it matches, or Fail if doesn't match
fu! s:parse_oneormore(thing)
	if s:debug | call s:print_state('oneormore', a:thing) | endif
	let first = s:parse_thing(a:thing)
	if !s:isfail(first)
		let rest = s:parse_zeroormore(a:thing)
		if s:concat_seqs 
			let rest = first . rest
		else
			call insert(rest, first)
		endif
		if s:debug | echom '>> oom: '.string(rest) | endif
		return rest
	else
		if s:debug | echom '>> oom: '.string(g:fail) | endif
		return g:fail
	endif
endf

"Returns: '' if the given item matches, Fail otherwise
"does not consume any chars of the parsed string
fu! s:parse_and(thing)
	if s:debug | call s:print_state('and', a:thing) | endif
	let old_pos = s:pos
	let res = s:parse_thing(a:thing)
	let s:pos = old_pos
	if s:isfail(res)
		if s:debug | echom '>> and: '.string(g:fail) | endif
		return g:fail
	else
		if s:debug | echom '>> and: '.string('') | endif
		return ''
	endif
endf

"Returns: '' if the given item matches not, Fail otherwise
"does not consume any chars of the parsed string
fu! s:parse_not(thing)
	if s:debug | call s:print_state('not', a:thing) | endif
	let result = s:parse_and(a:thing)
	if s:isfail(result)
		if s:debug | echom '>> not: '.string('') | endif
		return ''
	else
		if s:debug | echom '>> not: '.string(g:fail) | endif
		return g:fail
	endif
endf


"Calls the proper parse_* function for the given item
"afterwards, performs the transformation on the result
"
"We cache the input values (a:thing and s:pos) and the corresponding result
"this is called packrat parsing. At least I think so.
fu! s:parse_thing(thing)
	"if s:debug | call s:print_state('parse', a:thing) | endif

	if s:packrat_enabled
		let cache_key = s:pos . string(a:thing) . string(g:peggi_additional_state)
		if has_key(s:cache, cache_key)
			let cache_content = s:cache[cache_key]
			let s:pos = cache_content[0]
			"echom "Yayyyyyyyyy, cache hit! -> " . cache_key . " ----- " . string(cache_content)
			let g:peggi_additional_state = cache_content[2]
			return cache_content[1]
		endif
	endif

	let type = a:thing[0]
	let subrule = a:thing[1]
	let result = s:parse_{type}(subrule)
	if len(a:thing) > 2
		let functions = a:thing[2:]
		for funk in functions
			if funk[0] =~ '[gs]:\l' && s:isfail(result)
				if s:packrat_enabled | let s:cache[cache_key] = [s:pos, g:fail, g:peggi_additional_state] | endif
				return g:fail
			endif
			let res = call(function(funk[0]), funk[1:] + [result])
			unlet result
			let result = res
		endfor
	endif
	if s:packrat_enabled | let s:cache[cache_key] = [s:pos, result, g:peggi_additional_state] | endif
	return result
endf


fu! g:parse_begin(grammar, string, start)
	unlet! s:grammar
	let s:debug = 0
	let s:cache = {}
	let s:pos = 0
	let s:grammar = s:peggi_grammar
	let s:concat_seqs = 0
	let s:string = a:grammar
	let s:users_grammar = s:parse_nonterminal('peggrammar')


	if exists('g:peggi_debug') && g:peggi_debug
		let s:debug = 1
		call s:pprint(s:users_grammar)
	endif
	"return

	let s:cache = {}
	let s:pos = 0
	let s:grammar = s:users_grammar
	let s:concat_seqs = 1
	let s:string = a:string

	return s:parse_nonterminal(a:start)
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
	return g:parse(a:grammar, join(readfile(a:file), "\n")."\n", a:start)
endf

fu! g:parse_file_begin(grammar, file, start)
	return g:parse_begin(a:grammar, join(readfile(a:file), "\n")."\n", a:start)
endf

