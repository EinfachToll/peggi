set maxfuncdepth=1000000

fu! g:addhtmlstuff(content)
	return '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">\n<html>\n <head>\n <link rel="Stylesheet" type="text/css" href="'.s:css_file.'">\n <title>'.s:filename_without_ext.'</title>\n <meta http-equiv="Content-Type" content="text/html; charset=utf-8">\n </head>\n <body>\n' . a:content . '\n</body>\n</html>'
endf

fu! g:header(string)
	let res = matchlist(a:string, '\s*\(=\{1,6}\)\([^=].\{-}[^=]\)\1\s*\r')
	let level = strlen(res[1])
	let center = a:string =~ '^\s' ? ' class="justcenter"' : ''
	return '<h'.level.center.'>'.res[2].'</h'.level.'>'
endf

fu! g:breakorspace(string)
	return '<br />'
endf


function! g:checkbox(bulletandcb, type)
	let [bullet, cb] = a:bulletandcb
	if cb != ''
		let idx = index([' ', '.', 'o', 'O', 'X'], cb)
		let cb = ' class="done'.idx.'"'
	endif
	let typeattr = ''
	if a:type != '-'
		let typeattr = ' type="'.a:type.'"'
	endif
	return '<li' . typeattr . cb . '>'
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

fu! g:startmathblock(environment)
	if a:environment =~ '^\s*%.*%\s*$'
		"the current environment is saved in a variable for the close function
		"this is safe, because mathblocks can't be nested
		let s:cur_env = substitute(a:environment, '^\s*%\s*\(.*\)%$', '\1', '')
		return '\begin{' . s:cur_env . '}'
	else
		let s:cur_env = ''
		return '\['
	endif
endf

fu! g:endmathblock(string)
	let str = substitute(a:string, '\r\s*}}$\s*\r$', '', '')
	if s:cur_env != ''
		return str . '\end{' . s:cur_env . '}'
	else
		return str . '\]'
	endif
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
		return g:process_wikiincl(a:string)
	endif
endf

fu! g:process_wikiincl(string)
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxWikiIncl . '\)\(.*\)')
	if !empty(list)
		let str = list[2]
		" custom transclusions
		let line = VimwikiWikiIncludeHandler(str)
		" otherwise, assume image transclusion
		if line == ''
		  let url_0 = matchstr(str, g:vimwiki_rxWikiInclMatchUrl)
		  let descr = matchstr(str, vimwiki#html#incl_match_arg(1))
		  let verbatim_str = matchstr(str, vimwiki#html#incl_match_arg(2))
		  " resolve url
		  let [idx, scheme, path, subdir, lnk, ext, url] = 
				\ vimwiki#base#resolve_scheme(url_0, 1)

		  " Issue 343: Image transclusions: schemeless links have .html appended.
		  " If link is schemeless pass it as it is
		  if scheme == ''
			let url = lnk
		  endif

		  let url = escape(url, '#')
		  let line = vimwiki#html#linkify_image(url, descr, verbatim_str)
		endif
		return g:process_wikiincl(list[1]) . line . g:process_weblink(list[3])
	else
		return g:process_weblink(a:string)
	endif
endf

fu! g:process_weblink(string)
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxWeblink . '\)\(.*\)')
	if !empty(list)
		let str = list[2]
		let url = matchstr(str, g:vimwiki_rxWeblinkMatchUrl)
		let descr = matchstr(str, g:vimwiki_rxWeblinkMatchDescr)
		let line = vimwiki#html#linkify_link(url, descr)
		return g:process_weblink(list[1]) . line . g:process_code(list[3])
	else
		return g:process_code(a:string)
	endif
endf

function! s:mid(value, cnt) "{{{
  return strpart(a:value, a:cnt, len(a:value) - 2 * a:cnt)
endfunction "}}}

function! s:safe_html_tags(line) "{{{
  let line = substitute(a:line,'<','\&lt;', 'g')
  let line = substitute(line,'>','\&gt;', 'g')
  return line
endfunction "}}}

fu! g:process_code(string)
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxCode . '\)\(.*\)')
	if !empty(list)
		let str = '<code>'.s:safe_html_tags(s:mid(list[2], 1)).'</code>'
		return g:process_code(list[1]) . str . g:process_eqin(list[3])
	else
		return g:process_eqin(a:string)
	endif
endf

fu! g:process_eqin(string)
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxEqIn . '\)\(.*\)')
	if !empty(list)
		" mathJAX wants \( \) for inline maths
		let str = '\('.s:mid(list[2], 1).'\)'
		return g:process_eqin(list[1]) . str . g:process_italic(list[3])
	else
		return g:process_italic(a:string)
	endif
endf

fu! g:process_italic(string)
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxItalic . '\)\(.*\)')
	if !empty(list)
		let str = '<em>'.s:mid(list[2], 1).'</em>'
		return g:process_italic(list[1]) . str . g:process_bold(list[3])
	else
		return g:process_bold(a:string)
	endif
endf

fu! g:process_bold(string)
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxBold . '\)\(.*\)')
	if !empty(list)
		let str = '<strong>'.s:mid(list[2], 1).'</strong>'
		return g:process_bold(list[1]) . str . g:process_todo(list[3])
	else
		return g:process_todo(a:string)
	endif
endf

