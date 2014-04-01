Peggi is a parsing framework. On it's own, it's of not much use, but it can serve you
when you write a Vim script that has to struggle with data too complicated to parse
with regular expressions alone. 

# Installation

Use one of the many plugin managers for Vim, or install it manually by putting the
folder `peggi/` into any `autoload/` directory in your runtimepath.


# Basic Usage

1. In your Vim script, first specify the formal grammar of your data as Parsing
   Expression Grammar (PEG)
2. Then start Peggi: `let result = peggi#peggi#parse(grammar, data, start-nonterminal)`

See the section “Grammar” for how a grammar should look like exactly. See the other
sections for how to use Peggi.

As an example, let's look at a script that uses Peggi for processing arithmetic
expressions:
```viml
let s:grammar = '
            \ Expression = ( Term , /\s*[+-]/.strip() , Expression ).g:compute()  |  Term
            \ Term = ( Factor , /\s*[*\/]/.strip() , Term ).g:compute()  |  Factor
            \ Factor = ( /\s*(/ , Expression , /\s*)/ ).take("1")  |  /\s*[-0-9.]\+/.str2float()
            \ '

function! g:compute(list)
    if a:list[1] == '*'
        return a:list[0] * a:list[2]
    elseif a:list[1] == '/'
        return a:list[0] / a:list[2]
    elseif a:list[1] == '+'
        return a:list[0] + a:list[2]
    elseif a:list[1] == '-'
        return a:list[0] - a:list[2]
    endif
endfunction

let s:example = '-10 * (2* 2)/(0.6 +2)'

echo peggi#peggi#parse(s:grammar, s:example, 'Expression')
```

Some other parsing frameworks return its result as some kind of abstract syntax tree
(AST) which the user can process easily. In Vimscript however, it's not really fun to
make complicated data structures, so in Peggi, the processing of the result happens
while parsing. To this end, you can specify transformation functions in the grammar
which process the currently parsed text elements. These transformation functions can,
in principle, take and return arbitrary types (strings, numbers, lists, dictionaries,
…). So you have to take care yourself that the types match.

Regarding the given example, what exactly happens when Peggi attempts to match a Factor
to a part of a string? First, it tries to match the regular expression `\s*(`, which
means arbitrary many whitespaces followed by a parenthesis. If that succeeds, it
matches an Expression (which I skip in this explanation to avoid recursion). If this
also succeeds, more whitespaces and a closing parenthesis is matched. These three
items, opening parenthesis, result of the Expression matching, and closing parenthesis
are put into a list (because of the two `,`) which is handed to the function `take()`
(built into Peggi), which returns the item at position 1 in that list, that is, the
result of the expression which should be a number. Well, and if one of these three
matches fail, Peggi attempts to match the regular expression `\s*[-0-9.]\+`, which
means a number, and gives the matched string to the function str2float() (built into
Vim) which, as the name suggests, makes a number out of it. So, in every case, applying
the nonterminal Factor to a string, it returns a number (assuming Expression returns a
number and there is no parse fail).

# Grammar

The grammar is specified as one (big) string. The best is to format it like this:
```viml
let grammar = '
    \ Nonterminal1 = grammar expression ...
    \ Nonterminal2 = other expression ...
    \'
```
Because of the sloppy highlight of the standard Vimscript syntax file, this gets a nice
highlight, when displayed in Vim. Notice the space between the \ and the nonterminals.

For more information about Parsing Expression Grammar, see
[PEG](en.wikipedia.org/wiki/Parsing_expression_grammar).
In Peggi, a grammar expression has one of the following forms:

