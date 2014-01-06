"  pretty print function for arbitrary types

function! peggi#pprint#pprint(thing)
	call s:format(a:thing, 0)
endfunction

fu! s:printline(string, indent)
	let string = repeat(' ', a:indent) . a:string
	call append(line('$'), string)
endfu

fu! s:format(thing, indent)
	if type(a:thing) == type({})
		call s:printline('{', a:indent)
		for key in keys(a:thing)
			call s:printline(key.':', a:indent+2)
			call s:format(a:thing[key], a:indent+4)
		endfor
		call s:printline('}', a:indent)
	elseif type(a:thing) == type([])
		call s:printline('[', a:indent)
		for item in a:thing
			call s:format(item, a:indent+4)
			unlet item
		endfor
		call s:printline(']', a:indent)
	else
		call s:printline(a:thing, a:indent)
	endif
endf
