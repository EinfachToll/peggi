set maxfuncdepth=1000000
let s:debug = 0
let s:grammar_cache = {}
let s:inline_nonterminals = 2
let s:indent_stack = [-1]
if !exists("g:peggi_transformation_prefix")
	let g:peggi_transformation_prefix = ''
endif


function! s:print_state(thing, ...)
	let rest = a:0 ? ' --- ' . join(a:000, ' --- ') : ''
	let msg = '-> ' . string(a:thing).', pos: ' . s:pos . rest . ', call stack: ' . expand('<sfile>')
	call append(line('$'), msg)
endfunction


function! s:print_indentation_stack()
	let msg = '- indentation stack: '.string(s:indent_stack)
	call append(line('$'), msg)
endfunction


function! s:print_result(fun, outcome)
	let msg = '<- ' . a:fun . ' ' .string(a:outcome)
	call append(line('$'), msg)
endfunction



" -----------------------------------------------------
"some transformation functions:

let s:available_transformations = ['strip', 'tag', 'replace', 'surround', 'concat', 'join', 'skip', 'take', 'insertfirst']


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


function! s:replace(origin, target)
	return a:target
endfunction


function! s:surround(string, before, after)
	return a:before . a:string . a:after
endfunction


function! s:concat(listofstrings)
	return join(a:listofstrings, '')
endfunction


function! s:join(listofstrings, sep)
	return join(a:listofstrings, a:sep)
endfunction


function! s:skip(string)
	return ''
endfunction


function! s:take(list, n)
	let n = eval(a:n)
	return a:list[n]
endfunction


function! s:insertfirst(list)
	let first_thing = a:list[0]
	let restlist = a:list[1]
	return [first_thing] + restlist
endfunction


" -----------------------------------------------------
" Transformation functions used for creating the grammar:

function! s:indent_gt_stack(whitespaces)
	if g:peggi_debug >= 1 | call s:print_indentation_stack() | endif
	return strdisplaywidth(a:whitespaces, 0) > s:indent_stack[-1] ? a:whitespaces : g:fail
endfunction


function! s:indent_ge_stack(whitespaces)
	if g:peggi_debug >= 1 | call s:print_indentation_stack() | endif
	return strdisplaywidth(a:whitespaces, 0) >= s:indent_stack[-1] ? a:whitespaces : g:fail
endfunction


function! s:trLiteral(string)
	let str = s:strip(a:string)
	let str = str[1:-2]
	let str = escape(str, '.*[]\^$')
	let str = '\s*'.str
	return ['regexp', str]
endfunction


function! s:trRegexp(string)
	let str = s:strip(a:string)
	let str = str[1:-2]
	let str = substitute(str, '\\/', '/', 'g')
	let str = '\s*'.str
	return ['regexp', str]
endfunction


function! s:trNonterminal(string)
	let str = s:strip(a:string)
	return ['nonterminal', str]
endfunction


function! s:trSuffix(list)
	let suffix = s:strip(a:list[1])
	let thing = a:list[0]
	if suffix == '?' | return ['optional', thing] | endif
	if suffix == '+' | return ['oneormoreconcat', thing] | endif
	if suffix == '#' | return ['oneormorelist', thing] | endif
	if suffix == '°' | return ['zeroormoreconcat', thing] | endif
	if suffix == '*' | return ['zeroormorelist', thing] | endif
	return thing
endfunction


function! s:trPrefix(list)
	let prefix = s:strip(a:list[0])
	let thing = a:list[1]
	if prefix == '&' | return ['and', thing] | endif
	if prefix == '!' | return ['not', thing] | endif
	return thing
endfunction


function! s:trSequenceConc(list)
	if len(a:list) == 1
		return a:list[0]
	endif
	return ['sequence_concatenated', a:list]
endfunction


function! s:trSequenceList(list)
	let first_thing = a:list[0]
	let other_things = a:list[1]
	if empty(other_things)
		return first_thing
	endif
	let trseq = [first_thing]
	for i in range(len(other_things))
		if i % 2 == 0
			continue
		endif
		call add(trseq, other_things[i])
	endfor
	return ['sequence_list', trseq]
endfunction


function! s:trChoice(list)
	let first_thing = a:list[0]
	let other_things = a:list[1]
	if empty(other_things)
		return first_thing
	endif
	let trseq = [first_thing]
	for i in range(len(other_things))
		if i % 2 == 0
			continue
		endif
		call add(trseq, other_things[i])
	endfor
	return ['choice', trseq]
endfunction


function! s:trDefinition(list)
	let nt = s:strip(a:list[0])
	let is_indentation_nt = (a:list[1] != '')
	return [nt, is_indentation_nt, a:list[3]]
