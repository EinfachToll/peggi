set maxfuncdepth=1000000

fu! g:addhtmlstuff(content)
	return '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">\n<html>\n <head>\n <link rel="Stylesheet" type="text/css" href="'.s:css_file.'">\n <title>'.s:filename_without_ext.'</title>\n <meta http-equiv="Content-Type" content="text/html; charset=utf-8">\n </head>\n <body>\n' . a:content . '\n</body>\n</html>'
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
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxWikiLink . '\)\(.*\)')
	if !empty(list)
		let url = matchstr(list[2], g:vimwiki_rxWikiLinkMatchUrl)
		let descr = matchstr(list[2], g:vimwiki_rxWikiLinkMatchDescr)
		let descr = (substitute(descr,'^\s*\(.*\)\s*$','\1','') != '' ? descr : url)
		let [idx, scheme, path, subdir, lnk, ext, url] = vimwiki#base#resolve_scheme(url, 1)
		let link = vimwiki#html#linkify_link(url, descr)

		return g:process_line(list[1]) . link . g:process_wikiincl(list[3])
	else
		return a:string
	endif
endf

fu! g:process_wikiincl(string)
	return a:string
endf



unlet! s:grammar
let s:grammar = '
			\ file = ((emptyline | header | hline | paragraph.tag("p"))*).g:addhtmlstuff()
			\ emptyline = /\s*\r/.skip()
			\ header = /\s*\(=\{1,6}\)[^=].\{-}[^=]\1\s*\r/.g:header()
			\ hline = /-----*\r/.replace("<hr/>")
			\ paragraph = (table | list | preformatted_text | ordinarytextline)+
			\ ordinarytextline = !emptyline !header !hline &> text
			\ text = /[^\r]*/.g:process_line() /\r/.g:breakorspace()
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
			\ list_item_content = text (&> paragraph)? (emptyline paragraph.tag("p"))*
			\ 
			\ preformatted_text = &> "{{{".skip() /[^\r]*/.g:startpre() /\r/.skip() /\_.\{-}\r\s*}}}\s*\r/.g:endpre()
			\'


let g:peggi_debug = 2 "XXX currently, this is reset to 0 when VimwikiAll2HTML is called

fu! g:vw2html(force, syntax, ext, output_dir, input_file, css_file, tmpl_path, tmpl_default, tmpl_ext, root_path)
	let s:filename_without_ext = fnamemodify(a:input_file, ':t:r')
	let s:css_file = a:css_file
	let output_path = a:output_dir . '/' . s:filename_without_ext .'.html'
	call writefile(split(g:parse_file(s:grammar, a:input_file, 'file'), '\\n'), output_path)
endf



