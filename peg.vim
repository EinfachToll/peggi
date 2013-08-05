
fu! s:print_state(function, arg)
	echom '> '.a:function . ', '.string(a:arg).', Pos: ' . g:pos . ' --- ' . expand('<sfile>')
endf


let g:pos = 0 " the global variable that indicates where we are in the string that is parsed

let g:debug = 1


" -----------------------------------------------------

"some transformation functions:
function! s:strip(string)
  let res = substitute(a:string, '^\s\+', '', '')
  return substitute(res, '\s\+$', '', '')
endfunction
let g:Strip = function("s:strip")

function! s:tag(tag, string)
	return '<'.a:tag.'>'.a:string.'</'.a:tag.'>'
endfunction
let g:Tag = function("s:tag")

function! s:concat(listofstrings)
	return join(a:listofstrings, '')
endfunction
let g:Concat = function("s:concat")

function! s:join(sep, listofstrings)
	return join(a:listofstrings, a:sep)
endfunction
let g:Join = function("s:join")

function! s:remove(string)
	return ''
endfunction
let g:Remove = function("s:remove")

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
	if g:debug | call s:print_state('regexp', a:regexp) | endif
	let npos = matchend(g:string, '^'.a:regexp, g:pos)
	if npos != -1
		let result = g:string[g:pos : npos-1]
		let g:pos = npos
		if g:debug | echom '>> regexp: '.string(result) | endif
		return result
	else
		if g:debug | echom '>> regexp: '.string(g:fail) | endif
		return g:fail
	endif
endf

"Returns: a list of whatever the subitems return or Fail (if one of them fails)
fu! s:parse_sequence(sequence)
	if g:debug | call s:print_state('sequence', a:sequence) | endif
	let old_pos = g:pos
	let result = []
	let res = ''
	for thing in a:sequence
		unlet res "necessary, because the type of the parse result may change
		let res = s:parse(thing)
		if s:isfail(res)
			let g:pos = old_pos
			if g:debug | echom '>> sequence: '.string(g:fail) | endif
			return g:fail
		else
			call add(result, res)
		endif
	endfor
	if g:debug | echom '>> sequence: '.string(a:sequence).": ".string(result) | endif
	return result
endf

"Returns: whatever the element behind the nonterminal returns
fu! s:parse_nonterminal(nonterminal)
	if g:debug | call s:print_state('nonterminal', a:nonterminal) | endif
	let nt = eval("g:".a:nonterminal)
	let result = s:parse(nt)
	if g:debug | echom '>> nonterminal: '.string(a:nonterminal).": ".string(result) | endif
	return result
endf

"Returns: whatever the first matching subelement returns, or Fail if all items fail
fu! s:parse_choice(choices)
	if g:debug | call s:print_state('choice', a:choices) | endif
	let old_pos = g:pos
	let res = ''
	for thing in a:choices
		unlet res "necessary, because the type of the parse result may change
		let res = s:parse(thing)
		if !s:isfail(res)
			if g:debug | echom '>> choices: '.string(res) | endif
			return res
		else
			let g:pos = old_pos
		endif
	endfor
	if g:debug | echom '>> choices: '.string(g:fail) | endif
	return g:fail
endf

"Returns: whatever the subelement returns, or '' if it fails
fu! s:parse_optional(thing)
	if g:debug | call s:print_state('optional', a:thing) | endif
	let old_pos = g:pos
	let res = s:parse(a:thing)
	if s:isfail(res)
		let g:pos = old_pos
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
		let res = s:parse(a:thing)
		if s:isfail(res)
			break
		else
			call add(result, res)
		endif
	endwhile
	if g:debug | echom '>> zom: '.string(result) | endif
	return result
endf

"Returns: a list of whatever the subitem returns, as long as it matches, or Fail if doesn't match
fu! s:parse_oneormore(thing)
	if g:debug | call s:print_state('oneormore', a:thing) | endif
	let first = s:parse(a:thing)
	if !s:isfail(first)
		let rest = s:parse_zeroormore(a:thing)
		call insert(rest, first)
		if g:debug | echom '>> oom: '.string(rest) | endif
		return rest
	else
		if g:debug | echom '>> oom: '.string(g:fail) | endif
		return g:fail
	endif
endf

"Returns: '' if the given item matches, Fail otherwise
"does not consume any chars of the parsed string
fu! s:parse_and(thing)
	if g:debug | call s:print_state('and', a:thing) | endif
	let old_pos = g:pos
	let res = s:parse(a:thing)
	let g:pos = old_pos
	if s:isfail(res)
		if g:debug | echom '>> and: '.string(g:fail) | endif
		return g:fail
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
		if g:debug | echom '>> not: '.string(g:fail) | endif
		return g:fail
	endif