```
.---------------+------------------------------+------------------------------.
| Form          | Function                     | Yields                       |
+===============+==============================+==============================+
| /regexp/      | matches and consumes the     | the matched string or Fail   |
|               | regexp in the input string   | if it doesn't match          |
+---------------+------------------------------+------------------------------+
| "string"      | matches and consumes the     | the matched string or Fail   |
|               | string                       | if it doesn't match          |
+---------------+------------------------------+------------------------------+
| Nonterminal   | matches the right side of    | whatever the right side of   |
|               | this nonterminal             | the nonterminal yields       |
+---------------+------------------------------+------------------------------+
| Expr1 Expr2   | matches first Expr1 and if   | the concatenated results of  |
|               | it's successfull match Expr2 | Expr1 and Expr2 if both are  |
|               | afterwards                   | lists or strings, or Fail if |
|               |                              | one of them fails            |
+---------------+------------------------------+------------------------------+
| Expr1, Expr2  | matches first Expr1 and if   | the results of Expr1 and     |
|               | it's successfull match Expr2 | Expr2 as list of strings, or |
|               | afterwards                   | Fail if one of them fails    |
+---------------+------------------------------+------------------------------+
| Expr1 | Expr2 | matches first Expr1 and, if  | either what Expr1 or what    |
|               | it's not successfull, match  | Expr2 yields, or Fail if     |
|               | Expr2 at the same position   | both of them fail            |
|               | as Expr1                     |                              |
+---------------+------------------------------+------------------------------+
| Expr?         | matches Expr 0 or 1 times    | what Expr returns if it      |
|               |                              | matches, '' if it fails      |
+---------------+------------------------------+------------------------------+
| Expr*         | matches Expr 0 or more times | a (possibly empty) list of   |
|               | (greedy)                     | what Expr yields             |
+---------------+------------------------------+------------------------------+
| Expr°         | matches Expr 0 or more times | the concatenated results of  |
|               | (greedy)                     | Expr if the results are      |
|               |                              | strings or lists             |
+---------------+------------------------------+------------------------------+
| Expr+         | matches Expr 1 or more times | a list of what Expr yields,  |
|               | (greedy)                     | or Fail if it matches not a  |
|               |                              | single time                  |
+---------------+------------------------------+------------------------------+
| Expr#         | matches Expr 1 or more times | the concatenated results of  |
|               | (greedy)                     | Expr if the results are      |
|               |                              | strings or lists, or Fail if |
|               |                              | it matches not a single time |
+---------------+------------------------------+------------------------------+
| &Expr         | matches Expr, but doesn't    | '' if Expr matches, Fail     |
|               | consume it                   | otherwise                    |
+---------------+------------------------------+------------------------------+
| !Expr         | matches Expr, but doesn't    | Fail if Expr matches, ''     |
|               | consume it                   | otherwise                    |
+---------------+------------------------------+------------------------------+
| (Expr)        | matches Expr                 | whatever Expr yields         |
'---------------+------------------------------+------------------------------'
```

(Note: “Match and consume” means that the string is matched and the internal pointer
moves on to the place behind the matched string in order to match the next tokens.
“Matching without consuming” means the next expression is matched to the very same part
of the string. So `&Expr1 &Expr2 Expr3` means that all three expressions are matched to
the same part of the string.)

(Note 2: Due to Vims strange behavior concerning line endings, use `/\r/` instead of
`/\n/` to match a line break.)

## Special Items

### Comments
e.g. `Nonterminal = Expr1 | Expr2 Expr3   {Comment}`

Comments can only appear at the end of a rule definition.

### Transformation functions
e.g. `Expr.function("arg1", "arg2")` 

The result of matching Expr is handed as the first argument to function(), followed by
the given additional arguments. Additional arguments must always be enclosed in double
quotes. Functions can be concatenated: `Expr.fu1("arg1").fu2("arg2")`.
Unfortunately, only global functions (that means, starting with a capital, with `g:` or
functions that sit in an autoload directory) can be used as transformation functions.
Script-local functions (starting with `s:`) won't work, because Peggi is a different
script from your script.

Peggi has some functions built in:

