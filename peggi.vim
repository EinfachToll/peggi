let s:concat_seqs = 1

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

function! s:concat(listofstrings)
	return join(a:listofstrings, '')
endfunction

function! s:join(sep, listofstrings)
	return join(a:listofstrings, a:sep)
endfunction

function! s:skip(string)
	return ''
endfunction

fu! s:TrLiteral(string)
	let str = s:strip(a:string)
	let str = str[1:-2]
	let str = escape(str, '.*[]\^$')
	let str = '\s*'.str.'\s*'
	return ['regexp', str]
endf

fu! s:TrRegexp(string)
	let str = s:strip(a:string)
	let str = str[1:-2]
	let str = substitute(str, '\\/', '/', 'g')
	let str = '\s*'.str
	return ['regexp', str]
endf

fu! s:TrNonterminal(list)
	let str = s:strip(a:list[0])
	return ['nonterminal', str]
endf

fu! s:TrSuffix(list)
	let suffix = s:strip(a:list[1])
	let thing = a:list[0]
	if suffix == '?' | return ['optional', thing] | endif
	if suffix == '+' | return ['oneormore', thing] | endif
	if suffix == '*' | return ['zeroormore', thing] | endif
	return thing
endf

fu! s:TrPrefix(list)
	let prefix = s:strip(a:list[0])
	let thing = a:list[1]
	if prefix == '&' | return ['and', thing] | endif
	if prefix == '!' | return ['not', thing] | endif
	return thing
endf

fu! s:TrSequence(list)
	if len(a:list) == 1
		return a:list[0]
	endif
	return ['sequence', a:list]
endf

fu! s:TrChoice(list)
	if empty(a:list[1])
		return a:list[0]
	endif
	let trseq = [a:list[0]]
	for seq in a:list[1]
		call add(trseq, seq[1])
	endfor
	return ['choice', trseq]
endf

fu! s:TrDefinition(list)
	let nt = s:strip(a:list[0])
	return [nt, a:list[2]]
endf

fu! s:TakeSecond(list)
	return a:list[1]
endf

fu! s:TrTransform(list)
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

fu! s:AppendTransforms(list)
	return a:list[0] + a:list[1]
endf

fu! s:MakeGrammar(lists)
	let grammar = {}
	for lst in a:lists
		let grammar[lst[0]] = lst[1]
	endfor
	return grammar
endf


" ------------------------------------------------
"  the following defines the raw grammar for the nice grammar


let s:peggi_grammar = {
\ 'peggrammar' : ['oneormore', ['nonterminal', 'pegdefinition'], ['s:MakeGrammar']],
\ 'pegdefinition' : ['sequence', [['nonterminal', 'pegidentifier'], ['nonterminal','pegassignment'], ['nonterminal','pegexpression']], ['s:TrDefinition']],
\ 'pegexpression' : ['sequence', [['nonterminal','pegsequence'], ['zeroormore',['sequence',[['regexp','\s*|\s*'], ['nonterminal','pegsequence']]]]], ['s:TrChoice']],
\ 'pegsequence' : ['zeroormore', ['nonterminal', 'pegprefix'], ['s:TrSequence']],
\ 'pegprefix' : ['sequence', [['optional',['choice',[['regexp','\s*&\s*'], ['regexp','\s*!\s*']]]], ['nonterminal','pegsuffix']], ['s:TrPrefix']],
\ 'pegsuffix' : ['sequence', [['nonterminal','pegprimary'], ['optional',['choice',[['regexp','\s*?\s*'],['regexp','\s*\*\s*'],['regexp','\s*+\s*']]]]], ['s:TrSuffix']],
\ 'pegprimary' : ['sequence', [['choice',[['nonterminal','pegregexp'], ['nonterminal','pegliteral'], ['sequence', [['nonterminal','pegidentifier'], ['not', ['nonterminal','pegassignment']]], ['s:TrNonterminal']], ['sequence',[['regexp','\s*(\s*'],['nonterminal','pegexpression'],['regexp','\s*)\s*']], ['s:TakeSecond']]]], ['zeroormore', ['nonterminal','pegtransform']] ], ['s:AppendTransforms']],
\ 'pegtransform' : ['sequence', [['regexp', '\.'], ['regexp', '[a-zA-Z0-9_:]\+'], ['regexp', '('], ['zeroormore', ['regexp', '\s*"\%(\\.\|[^"]\)*"\s*,\?\s*']], ['regexp', '\s*)']], ['s:TrTransform']],
\ 'pegidentifier' : ['regexp', '\s*[a-zA-Z_][a-zA-Z0-9_]*\s*'],
\ 'pegregexp' : ['regexp', '\s*/\%(\\.\|[^/]\)*/\s*', ['s:TrRegexp']],
\ 'pegliteral' : ['regexp', '\s*"\%(\\.\|[^"]\)*"\s*', ['s:TrLiteral']],
\ 'pegassignment' : ['regexp', '\s*=']
\ }

