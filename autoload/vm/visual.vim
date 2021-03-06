"commands to add/subtract regions with visual selection
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#visual#add(mode) abort
    call s:backup_map()
    let [ w, h ] = [ 0, 0 ]

    if a:mode ==# 'v'     | call s:vchar()
    elseif a:mode ==# 'V' | call s:vline()
    else                  | let w = s:vblock(1)
    endif

    call s:merge(0)

    if a:mode ==# 'V'
        call s:G.split_lines()
        call s:G.remove_empty_lines()
    elseif a:mode ==# 'v'
        for r in s:R()
            if r.h | let h = 1 | break | endif
        endfor
    endif

    if h | let s:v.multiline = 1 | endif
    call s:G.update_and_select_region({'id': s:v.IDs_list[-1]})
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#visual#subtract(mode) abort
    let X = s:backup_map()

    if a:mode ==# 'v'     | call s:vchar()
    elseif a:mode ==# 'V' | call s:vline()
    else                  | call s:vblock(1)
    endif

    call s:merge(1)
    call s:G.update_and_select_region({'id': s:v.IDs_list[-1]})
    if X | call s:G.cursor_mode() | endif
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#visual#reduce() abort
    let X = s:backup_map()
    call s:G.rebuild_from_map(s:Bytes, [s:F.pos2byte("'<"), s:F.pos2byte("'>")])
    if X | call s:G.cursor_mode() | endif
    call s:G.update_and_select_region()
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#visual#cursors(mode) abort
    """Create cursors, one for each line of the visual selection."""
    call s:backup_map()

    "convert to visual block, if not V
    if a:mode ==# 'v' | exe "normal! \<C-v>" | endif

    if a:mode ==# 'V' | call s:vline()
    else              | call s:vblock(0)
    endif

    call s:merge(0)

    if a:mode ==# 'V'
        call s:G.split_lines()
        call s:G.cursor_mode()
        if get(g:, 'VM_autoremove_empty_lines', 1)
            call s:G.remove_empty_lines()
        endif
    else
        call s:G.cursor_mode()
    endif

    call s:G.update_and_select_region({'id': s:v.IDs_list[-1]})
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! vm#visual#split() abort
    """Split regions with regex pattern."""
    call s:init()
    if !len(s:R()) | return
    elseif !s:X()  | return s:F.msg('Not in cursor mode.')  | endif

    echohl Type   | let pat = input('Pattern to remove > ') | echohl None
    if empty(pat) | return s:F.msg('Command aborted.')      | endif

    let start = s:R()[0]                "first region
    let stop = s:R()[-1]                "last region

    call s:F.Cursor(start.A)            "check for a match first
    if !search(pat, 'nczW', stop.L)     "search method: accept at cursor position
        call s:F.msg("\t\tPattern not found")
        return s:G.select_region(s:v.index)
    endif

    call s:backup_map()

    "backup old patterns and create new regions
    let oldsearch = copy(s:v.search)
    call s:V.Search.get_slash_reg(pat)

    call s:G.get_all_regions(start.A, stop.B)

    "subtract regions and rebuild from map
    call s:merge(1)
    call s:V.Search.join(oldsearch)
    call s:G.update_and_select_region()
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:vchar() abort
    "characterwise
    silent keepjumps normal! `<y`>`]
    call s:G.check_mutliline(0, s:G.new_region())
endfun

fun! s:vline() abort
    "linewise
    silent keepjumps normal! '<y'>`]
    call s:G.new_region()
endfun

fun! s:vblock(extend) abort
    "blockwise
    let start = getpos("'<")[1:2]
    let end = getpos("'>")[1:2]
    let w = end[1] - start[1]

    "create cursors downwards until end of block
    call cursor(start)

    while getpos('.')[1] < end[0]
        call vm#commands#add_cursor_down(0, 1)
    endwhile

    if a:extend
        call vm#commands#motion('l', w, 1, 0)
    endif
    return w
endfun

fun! s:backup_map() abort
    "use temporary regions, they will be merged later
    call s:init()
    let X = s:G.extend_mode()
    let s:Bytes = copy(s:V.Bytes)
    call s:G.erase_regions()
    let s:v.no_search = 1
    let s:v.eco = 1
    return X
endfun

fun! s:merge(subtract) abort
    "merge or subtract regions
    let new_map = copy(s:V.Bytes)
    let s:V.Bytes = s:Bytes
    if a:subtract | call s:G.subtract_maps(new_map)
    else          | call s:G.merge_maps(new_map)
    endif
    unlet new_map
endfun

fun! s:init() abort
    "init script vars
    let s:V = b:VM_Selection
    let s:v = s:V.Vars
    let s:G = s:V.Global
    let s:F = s:V.Funcs
endfun

let s:R = { -> s:V.Regions }
let s:X = { -> g:Vm.extend_mode }


" vim: et ts=4 sw=4 sts=4 :
