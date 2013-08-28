
so peggi.vim

fu! g:addhtmlstuff(content)
	return '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">\n<html>\n <head>\n <link rel="Stylesheet" type="text/css" href="style.css">\n <title>Testwiki</title>\n <meta http-equiv="Content-Type" content="text/html; charset=utf-8">\n </head>\n <body>\n' . a:content . '\n</body>\n </html>'
endf

fu! g:header(string)
	return '<h1>'.a:string.'</h1>'
endf

fu! g:breakorspace(string)
	return '<br />'
endf



unlet! s:grammar
let s:grammar = '
			\file = ((emptyline | header | hline | paragraph)*).g:addhtmlstuff()
			\emptyline = /\s*\n/.skip()
			\header = /\s*\(=\{1,6}\)[^=].\{-}[^=]\1\s*\n/.g:header()
			\hline = /-----*\n/.replace("<hr/>")
			\paragraph = (ordinarytextline+).tag("p")
			\ordinarytextline = !emptyline !header !hline /[^\n]*[^\s\n][^\n]*/ /\n/.g:breakorspace()
			\'

let g:peggi_debug = 0
"call writefile(split(g:parse_file(s:grammar, 'in.wiki', 'file'), '\\n'), 'out.html')

for wikifile in split(globpath('vwtest', '*.wiki'), '\n')
	call writefile(split(g:parse_file(s:grammar, wikifile, 'file'), '\\n'), 'vwtest/'.fnamemodify(wikifile, ':t:r').'.html')
endfor