"let g:string = 'asd wef /sdf/ "fw" | bla'
"let g:string = '!/df_bla/?"so!*+so"*|   (hm |!/bla d/)'
"let g:string = '!/adf/ + sdf | (ahm | jo)'
"let g:string = 'adf | ahm | jo'
"echom ">>>".string(s:parse_st(pegdefinition))





fu! s:print_state(function, arg)
	echom '> '.a:function . ', '.string(a:arg).', Pos: ' . s:pos . ' --- ' . expand('<sfile>')
endf


let g:debug = 1


" ------------------------------------------------
"
" this is what some parse_* functions return if they don't match
let s:fail = 'fail'

fu! s:isfail(result)
	return type(a:result) == 1 && a:result == s:fail
endf

" ------------------------------------------------
" the various parse functions for every element of a PEG grammar

"Returns: the matched string or Fail
fu! s:parse_regexp(regexp)
	if g:debug | call s:print_state('regexp', a:regexp) | endif
	let npos = matchend(s:string, '^'.a:regexp, s:pos)
	if npos != -1
		let result = s:string[s:pos : npos-1]
		let s:pos = npos
		if g:debug | echom '>> regexp: '.string(result) | endif
		return result
	else
		if g:debug | echom '>> regexp: '.string(s:fail) | endif
		return s:fail
	endif
endf

"Returns: a list of whatever the subitems return or Fail (if one of them fails)
fu! s:parse_sequence(sequence)
	if g:debug | call s:print_state('sequence', a:sequence) | endif
	let old_pos = s:pos
	let result = []
	let res = ''
	for thing in a:sequence
		unlet res "necessary, because the type of the parse result may change
		let res = s:parse_st(thing)
		if s:isfail(res)
			let s:pos = old_pos
			if g:debug | echom '>> sequence: '.string(s:fail) | endif
			return s:fail
		else
			call add(result, res)
		endif
	endfor
	if s:concat_seqs 
		let res_string = join(result, '')
		unlet result
		let result = res_string
	endif
	if g:debug | echom '>> sequence: '.string(a:sequence).": ".string(result) | endif
	return result
endf

"Returns: whatever the element behind the nonterminal returns
fu! s:parse_nonterminal(nonterminal)
	if g:debug | call s:print_state('nonterminal', a:nonterminal) | endif
	let nt = s:grammar[a:nonterminal]
	let result = s:parse_st(nt)
	if g:debug | echom '>> nonterminal: '.string(a:nonterminal).": ".string(result) | endif
	return result
endf

"Returns: whatever the first matching subelement returns, or Fail if all items fail
fu! s:parse_choice(choices)
	if g:debug | call s:print_state('choice', a:choices) | endif
	let old_pos = s:pos
	let res = ''
	for thing in a:choices
		unlet res "necessary, because the type of the parse result may change
		let res = s:parse_st(thing)
		if !s:isfail(res)
			if g:debug | echom '>> choices: '.string(res) | endif
			return res
		else
			let s:pos = old_pos
		endif
	endfor
	if g:debug | echom '>> choices: '.string(s:fail) | endif
	return s:fail
endf