fu! g:process_todo(string)
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxTodo . '\)\(.*\)')
	if !empty(list)
		let str = '<span class="todo">'.list[2].'</span>'
		return g:process_todo(list[1]) . str . g:process_deltext(list[3])
	else
		return g:process_deltext(a:string)
	endif
endf

fu! g:process_deltext(string)
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxDelText . '\)\(.*\)')
	if !empty(list)
		let str = '<del>'.s:mid(list[2], 2).'</del>'
		return g:process_deltext(list[1]) . str . g:process_super(list[3])
	else
		return g:process_super(a:string)
	endif
endf

fu! g:process_super(string)
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxSuperScript . '\)\(.*\)')
	if !empty(list)
		let str = '<sup><small>'.s:mid(list[2], 1).'</small></sup>'
		return g:process_super(list[1]) . str . g:process_sub(list[3])
	else
		return g:process_sub(a:string)
	endif
endf

fu! g:process_sub(string)
	let list = matchlist(a:string, '\(.*\)\(' . g:vimwiki_rxSubScript . '\)\(.*\)')
	if !empty(list)
		let str = '<sub><small>'.s:mid(list[2], 2).'</small></sub>'
		return g:process_sub(list[1]) . str . list[3]
	else
		return a:string
	endif
endf

unlet! s:grammar
let s:grammar = '
			\ file = ((emptyline | header | hline | paragraph.tag("p"))*).g:addhtmlstuff()
			\ emptyline = /\s*\r/.skip()
			\ header = /\s*\(=\{1,6}\)[^=][^\r]\{-}[^=]\1\s*\r/.g:header()
			\ hline = /-----*\r/.replace("<hr/>")
			\ paragraph = (table | list | preformatted_text | math_block | deflist | ordinarytextline)+
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
			\ list = &liststart (blist | rlist | Rlist | alist | Alist | nlist)
			\ blist = &bullet ((&> blist_item)+).tag("ul")
			\ rlist = &rstartnumber ((&> rlist_item)+).tag("ol")
			\ Rlist = &Rstartnumber ((&> Rlist_item)+).tag("ol")
			\ alist = &alphanumber ((&> alist_item)+).tag("ol")
			\ Alist = &Alphanumber ((&> Alist_item)+).tag("ol")
			\ nlist = &number ((&> nlist_item)+).tag("ol")
			\ blist_item^ = (bullet checkbox?).split().g:checkbox("-") list_item_content
			\ rlist_item^ = (rnumber checkbox?).split().g:checkbox("i") list_item_content
			\ Rlist_item^ = (Rnumber checkbox?).split().g:checkbox("I") list_item_content
			\ alist_item^ = (alphanumber checkbox?).split().g:checkbox("a") list_item_content
			\ Alist_item^ = (Alphanumber checkbox?).split().g:checkbox("A") list_item_content
			\ nlist_item^ = (number checkbox?).split().g:checkbox("1") list_item_content
			\ bullet = /\s*[-*#•]\s\+/
			\ rstartnumber = /\s*i\{1,3})\s\+/
			\ Rstartnumber = /\s*I\{1,3})\s\+/
			\ rnumber = /\s*[ivxlcdm]\+)\s\+/
			\ Rnumber = /\s*[IVXLCDM]\+)\s\+/
			\ alphanumber = /\s*\l\{1,2})\s\+/
			\ Alphanumber = /\s*\u\{1,2})\s\+/
			\ number = /\s*\d\+[.)]\s\+/
			\ liststart = /\s*\([-*#•]\|\d\+\.\|\d\+)\|[ivxlcdm]\+)\|[IVXLCDM]\+)\|\l\{1,2})\|\u\{1,2})\)\s\+/
			\ checkbox = "[".skip() /[ .oOX]/ /\]\s\+/.skip()
			\ list_item_content = text (&> paragraph)? (emptyline paragraph.tag("p"))*
			\ 
			\ preformatted_text = &> "{{{".skip() /[^\r]*/.g:startpre() /\r/.skip() /\_.\{-}\r\s*}}}\s*\r/.g:endpre()
			\ math_block = &> "{{$".skip() /[^\r]*/.g:startmathblock() /\r/.skip() /\_.\{-}\r\s*}}\$\s*\r/.g:endmathblock()
			\ 
			\ deflist = (&> deflist_item+).tag("dl")
			\ deflist_item^ = term (/\s\+/ short_definition)? /\r/.skip() (&>= long_definition)*
			\ term = /[^\r:]*[[:alnum:]][^\r:]*/.tag("dt") "::".skip()
			\ short_definition = /[^\r]\+/.tag("dd")
			\ long_definition^ = /::\s\+/.skip() list_item_content.tag("dd")
			\
			\'


let g:peggi_debug = 2 "XXX currently, this is reset to 0 when VimwikiAll2HTML is called

fu! g:vw2html(force, syntax, ext, output_dir, input_file, css_file, tmpl_path, tmpl_default, tmpl_ext, root_path)
	let s:filename_without_ext = fnamemodify(a:input_file, ':t:r')
	let s:css_file = a:css_file
	let output_path = a:output_dir . '/' . s:filename_without_ext .'.html'
	call writefile(split(g:parse_file(s:grammar, a:input_file, 'file'), '\\n'), output_path)
endf



