so peggi.vim


" ------------------------------------------------
"  an Example: parse a table and transform it to HTML


"the Syntax for a grammar for now:
"the rules are nested lists of the form ['type of the PEG element', subelement, transformation function]
"let bar = ['regexp', '[|│]', [g:Remove]]
"let cell = ['regexp', '[a-zA-Z0-9 ]\+', [g:Strip]]
"let table_line = ['sequence', [ ['nonterminal', 'bar'], ['oneormore', ['sequence', [['nonterminal', 'cell', [g:Tag,'td']], ['nonterminal', 'bar']], [g:Concat] ], [g:Concat]]], [g:Concat]]
"let table_header_line = ['sequence', [ ['nonterminal', 'bar'], ['oneormore', ['sequence', [['nonterminal', 'cell', [g:Tag,'th']], ['nonterminal', 'bar']], [g:Concat]], [g:Concat]]], [g:Concat]]
"let table_div = ['regexp', '|[-|]\+|']
"let table_header = ['sequence', [ ['nonterminal', 'table_header_line', [g:Tag,'tr']], ['sequence', [ ['regexp','\n'] , ['nonterminal','table_div'] , ['regexp','\n'] ], [g:Remove]] ], [g:Concat]]
"let table_block = ['sequence', [ ['nonterminal','table_line', [g:Tag,'tr']], ['zeroormore', ['sequence',[['regexp','\n', [g:Remove]],['nonterminal','table_line', [g:Tag,'tr']]], [g:Concat]], [g:Concat]] ], [g:Concat]]
"let table = ['sequence', [['optional',['nonterminal','table_header']], ['nonterminal','table_block'] , ['regexp','$']] , [g:Concat], [g:Tag,'table']]


"the Syntax for a grammar in a nicer syntax

let s:grammar = {
			\ 'bar' : '/[|│]/.skip()',
			\ 'header_cell' : '/[a-zA-Z0-9 ]\+/.strip().tag("th")',
			\ 'body_cell' : '/[a-zA-Z0-9 ]\+/.strip().tag("td")',
			\ 'table_line' : '(bar (body_cell bar)+).tag("tr")',
			\ 'table_header_line' : 'bar (header_cell bar)+',
			\ 'table_div' : '/|[-|]\+|/',
			\ 'table_header' : 'table_header_line.tag("tr")  (/\n/ table_div /\n/).remove()',
			\ 'table_block' : 'table_line (/\n/.skip() table_line)+',
			\ 'table' : '(table_header? table_block /$/).tag("table")',
			\ }


"the string to be parsed:
let s:string = "|hm|\n|--|\n| blabla | soso | lala │ naja |\n|b|d|"
"let s:string = '|hm|'

"start parsing:
echom ">>> ".string(g:parse(s:grammar, s:string, 'table'))