"Returns: whatever the subelement returns, or '' if it fails
fu! s:parse_optional(thing)
	if g:debug | call s:print_state('optional', a:thing) | endif
	let old_pos = s:pos
	let res = s:parse_st(a:thing)
	if s:isfail(res)
		let s:pos = old_pos
		if g:debug | echom '>> optional: '.string('') | endif
		return ''
	endif
	if g:debug | echom '>> optional: '.string(res) | endif
	return res
endf

"Returns: a (possibliy empty) list of whatever the subitem returns, as long as it matches
fu! s:parse_zeroormore(thing)
	if g:debug | call s:print_state('zeroormore', a:thing) | endif
	let result = []
	let res = ''
	while 1
		unlet res "necessary, because the type of the parse result may change
		let res = s:parse_st(a:thing)
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
	if g:debug | echom '>> zom: '.string(result) | endif
	return result
endf

"Returns: a list of whatever the subitem returns, as long as it matches, or Fail if doesn't match
fu! s:parse_oneormore(thing)
	if g:debug | call s:print_state('oneormore', a:thing) | endif
	let first = s:parse_st(a:thing)
	if !s:isfail(first)
		let rest = s:parse_zeroormore(a:thing)
		if s:concat_seqs 
			let rest = first . rest
		else
			call insert(rest, first)
		endif
		if g:debug | echom '>> oom: '.string(rest) | endif
		return rest
	else
		if g:debug | echom '>> oom: '.string(s:fail) | endif
		return s:fail
	endif
endf

"Returns: '' if the given item matches, Fail otherwise
"does not consume any chars of the parsed string
fu! s:parse_and(thing)
	if g:debug | call s:print_state('and', a:thing) | endif
	let old_pos = s:pos
	let res = s:parse_st(a:thing)
	let s:pos = old_pos
	if s:isfail(res)
		if g:debug | echom '>> and: '.string(s:fail) | endif
		return s:fail
	else
		if g:debug | echom '>> and: '.string('') | endif
		return ''
	endif
endf

"Returns: '' if the given item matches not, Fail otherwise
"does not consume any chars of the parsed string
fu! s:parse_not(thing)
	if g:debug | call s:print_state('not', a:thing) | endif
	let result = s:parse_and(a:thing)
	if s:isfail(result)
		if g:debug | echom '>> not: '.string('') | endif
		return ''
	else
		if g:debug | echom '>> not: '.string(s:fail) | endif
		return s:fail
	endif
endf


"Calls the proper parse_* function for the given item
"afterwards, performs the transformation on the result
"
"We cache the input values (a:thing and s:pos) and the corresponding result
"this is called packrat parsing. At least I think so.
let g:cache = {}
fu! s:parse_st(nt)
	if g:debug | call s:print_state('parse', a:nt) | endif

	"XXX irgendwie das nt statt dem ganzen inhalt speichern
	"let cache_key = s:pos . string(a:nt)
	"if has_key(g:cache, cache_key)
	"	echom "Yayyyyyyyyy, cache hit!"
	"	let cache_content = g:cache[cache_key]
	"	let s:pos = cache_content[0]
	"	return cache_content[1]
	"endif

	let type = a:nt[0]
	let subrule = a:nt[1]
	let result = s:parse_{type}(subrule)
	if s:isfail(result)
		"let g:cache[cache_key] = [s:pos, s:fail]
		return s:fail
	endif
	if len(a:nt) > 2
		let functions = a:nt[2:]
		for funk in functions
			let res = call(function(funk[0]), funk[1:] + [result])
			unlet result
			let result = res
		endfor
	endif
	"let g:cache[cache_key] = [s:pos, result]
	return result
endf


fu! g:parse_begin(grammar, string, start)
	let s:grammar = s:peggi_grammar
	let s:pos = 0
	let s:concat_seqs = 0

	let s:string = a:grammar
	let s:users_grammar = s:parse_st(s:grammar['peggrammar'])
	call s:pprint(s:users_grammar)

	let s:concat_seqs = 1
	let s:grammar = s:users_grammar
	let s:string = a:string
	let s:pos = 0
	return s:parse_st(s:grammar[a:start])
endf

fu! g:parse(grammar, string, start)
	let result = g:parse_begin(a:grammar, a:string, a:start)
	if strlen(s:string) > s:pos
		return s:fail
	else
		return result
	endif
endf


