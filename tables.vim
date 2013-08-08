
" ------------------------------------------------
"  an Example: parse a table and transform it to HTML

so peggi.vim

let s:grammar = {
			\ 'bar' : '/[|│]/.skip()',
			\ 'header_cell' : '/[a-zA-Z0-9 ]\+/.strip().tag("th")',
			\ 'body_cell' : '/[a-zA-Z0-9 ]\+/.strip().tag("td")',
			\ 'table_line' : '(bar (body_cell bar)+).tag("tr")',
			\ 'table_header_line' : 'bar (header_cell bar)+',
			\ 'table_div' : '/|[-|]\+|/',
			\ 'table_header' : 'table_header_line.tag("tr")  (/\n/ table_div /\n/).skip()',
			\ 'table_block' : 'table_line (/\n/.skip() table_line)+',
			\ 'table' : '(table_header? table_block /$/).tag("table")',
			\ }


"the string to be parsed:
let s:string = "|hm|\n|--|\n| blabla | soso | lala │ naja |\n|b|d|"
"let s:string = '|hm|'

"start parsing:
echom ">>> ".string(g:parse(s:grammar, s:string, 'table'))

