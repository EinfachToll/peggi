set maxfuncdepth=1000000

so peggi.vim

fu! g:addhtmlstuff(content)
	return '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">\n<html>\n <head>\n <link rel="Stylesheet" type="text/css" href="style.css">\n <title>Testwiki</title>\n <meta http-equiv="Content-Type" content="text/html; charset=utf-8">\n </head>\n <body>\n' . a:content . '\n</body>\n </html>'
endf

fu! g:header(string)
	let res = matchlist(a:string, '\s*\(=\{1,6}\)\([^=].\{-}[^=]\)\1\s*\n')
	let level = strlen(res[1])
	return '<h'.level.'>'.res[2].'</h'.level.'>'
endf

fu! g:breakorspace(string)
	return '<br />'
endf


let g:peggi_additional_state = [-1]
fu! g:Pushindent(element)
	call add(g:peggi_additional_state, strdisplaywidth(a:element, 0)-2)
	"echom "--------" . string(g:peggi_additional_state)
	return a:element
endf

fu! g:Popindent(ele)
	call remove(g:peggi_additional_state, -1)
	"echom "--------" . string(g:peggi_additional_state)
	return a:ele
endf

fu! g:leqlastindent(spaces)
	"echom "--------" . string(g:peggi_additional_state)
	return strdisplaywidth(a:spaces, 0) <= g:peggi_additional_state[-1] ? '' : g:fail
endf

fu! g:gtsndlastindent(spaces)
	"echom "--------" . string(g:peggi_additional_state)
	return strdisplaywidth(a:spaces, 0) > g:peggi_additional_state[-2] ? '' : g:fail
endf

fu! g:gtlastindent(spaces)
	"echom "--------" . string(g:peggi_additional_state)
	return strdisplaywidth(a:spaces, 0) > g:peggi_additional_state[-1] ? '' : g:fail
endf


unlet! s:grammar
let s:grammar = '
			\file = ((emptyline | header | hline | paragraph)*).g:addhtmlstuff()
			\emptyline = /\s*\n/.skip()
			\header = /\s*\(=\{1,6}\)[^=].\{-}[^=]\1\s*\n/.g:header()
			\hline = /-----*\n/.replace("<hr/>")
			\paragraph = ((table | list | ordinarytextline)+).tag("p")
			\ordinarytextline = !emptyline !header !hline /[^\n]*/ /\n/.g:breakorspace()
			\
			\table = &/|/ (table_header? table_block).tag("table")
			\table_header = table_header_line.tag("tr")  (/\n/ table_div /\n/).skip()
			\table_block = table_line (/\n/.skip() table_line)*
			\table_div = /|[-|]\+|/
			\table_header_line = bar (header_cell bar)+
			\table_line = (bar (body_cell bar)+).tag("tr")
			\body_cell = /[^\n|]\+/.strip().tag("td")
			\header_cell = /[^\n|]\+/.strip().tag("th")
			\bar = /|/.skip()
			\
			\list = blist | nlist 
			\blist = &listbullet (blist_item+).tag("ul")
			\nlist = &listnumber (nlist_item+).tag("ol")
			\blist_item = (&(listbullet.g:Pushindent()) &(g:leqlastindent(/\s*/)) &(g:gtsndlastindent(/\s*/)) /\s*/.skip() listbullet.replace("<li>") text ( &(g:gtlastindent(/\s*/)) (list | /\s\+/ text) )*).g:Popindent()
			\nlist_item = (&(listnumber.g:Pushindent()) &(g:leqlastindent(/\s*/)) &(g:gtsndlastindent(/\s*/)) /\s*/.skip() listnumber.replace("<li>") text ( &(g:gtlastindent(/\s*/)) (list | /\s\+/ text) )*).g:Popindent()
			\text = /[^\n]\+/ /\n/.skip()
			\listbullet = /\s*[-*#•]\s\+/
			\listnumber = /\s*\(\d\+\.\|\d\+)\|[ivxlcdm]\+)\|[IVXLCDM]\+)\|\l\{1,2})\|\u\{1,2})\)\s\+/
			\'

let g:peggi_debug = 0

call writefile(split(g:parse_file(s:grammar, 'in.wiki', 'file'), '\\n'), 'out.html')
for wikifile in split(globpath('vwtest', '*.wiki'), '\n')
	call writefile(split(g:parse_file(s:grammar, wikifile, 'file'), '\\n'), 'vwtest/'.fnamemodify(wikifile, ':t:r').'.html')
endfor