endf


"Calls the proper parse_* function for the given item
"afterwards, performs the transformation on the result
"
"We cache the input values (a:thing and g:pos) and the corresponding result
"this is called packrat parsing. At least I think so.
let g:cache = {}
fu! s:parse(thing)
	if g:debug | call s:print_state('parse', a:thing) | endif

	let cache_key = string(a:thing) . string(g:pos)
	if has_key(g:cache, cache_key)
		echom "Yayyyyyyyyy, cache hit!"
		let cache_content = g:cache[cache_key]
		let g:pos = cache_content[1]
		return cache_content[0]
	endif

	let type = a:thing[0]
	let thing = a:thing[1]
	let result = s:parse_{type}(thing)
	if s:isfail(result)
		let g:cache[cache_key] = [g:fail, g:pos]
		return g:fail
	endif
	if len(a:thing) > 2
		let functions = a:thing[2:]
		for funk in functions
			let res = call(funk[0], funk[1:] + [result])
			unlet result
			let result = res
		endfor
	endif
	let g:cache[cache_key] = [result, g:pos]
	return result
endf



" ------------------------------------------------
"  an Example: parse a table and transform it to HTML


"the Syntax for a grammar for now:
"the rules are nested lists of the form ['type of the PEG element', subelement, transformation function]
let bar = ['regexp', '[|│]', [g:Remove]]
let cell = ['regexp', '[a-zA-Z0-9 ]\+', [g:Strip]]
let table_line = ['sequence', [ ['nonterminal', 'bar'], ['oneormore', ['sequence', [['nonterminal', 'cell', [g:Tag,'td']], ['nonterminal', 'bar']], [g:Concat] ], [g:Concat]]], [g:Concat]]
let table_header_line = ['sequence', [ ['nonterminal', 'bar'], ['oneormore', ['sequence', [['nonterminal', 'cell', [g:Tag,'th']], ['nonterminal', 'bar']], [g:Concat]], [g:Concat]]], [g:Concat]]
let table_div = ['regexp', '|[-|]\+|']
let table_header = ['sequence', [ ['nonterminal', 'table_header_line', [g:Tag,'tr']], ['sequence', [ ['regexp','\n'] , ['nonterminal','table_div'] , ['regexp','\n'] ], [g:Remove]] ], [g:Concat]]
let table_block = ['sequence', [ ['nonterminal','table_line', [g:Tag,'tr']], ['zeroormore', ['sequence',[['regexp','\n', [g:Remove]],['nonterminal','table_line', [g:Tag,'tr']]], [g:Concat]], [g:Concat]] ], [g:Concat]]
let table = ['sequence', [['optional',['nonterminal','table_header']], ['nonterminal','table_block'] , ['regexp','$']] , [g:Concat], [g:Tag,'table']]

"the string to be parsed:
let g:string = "|hm|\n|--|\n| blabla | soso | lala │ naja |\n|b|d|"

"start parsing:
echom ">>> ".string(s:parse(table))


"the Syntax for a grammar as I want it someday
"let bar = "remove(/[|│]/)"
"let cell = "strip(/[a-zA-Z0-9 ]\+/)"
"let table_line = "< bar, tag('td', cell) >"
"let table_header_line = "< bar, tag('th', cell) >"
"let table_div = "/|[-|]\+|/"
"let table_header = "tag('tr', table_header_line) + remove(/\n/ + table_div + /\n/)"
"let table_block = "< tag('tr', table_line), remove(/\n/) >"
"let table = "tag('table', table_header? + table_block + /$/)"



"let g:pos = 0
"let g:string = "bla"
"let ein = ['regexp', 'bla', [g:Strip]]
"let ein = ['regexp', 'bla', [g:Tag, 'so']]
"let ein = ['sequence', [['regexp', 'bl', [g:Strip]],['regexp','a']], [g:Join, '+']]
"let ein = ['sequence', [['regexp','bl'],['nonterminal','beispiel']]]
"let beispiel = ['regexp', 'a', [g:Strip]]
"let ein = ['choice', [['regexp','blaf'], ['regexp','bla']], [g:Tag, 'la']]
"let ein = ['sequence', [['optional', ['regexp','l']], ['regexp','bla']]]
"let ein = ['sequence', [['zeroormore', ['regexp','r']], ['regexp','bla']]]
"let ein = ['sequence', [['oneormore', ['regexp','b'], [g:Concat]], ['regexp','la']], [g:Concat]]
"let ein = ['and', ['regexp','bl']]
"let ein = ['not', ['regexp','blö']]
"echom ">>> ".string(s:parse(ein))