```
.------------------------------+------------------------------.
| Function                     | Function (I mean, function   |
|                              | of the function)             |
+==============================+==============================+
| Expr.strip()                 | cuts whitespace off from     |
|                              | left and right               |
+------------------------------+------------------------------+
| Expr.tag("ul")               | surrounds the result of Expr |
|                              | with `<ul>` and `</ul>`. An  |
|                              | optional second argument is  |
|                              | the tag attribute.           |
+------------------------------+------------------------------+
| Expr.replace(":)")           | replaces the result of Expr  |
|                              | with a funny smiley. Highly  |
|                              | recommended!                 |
+------------------------------+------------------------------+
| Expr.surround("before",      | surrounds the result of Expr |
| "after")                     |                              |
+------------------------------+------------------------------+
| Expr.concat()                | if Expr yields a list of     |
|                              | strings, concatenate them    |
+------------------------------+------------------------------+
| Expr.join(", ")              | if Expr yields a list of     |
|                              | strings, join them nicely    |
+------------------------------+------------------------------+
| Expr.skip()                  | Just return an empty string. |
|                              | Of course, Expr is still     |
|                              | matched and consumed.        |
+------------------------------+------------------------------+
| Expr.take("2")               | if Expr returns a list,      |
|                              | return the item at index 2   |
|                              | (counted from zero)          |
'------------------------------+------------------------------'
```


### Indentation
Normally, Parsing Expression Grammar is not powerful enough to deal with text where the
indentation of a line determines some kind of level of that line (like, for example, in
Python source code) because that is context sensitive information while PEG only
understands (roughly) context free properties.
But because Peggi is so cool, Peggi can, albeit with a rather awkward syntax:

`Nonterminal^ = Expr` means that whenever Peggi starts to match the nonterminal
`Nonterminal`, the indentation at the current position is pushed on a stack. It is
popped off as soon as the rule is done, whether successfully or not. Inside the rule,
the expression `>` matches and consumes as much whitespace as possible and succeeds if
and only if the amount of whitespace is larger than the indentation on top of the
stack. The expression `>=` works analogous.

As an example, take a look at the following grammar definition. It parses bulleted
lists and converts them to HTML.
```viml
let s:grammar = '
            \ list = ((&> list_item)+).tag("ul")         { a list consists of list_items that are
            \                                                   more indented than a surrounding list;
            \                                                   at the global level, > succeeds always }
            \ bullet = /\s*[-*]\s\+/
            \ list_item^ = bullet.replace("<li>") text   { list_item is what determines the allowed
            \                                                               indentation of its subitems }
            \ text = textline indented_textline°
            \ indented_textline = list | (> textline)
            \ textline = /[^\r]\+/ /\r/.skip()
            \'

echo peggi#peggi#parse_file_begin(s:grammar, filename, 'list')
```

An example list:
```
- a list
  continuation
  * a list inside a list
  * crazy, hu?
  outer list continued
- next list item
```

# Calling Peggi
`:let result = peggi#peggi#parse(grammar, input_string, start_nonterminal)`

Starts Peggi with an input string. Tries to match the whole string.


`:let result = peggi#peggi#parse_begin(grammar, input_string, start_nonterminal)`

Peggi matches from the start of the string on as long as Peggi matches. If there is
garbage in the input string that cannot be matched by the grammar, Peggi silently stops
and returns what it matched so far.


`let result = peggi#peggi#parse_file(grammar, filename, start_nonterminal)`
`let result = peggi#peggi#parse_file_begin(grammar, filename, start_nonterminal)`

Like above, but parse the content of the given filename instead of a given string.

# Peggi options
## Debugging
`:call peggi#peggi#debug(value)`

Configures Peggi to spit out debug messages while parsing. The messages are printed to
an own buffer in a new tab.

value = 0: print nothing
value = 1: print out the parsing state on every step
value = 2: like 1, additionally, print out the internal form of your grammar

## Inlining
`:call peggi#peggi#inline_nonterminals(value)`

If value = 1, Peggi changes the grammar, so that all nonterminals in the right side of
a rule are substituted with the respective right side of that nonterminal. The parsing
may or may not be a little bit faster after inlining. Of course, only nonrecursive
nonterminals are inlined.

If value = 2, the nonterminals are only inlined if debug is set to 0 so that the debug
messages are easier to interpret. It's still hard.

For example, after inlining, the following grammar
```
    bla = blubb blubber
    blubb = "lol" blubb
    blubber = "rofl"
```
becomes
```
    bla = blubb "rofl"
    blubb = "lol" blubb
```

## Transformation function Prefix
`:call peggi#peggi#transformation_prefix("myplugin#")`

Every transformation function (except for the ones built in) is prefixed with the given string.


# License

The MIT License (MIT)

Copyright (c) 2014 Daniel Schemala

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
