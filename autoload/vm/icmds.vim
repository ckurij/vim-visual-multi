"script to handle several insert mode commands

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#icmds#init()
    let s:V = b:VM_Selection
    let s:v = s:V.Vars
    let s:G = s:V.Global
    let s:F = s:V.Funcs
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Lambdas
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if v:version >= 800
    let s:R    = { -> s:V.Regions }
    let s:X    = { -> g:Vm.extend_mode }
    let s:size = { -> line2byte(line('$') + 1) - 1 }
else
    let s:R    = function('vm#v74#regions')
    let s:X    = function('vm#v74#extend_mode')
    let s:size = function('vm#v74#size')
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#icmds#x(cmd)
    let size = s:size()    | let s:change = 0 | let s:v.eco = 1
    if empty(s:v.storepos) | let s:v.storepos = getpos('.')[1:2] | endif

    for r in s:R()

        call r.shift(s:change, s:change)
        call s:F.Cursor(r.A)

        " we want to emulate the behaviour that <del> and <bs> have in insert
        " mode, but implemented as normal mode commands

        if a:cmd ==# 'x' && s:eol(r)        "at eol, join lines
            normal! gJ
        elseif a:cmd ==# 'x'                "normal delete
            normal! x
        elseif a:cmd ==# 'X' && r.a == 1    "at bol, go up and join lines
            normal! kgJ
            call r.shift(-1,-1)
        else                                "normal backspace
            normal! X
            call r.shift(-1,-1)
        endif

        "update changed size
        let s:change = s:size() - size
    endfor

    call s:G.merge_regions()
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#icmds#cw()
    let s:v.storepos = getpos('.')[1:2]
    let s:v.direction = 1 | let n = 0

    for r in s:R()
        if s:eol(r)
            "c-w requires an additional extra space, will be fixed on its own
            call setline(r.L, getline(r.L).'  ')
            call add(s:v.cw_spaces, r.index)
        endif
    endfor
    call vm#operators#select(1, 1, 'b')
    normal h"_d
    call s:G.merge_regions()
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#icmds#paste()
    call s:G.select_region(-1)
    call s:V.Edit.paste(1, 0, 1, '"')
    call s:G.select_region(s:V.Insert.index)
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#icmds#return()
    let indentexpr = !empty(&indentexpr)
    let autoindent = !indentexpr && &autoindent
    let indent = 0

    "invert regions order, so that they are processed from bottom to top
    let s:V.Regions = reverse(s:R())

    for r in s:R()
        call cursor(r.l, r.a)
        let rline = getline('.')

        "get indent level for the current line, if using autoindent
        if autoindent
            let indent = strlen(matchstr(rline, '^[ \t]*'))
        endif

        "if not at eol, CR will cut the line and carry over the remaining text
        let at_eol = r.a >= col([r.l, '$']) - 1

        "if carrying over some text, delete it now, for better indentexpr
        "otherwise delete the trailing space that would be left at EOL
        if !at_eol
            normal! d$
        elseif rline[-1:-1] == ' '
            normal! "_x
        endif

        "append a line with a dummy char, to be able to indent it
        call append(line('.'), '-')
        normal! j

        "get indent level for the new line, if using indentexpr
        "if carrying over text, no need to find the indent
        if at_eol && indentexpr
            normal! ==
            let indent = strlen(matchstr(getline('.'), '^[ \t]*'))
        endif

        "fill the line with tabs or spaces, according to the found indent
        "an extra space must be added, if not carrying over any text
        let extra_space = at_eol ? ' ' : ''
        call setline('.', repeat(&et ? " " : "\t", indent) . extra_space)

        "if carrying over some text, paste it after the indent
        if !at_eol
            normal! $p
            if indentexpr
                normal! ==
            endif
        endif

        "cursor line will be moved down by the next cursors
        call r.update_cursor([line('.') + r.index, indent + 1])
    endfor

    "reorder regions
    let s:V.Regions = reverse(s:R())

    "move back cursors to indent level
    normal ^

    "remove extra spaces that could have been left in the new lines
    call s:V.Edit.extra_spaces.remove()
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#icmds#insert_line(above)
    let indentexpr = !empty(&indentexpr)
    let autoindent = !indentexpr && &autoindent
    let indent = 0

    for r in s:R()
        "cursor line will be moved down by the next cursors
        let r.l += r.index

        "get indent level for the current line, if using autoindent
        if autoindent
            let indent = strlen(matchstr(getline(r.l), '^[ \t]*'))
        endif

        "append a line with a dummy char, to be able to indent it
        call cursor(r.l, r.a)
        call append(line('.') - a:above, '-')
        exe "normal!" (a:above ? 'k' : 'j')

        "get indent level for the new line, if using indentexpr
        if indentexpr
            normal! ==
            let indent = strlen(matchstr(getline('.'), '^[ \t]*'))
        endif

        "fill the line with tabs or spaces
        call setline('.', repeat(&et ? " " : "\t", indent).' ')

        call r.update_cursor([line('.'), indent + 1])
        call add(s:v.extra_spaces, r.index)
    endfor
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if v:version >= 800
    let s:E   = { r -> col([r.l, '$']) }
    let s:eol = { r -> r.a == (s:E(r) - 1) }
    finish
endif

fun! s:E(r)
    return col([a:r.l, '$'])
endfun

fun! s:eol(r)
    return a:r.a == (s:E(a:r) - 1)
endfun