endfunction


function! s:trTransform(list)
	let funk = a:list[1]
	if index(s:available_transformations, funk) >= 0
		let funk = 's:'.funk
	elseif funk !~# '^[gs]:'
		let funk = g:peggi_transformation_prefix . funk
	endif

	let good_args = []
	for arg in a:list[3]
		let a = substitute(arg, '^\s*"', '', '')
		let a = substitute(a, '"\s*,\?\s*$', '', '')
		let a = substitute(a, '\\"', '"', 'g')
		call add(good_args, a)
	endfor
	return [funk] + good_args
endfunction


function! s:trIndentGT(string)
	return ['regexp', '\s*', ['s:indent_gt_stack']]
endfunction


function! s:trIndentGE(string)
	return ['regexp', '\s*', ['s:indent_ge_stack']]
endfunction


"for a given rule, replace every occurrence of a nonterminal thing on it's
"right side by a nonterminal_indent thing if it is in a:indentation_nts
function! s:replace_nts(rule, indentation_nts)
	if a:rule[0] == 'nonterminal'
		if index(a:indentation_nts, a:rule[1]) > -1
			return ['nonterminal_indent'] + a:rule[1:]
		endif
		return a:rule
	elseif a:rule[0] == 'regexp'
		return a:rule
	elseif a:rule[0] == 'sequence_list' || a:rule[0] == 'sequence_concatenated' || a:rule[0] == 'choice'
		let result = []
		for subitem in a:rule[1]
			call add(result, s:replace_nts(subitem, a:indentation_nts))
		endfor
		return [a:rule[0]] + [result] + a:rule[2:]
	else
		return [a:rule[0]] + [s:replace_nts(a:rule[1], a:indentation_nts)] + a:rule[2:]
	endif
endfunction


function! s:trMakeGrammar(list_of_definitions)
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
endfunction



" ------------------------------------------------
" nonterminal inlining stuff

function! s:nts_on_right_side(rule)
	if a:rule[0] == 'nonterminal'
		return [a:rule[1]]
	elseif a:rule[0] == 'regexp' || a:rule[0] == 'nonterminal_indent'
		return []
	elseif a:rule[0] == 'sequence_list' || a:rule[0] == 'sequence_concatenated' || a:rule[0] == 'choice'
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
	elseif a:rule[0] == 'sequence_list' || a:rule[0] == 'sequence_concatenated' || a:rule[0] == 'choice'
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
" definition of Peggi's grammar

" the grammar described by itself, for illustration:

