
so peggi.vim
set maxfuncdepth=10000

let s:stack = [-1]

fu! g:Pushindent(element)
	call add(s:stack, strdisplaywidth(a:element, 0)-2)
	"echom "--------" . string(s:stack)
	return a:element
endf

fu! g:Popindent(ele)
	call remove(s:stack, -1)
	"echom "--------" . string(s:stack)
	return a:ele
endf

fu! g:leqlastindent(spaces)
	"echom "--------" . string(s:stack)
	return strdisplaywidth(a:spaces, 0) <= s:stack[-1] ? '' : g:fail
endf

fu! g:gtsndlastindent(spaces)
	"echom "--------" . string(s:stack)
	return strdisplaywidth(a:spaces, 0) > s:stack[-2] ? '' : g:fail
endf

fu! g:gtlastindent(spaces)
	"echom "--------" . string(s:stack)
	return strdisplaywidth(a:spaces, 0) > s:stack[-1] ? '' : g:fail
endf


fu! g:clear(ele)
	call remove(s:stack, 0, len(s:stack)-1)
	return a:ele
endf

let s:grammar='
			\text = /[a-zA-Z0-9 ]\+/ /\n/.skip()
			\list_item = (&((/\s*- /).g:Pushindent()) &(g:leqlastindent(/\s*/)) &(g:gtsndlastindent(/\s*/)) /\s*/.skip() "- ".replace("<li>") text ( &(g:gtlastindent(/\s*/)) (/\s\+/ text | list) )*).g:Popindent()
			\list = (list_item+).tag("ul")
			\'

let s:string="- this is\n  a long list item\n  - subitem 1\n - misindented subitem 2\n - misindented subitem 3\n  - subsubitem\n- item 2\n"
echom ">>> ".string(g:parse(s:grammar, s:string, 'list'))
