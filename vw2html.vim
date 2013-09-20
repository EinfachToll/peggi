set maxfuncdepth=1000000

so peggi.vim

fu! g:addhtmlstuff(content)
	return '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">\n<html>\n <head>\n <link rel="Stylesheet" type="text/css" href="style.css">\n <title>Testwiki</title>\n <meta http-equiv="Content-Type" content="text/html; charset=utf-8">\n </head>\n <body>\n' . a:content . '\n</body>\n</html>'
endf

fu! g:header(string)
	let res = matchlist(a:string, '\s*\(=\{1,6}\)\([^=].\{-}[^=]\)\1\s*\r')
	let level = strlen(res[1])
	return '<h'.level.'>'.res[2].'</h'.level.'>'
endf

fu! g:breakorspace(string)
	return '<br />'
endf


function! g:checkbox(bulletandcb)
	let [bullet, cb] = a:bulletandcb
	if cb != ''
		let idx = index([' ', '.', 'o', 'O', 'X'], cb)
		let cb = ' class="done'.idx.'"'
	endif
	let type = ''
	if bullet =~ '\d\+'
		let type = '1'
	elseif bullet =~# '[ivxlcdm]\+)'
		let type = 'i'
	elseif bullet =~# '[IVXLCDM]\+)'
		let type = 'I'
	elseif bullet =~# '\u'
		let type = 'A'
	elseif bullet =~# '\l'
		let type = 'a'
	endif
	if type != ''
		let type = ' type="'.type.'"'
	endif
	return '<li' . type . cb . '>'
endfunction

fu! g:startpre(class)
	if a:class !~ '^\s*$'
		return '<pre ' . a:class . '>'
	else
		return '<pre>'
	endif
endf

fu! g:endpre(string)
	let str = substitute(a:string, '\r\s*}}}\s*\r$', '', '')
	return str . '</pre>'
endf

fu! g:process_line(string)
	if a:string =~ g:vimwiki_rxWikiLink
	endif
endf



unlet! s:grammar
let s:grammar = '
			\ file = ((emptyline | header | hline | paragraph.tag("p"))*).g:addhtmlstuff()
			\ emptyline = /\s*\r/.skip()
			\ header = /\s*\(=\{1,6}\)[^=].\{-}[^=]\1\s*\r/.g:header()
			\ hline = /-----*\r/.replace("<hr/>")
			\ paragraph = (table | list | preformatted_text | ordinarytextline)+
			\ ordinarytextline = !emptyline !header !hline &> text
			\ text = /[^\r]*/ /\r/.g:breakorspace()
			\ 
			\ table = &> &bar (table_header? table_block).tag("table")
			\ table_header = table_header_line.tag("tr")  (/\r/ table_div /\r/).skip()
			\ table_block = table_line (/\r/.skip() table_line)*
			\ table_div = /|[-|]\+|/
			\ table_header_line = bar (header_cell bar)+
			\ table_line = (bar (body_cell bar)+).tag("tr")
			\ body_cell = /[^\r|]\+/.strip().tag("td")
			\ header_cell = /[^\r|]\+/.strip().tag("th")
			\ bar = /|/.skip()
			\ 
			\ list = blist | nlist
			\ blist = &listbullet ((&> blist_item)+).tag("ul")
			\ nlist = &listnumber ((&> nlist_item)+).tag("ol")
			\ blist_item^ = (listbullet checkbox?).split().g:checkbox() list_item_content
			\ nlist_item^ = (listnumber checkbox?).split().g:checkbox() list_item_content
			\ listbullet = /\s*[-*#•]\s\+/
			\ listnumber = /\s*\(\d\+\.\|\d\+)\|[ivxlcdm]\+)\|[IVXLCDM]\+)\|\l\{1,2})\|\u\{1,2})\)\s\+/
			\ checkbox = "[".skip() /[ .oOX]/ /\]\s\+/.skip()
			\ list_item_content = text paragraph? (emptyline paragraph.tag("p"))*
			\ 
			\ preformatted_text = &> "{{{".skip() /[^\r]*/.g:startpre() /\r/.skip() /\_.\{-}\r\s*}}}\s*\r/.g:endpre()
			\'

if 1
	let g:peggi_debug = 0
	for wikifile in split(globpath('vwtest/', '*.wiki'), '\n')
		call writefile(split(g:parse_file(s:grammar, wikifile, 'file'), '\\n'), 'vwtest/'.fnamemodify(wikifile, ':t:r').'.html')
	endfor
else
	let g:peggi_debug = 2
	call writefile(split(g:parse_file(s:grammar, 'in.wiki', 'file'), '\\n'), 'out.html')
endif