" peggrammar = (pegdefinition#).s:trMakeGrammar()
" pegdefinition = (pegidentifier, pegindentnt?, pegassignment, pegexpression, pegcomment?).s:trDefinition() {-> [identifiername, bool, thing]}
" pegexpression = (pegsequencelist, (/\s*|\s*/ , pegsequencelist)°).s:trChoice()  {-> thing}
" pegsequencelist = (pegsequenceconc , (/\s*,/ , pegsequenceconc)°).s:trSequenceList() {-> thing}
" pegsequenceconc = (pegprefix#).s:trSequenceConc() {-> thing}
" pegprefix = ((/\s*&\s*/ | /\s*!\s*/)? , pegsuffix).s:trPrefix() {-> thing}
" pegsuffix = (pegprimary , (/\s*?\s*/ | /\s*\*\s*/ | /\s*+\s*/ | /\s*°\s*/ | /\s*#\s*/)?).s:trSuffix() {-> thing}
" pegprimary = (( pegregexp | pegliteral | pegindentgreaterequal | pegindentgreater | (pegidentifier !pegindentnt !pegassignment).s:trNonterminal() | (/\s*(\s*/ , pegexpression , /\s*)\s*/).g:take("1") ) ,  pegtransform*) {-> [thing, [[funktion, arg1, arg2, …]]]}
" pegtransform = (/\./ , /[a-zA-Z0-9_:]\+/ , /(/ , (/\s*"\%(\\.\|[^"]\)*"\s*,\?\s*/)* , /\s*)/).s:trTransform() {-> [funktion, arg1, arg2, …]}
" pegidentifier = /\s*[a-zA-Z_][a-zA-Z0-9_]*\s*/.s:strip() {-> string}
" pegregexp = /\s*/\%(\\.\|[^/]\)*/\s*/.s:trRegexp() {-> thing}
" pegliteral = /\s*"\%(\\.\|[^"]\)*"\s*/.s:trLiteral() {-> thing}
" pegassignment = /\s*=/ {-> string}
" pegindentnt = /\s*\^/ {-> string}
" pegindentgreaterequal = /\s*>=/.s:trIndentGE() {-> thing}
" pegindentgreater = /\s*>/.s:trIndentGT() {-> thing}
" pegcomment = /\s*{[^}]*}\s*/.skip() {-> string}


"  the raw grammar for the nice grammar:
let s:peggi_grammar = {
\ 'peggrammar' : ['oneormorelist', ['nonterminal', 'pegdefinition'], ['s:trMakeGrammar']],
\ 'pegdefinition' : ['sequence_list', [['nonterminal', 'pegidentifier'], ['optional', ['nonterminal','pegindentnt']], ['nonterminal','pegassignment'], ['nonterminal','pegexpression'], ['optional', ['nonterminal','pegcomment']]], ['s:trDefinition']],
\ 'pegexpression' : ['sequence_list', [['nonterminal','pegsequencelist'], ['zeroormoreconcat',['sequence_list',[['regexp','\s*|\s*'], ['nonterminal','pegsequencelist']]]]], ['s:trChoice']],
\ 'pegsequencelist' : ['sequence_list', [['nonterminal','pegsequenceconc'], ['zeroormoreconcat',['sequence_list',[['regexp','\s*,'], ['nonterminal','pegsequenceconc']]]]], ['s:trSequenceList']],
\ 'pegsequenceconc' : ['oneormorelist', ['nonterminal', 'pegprefix'], ['s:trSequenceConc']],
\ 'pegprefix' : ['sequence_list', [['optional',['choice',[['regexp','\s*&\s*'], ['regexp','\s*!\s*']]]], ['nonterminal','pegsuffix']], ['s:trPrefix']],
\ 'pegsuffix' : ['sequence_list', [['nonterminal','pegprimary'], ['optional',['choice',[['regexp','\s*?\s*'],['regexp','\s*\*\s*'],['regexp','\s*+\s*'],['regexp','\s*°\s*'],['regexp','\s*#\s*']]]]], ['s:trSuffix']],
\ 'pegprimary' : ['sequence_concatenated', [['choice',[['nonterminal','pegregexp'], ['nonterminal','pegliteral'], ['nonterminal', 'pegindentgreaterequal'], ['nonterminal', 'pegindentgreater'], ['sequence_concatenated', [['nonterminal','pegidentifier'], ['not', ['nonterminal','pegindentnt']], ['not', ['nonterminal','pegassignment']]], ['s:trNonterminal']], ['sequence_list',[['regexp','\s*(\s*'],['nonterminal','pegexpression'],['regexp','\s*)\s*']], ['s:take', '1']]]], ['zeroormorelist', ['nonterminal','pegtransform']] ]],
\ 'pegtransform' : ['sequence_list', [['regexp', '\.'], ['regexp', '[a-zA-Z0-9_:]\+'], ['regexp', '('], ['zeroormorelist', ['regexp', '\s*"\%(\\.\|[^"]\)*"\s*,\?\s*']], ['regexp', '\s*)']], ['s:trTransform']],
\ 'pegidentifier' : ['regexp', '\s*[a-zA-Z_][a-zA-Z0-9_]*\s*', ['s:strip']],
\ 'pegregexp' : ['regexp', '\s*/\%(\\.\|[^/]\)*/\s*', ['s:trRegexp']],
\ 'pegliteral' : ['regexp', '\s*"\%(\\.\|[^"]\)*"\s*', ['s:trLiteral']],
\ 'pegassignment' : ['regexp', '\s*='],
\ 'pegindentnt' : ['regexp', '\s*\^'],
\ 'pegindentgreaterequal' : ['regexp', '\s*>=', ['s:trIndentGE']],
\ 'pegindentgreater' : ['regexp', '\s*>', ['s:trIndentGT']],
\ 'pegcomment' : ['regexp', '\s*{[^}]*}\s*', ['s:skip']]
\ }









" ------------------------------------------------
" definition of fail objects

" this is what some parse_* functions return if they don't match
let g:fail = 'fail'

function! s:isfail(result)
	return type(a:result) == 1 && a:result == g:fail
endfunction



" ------------------------------------------------
" the various parse functions for every element of a PEG grammar

"Returns: the matched string or Fail
function! s:parse_regexp(thing)
	if s:debug | call s:print_state(a:thing, strpart(s:string, s:pos, 50)) | endif

	let npos = matchend(s:string, '\C^'.a:thing[1], s:pos)
	if npos == s:pos
		let result = ''
	elseif npos != -1
		let result = s:string[s:pos : npos-1]
		let s:pos = npos
	else
		let result = g:fail
	endif

	let outcome = s:apply_transformations(result, a:thing[2:])

	if s:debug | call s:print_result('regexp', outcome) | endif
	return outcome
endfunction

"Returns: the concatenated result (a list or a string) of whatever the subitems
"return or Fail (if one of them fails)
function! s:parse_sequence_concatenated(thing)
	if s:debug | call s:print_state(a:thing) | endif

	let old_pos = s:pos
	let result = []
	let res = ''
	for thing in a:thing[1]
		unlet res  "necessary, because the type of the parse result may change
		let res = s:parse_{thing[0]}(thing)
		if s:isfail(res)
			let s:pos = old_pos
			unlet result
			let result = g:fail
			break
		else
			call add(result, res)
		endif
	endfor
	if !s:isfail(result)
		if type(result[0]) == 3 " the results are lists (at least the first element)
			unlet! res
			let res = []
			for inner_list in result
				call extend(res, inner_list)
			endfor
			let result = res
		elseif type(result[0]) == 1 " the results are strings
			let res_string = join(result, '')
			unlet result
			let result = res_string
		else
			echom "Error: expected a list of lists or a list of strings"
			return 
		endif
	endif

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('sequence_concatenated', outcome) | endif
	return outcome
endfunction


"Returns: a list of whatever the subitems return or Fail (if one of them fails)
function! s:parse_sequence_list(thing)
	if s:debug | call s:print_state(a:thing) | endif

	let old_pos = s:pos
	let result = []
	let res = ''
	for thing in a:thing[1]
		unlet res  "necessary, because the type of the parse result may change
		let res = s:parse_{thing[0]}(thing)
		if s:isfail(res)
			let s:pos = old_pos
			unlet result
			let result = g:fail
			break
		else
			call add(result, res)
		endif
	endfor

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('sequence_list', outcome) | endif
	return outcome
endfunction


"Returns: whatever the element on the right side of the nonterminal returns
function! s:parse_nonterminal(thing)
	if s:debug | call s:print_state(a:thing) | endif

	let thing = s:grammar[a:thing[1]]
	let result = s:parse_{thing[0]}(thing)

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('nonterminal: '.string(a:thing[1]), outcome) | endif
	return outcome
endfunction


"like parse_nonterminal, but don't cache the output and push the current
"indentation on a stack when beginning the parsing and pop it when done
function! s:parse_nonterminal_indent(thing)
	if s:debug | call s:print_state(a:thing) | endif

	call add(s:indent_stack, strdisplaywidth(matchstr(s:string, '^\s*', s:pos), 0))
	if g:peggi_debug >= 1 | call s:print_indentation_stack() | endif

	let thing = s:grammar[a:thing[1]]
	let result = s:parse_{thing[0]}(thing)

	let outcome = s:apply_transformations(result, a:thing[2:])

	call remove(s:indent_stack, -1)
	if g:peggi_debug >= 1 | call s:print_indentation_stack() | endif

	if s:debug | call s:print_result('indent_nonterminal: '.string(a:thing[1]), outcome) | endif
	return outcome
endfunction


"Returns: whatever the first matching subelement returns, or Fail if all items fail
function! s:parse_choice(thing)
	if s:debug | call s:print_state(a:thing) | endif

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

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('choice', outcome) | endif
	return outcome
endfunction


"Returns: whatever the subelement returns, or '' if it fails
function! s:parse_optional(thing)
	if s:debug | call s:print_state(a:thing) | endif

	let old_pos = s:pos
	let result = s:parse_{a:thing[1][0]}(a:thing[1])
	if s:isfail(result)
		let s:pos = old_pos
		let result = ''
	endif

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('optional', outcome) | endif
	return outcome
endfunction


"Returns: the (possibliy empty) concatenated results (a list or string) of
"whatever the subitem returns, as long as it matches
function! s:parse_zeroormoreconcat(thing)
	if s:debug | call s:print_state(a:thing) | endif

	let result = []
	while 1
		unlet! res "necessary, because the type of the parse result may change
		let res = s:parse_{a:thing[1][0]}(a:thing[1])
		if s:isfail(res)
			break
		else
			call add(result, res)
		endif
	endwhile

	if !empty(result)
		if type(result[0]) == 3 " the results are lists (at least the first element)
			unlet! res
			let res = []
			for inner_list in result
				call extend(res, inner_list)
			endfor
			let result = res
		elseif type(result[0]) == 1 " the results are strings
			let res_string = join(result, '')
			unlet result
			let result = res_string
		else
			echom "Error: expected a list of lists or a list of strings"
			return 
		endif
	else
		unlet result
		let result = ''
	endif
		

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('zeroormoreconcat', outcome) | endif
	return outcome
endfunction


"Returns: a (possibliy empty) list of whatever the subitem returns, as long as it matches
function! s:parse_zeroormorelist(thing)
	if s:debug | call s:print_state(a:thing) | endif

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

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('zeroormorelist', outcome) | endif
	return outcome
endfunction


"Returns: the concatenated results (a list or string) of whatever the subitem
"returns, as long as it matches or Fail if it doesn't match
function! s:parse_oneormoreconcat(thing)
	if s:debug | call s:print_state(a:thing) | endif

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
		if type(first) == 3 " the results are lists (at least the first element)
			for inner_list in rest
				call extend(first, inner_list)
			endfor
			let result = first
		elseif type(first) == 1 " the results are strings
			let result = first . join(rest, '')
		else
			echom "Error: expected a list of lists or a list of strings"
			return 
		endif
	endif

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('oneormoreconcat', outcome) | endif
	return outcome
endfunction


"Returns: a list of whatever the subitem returns, as long as it matches, or Fail if it doesn't match
function! s:parse_oneormorelist(thing)
	if s:debug | call s:print_state(a:thing) | endif

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
		let result = [first] + rest
	endif

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('oneormorelist', outcome) | endif
	return outcome
endfunction


"Returns: '' if the given item matches, Fail otherwise
"does not consume any chars of the parsed string
function! s:parse_and(thing)
	if s:debug | call s:print_state(a:thing) | endif

	let old_pos = s:pos
	let res = s:parse_{a:thing[1][0]}(a:thing[1])
	let s:pos = old_pos
	if s:isfail(res)
		let result = g:fail
	else
		let result = ''
	endif

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('and', outcome) | endif
	return outcome
endfunction


"Returns: '' if the given item matches not, Fail otherwise
"does not consume any chars of the parsed string
function! s:parse_not(thing)
	if s:debug | call s:print_state(a:thing) | endif

	let old_pos = s:pos
	let res = s:parse_{a:thing[1][0]}(a:thing[1])
	let s:pos = old_pos
	if s:isfail(res)
		let result = ''
	else
		let result = g:fail
	endif

	let outcome = s:apply_transformations(result, a:thing[2:])
	if s:debug | call s:print_result('not', outcome) | endif
	return outcome
endfunction





function! s:apply_transformations(result, transformations)
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
endfunction

function! peggi#peggi#abort()
	throw "peggi_abort"
endfunction

function! peggi#peggi#parse_begin(grammar, string, start)
	unlet! s:grammar

	if has_key(s:grammar_cache, a:grammar)
		let users_grammar = s:grammar_cache[a:grammar]
	else
		let s:debug = 0
		let s:pos = 0
		let s:grammar = s:peggi_grammar
		let s:string = a:grammar
		try
			let users_grammar = s:parse_nonterminal(['nonterminal', 'peggrammar'])
		catch /peggi_abort/
		endtry
		if (type(users_grammar) == type(g:fail) && users_grammar == g:fail) || strlen(s:string) > s:pos
			echom "Error: your grammar is malformed"
			return
		endif
		if s:inline_nonterminals == 1 || (s:inline_nonterminals == 2 && (!exists('g:peggi_debug') || g:peggi_debug == 0))
			let users_grammar = s:inline_nts(users_grammar, a:start)
		endif
		let s:grammar_cache[a:grammar] = users_grammar
	endif

	if exists('g:peggi_debug') && g:peggi_debug >= 1
		let s:debug = 1
		"XXX hack
		let vimwiki_list = b:vimwiki_list
		tabnew
		let b:vimwiki_list = vimwiki_list
		set nowrap
	endif
	if exists('g:peggi_debug') && g:peggi_debug >= 2
		call peggi#pprint#pprint(users_grammar)
	endif
	"return

	let s:pos = 0
	let s:grammar = users_grammar
	let s:string = a:string

	return s:parse_nonterminal(['nonterminal', a:start])
endfunction

function! peggi#peggi#parse(grammar, string, start)
	let result = peggi#peggi#parse_begin(a:grammar, a:string, a:start)
	if strlen(s:string) > s:pos
		return g:fail
	else
		return result
	endif
endfunction

function! peggi#peggi#parse_file(grammar, file, start)
	return peggi#peggi#parse(a:grammar, join(readfile(a:file), "\r")."\r", a:start)
endfunction

function! peggi#peggi#parse_file_begin(grammar, file, start)
	return peggi#peggi#parse_begin(a:grammar, join(readfile(a:file), "\r")."\r", a:start)
endfunction

