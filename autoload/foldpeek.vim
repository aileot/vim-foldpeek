" ============================================================================
" Repo: kaile256/vim-foldpeek
" File: autoload/foldpeek.vim
" Author: kaile256
" License: MIT license {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" ============================================================================

"if v:version < 730 | finish | endif
"" v7.3: for strdisplaywidth()

if !has('patch-7.4.156') | finish | endif
" v:7.4.156: for func-abort

if exists('g:loaded_foldpeek') | finish | endif
let g:loaded_foldpeek = 1
" save 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

" Define Helper Functions {{{1
function! s:set_variables(prefix, suffixes, default) abort
  " TODO: this function returns l:var; defines g:var, b:var, s:var and so on.
  " (of cource, meaningless for either a:var or v:var)

  " Example:
  "   a:prefix: 'g:foldpeek#whiteout_patterns_'
  "     -> pre: 'g:'
  "     -> fix: 'foldpeek#whiteout_patterns_'
  "   a:suffixes: ['omit', 'fill']
  "     -> type: could be either 'omit' and 'fill'
  "   a:default: []

  let pre = matchstr(a:prefix, '^\w:')
  let fix = matchstr(a:prefix, pre .'\zs.*')

  if empty(pre) || pre ==# 'l:'
    throw 'l:var is unsupported'
  endif

  let prefix = pre
  for sfx in a:suffixes
    " Example:
    "   var:    'g:foldpeek#whiteout_patterns_omit'
    "   prefix: 'g:'
    "   suffix: 'foldpeek#whiteout_patterns_omit'
    let var    = a:prefix . sfx
    let suffix = fix . sfx

    let {var} = get({prefix}, suffix, a:default)
  endfor
endfunction

" Initialze Global Variables {{{1
let g:foldpeek#maxspaces       = get(g:, 'foldpeek#maxspaces', &shiftwidth)
let g:foldpeek#auto_foldcolumn = get(g:, 'foldpeek#auto_foldcolumn', 0)

let g:foldpeek#maxwidth        = get(g:, 'foldpeek#maxwidth',
      \ '&textwidth > 0 ? &tw : 79'
      \ )
let g:foldpeek#skip_patterns   = get(g:, 'foldpeek#skip_patterns', [
      \ '^[>#\-=/{!* \t]*$',
      \ ])
let g:foldpeek#override_skip_patterns =
      \ get(g:, 'foldpeek#override_skip_patterns', 0)

let g:foldpeek#indent_with_head = get(g:, 'foldpeek#indent_with_head', 0)
let g:foldpeek#head = get(g:, 'foldpeek#head', {
      \ 1: "v:foldlevel > 1 ? v:foldlevel .') ' : v:folddashes"
      \ })
let g:foldpeek#tail = get(g:, 'foldpeek#tail', {
      \ 1: "' ['. (v:foldend - v:foldstart + 1) .']'",
      \ 2: "' [%PEEK%/'. (v:foldend - v:foldstart + 1) .']'",
      \ })

let g:foldpeek#table = get(g:, 'foldpeek#table', {})

let s:whiteout_styles = ['left', 'omit', 'fill', 'substitute']
call s:set_variables('g:foldpeek#whiteout_patterns_',
      \ filter(deepcopy(s:whiteout_styles), 'v:val !=# "substitute"'), [])
let g:foldpeek#whiteout_patterns_substitute =
      \ get(g:, 'foldpeek#whiteout_patterns_substitute', [
      \   ['{\s*$', '{...}', ''],
      \   ['[\s*$', '[...]', ''],
      \   ['(\s*$', '(...)', ''],
      \ ])
let g:foldpeek#disabled_whiteout_styles =
      \ get(g:, 'foldpeek#disabled_whiteout_styles', [])
let g:foldpeek#overrided_whiteout_styles =
      \ get(g:, 'foldpeek#overrided_whiteout_styles', [])

let g:foldpeek#whiteout_style_for_foldmarker =
      \ get(g:, 'foldpeek#whiteout_style_for_foldmarker', 'omit')

function! foldpeek#text() abort "{{{1
  if g:foldpeek#auto_foldcolumn && v:foldlevel > (&foldcolumn - 1)
    let &foldcolumn = v:foldlevel + 1
  endif

  let [body, peeklnum] = s:peekline()
  let [head, tail]     = s:decorations(peeklnum)
  return s:return_text(head, body, tail)
endfunction

function! s:peekline() abort "{{{2
  let add  = 0
  let line = getline(v:foldstart)

  while add <= (v:foldend - v:foldstart)
    if string(get(b:, 'foldpeek_disabled_whiteout_styles',
          \ g:foldpeek#disabled_whiteout_styles)) !~# 'ALL'
      " Profile: s:whiteout_at_patterns() is a bottle-neck according to
      "   `:profile`
      let line = s:whiteout_at_patterns(line)
    endif

    if ! s:skippattern(line) | return [line, add + 1] | endif
    " Note: keep `+ 1` after s:skippattern()
    let add  += 1
    let line  = getline(v:foldstart + add)
  endwhile

  return [getline(v:foldstart), 1]
endfunction

function! s:whiteout_at_patterns(line) abort "{{{3
  for type in s:whiteout_styles
    let {'patterns_'. type} = s:set_whiteout_patterns(type)
  endfor

  let ret = a:line

  let match_for_left = s:whiteout_left(ret, patterns_left)

  if !empty(match_for_left)
    let ret = match_for_left

  else
    let style_for_foldmarker = s:set_style_for_foldmarker()
    let {'patterns_'. style_for_foldmarker} += s:foldmarkers_on_buffer()

    let ret = s:whiteout_omit(ret, patterns_omit)
    let ret = s:whiteout_fill(ret, patterns_fill)
  endif

  let ret = s:whiteout_substitute(ret, patterns_substitute)

  if &ts != &sw
    let ret = substitute(ret, '^\t', repeat(' ', &tabstop), '')
  endif
  return substitute(ret, '\t', repeat(' ', &shiftwidth), 'g')
endfunction

function! s:set_whiteout_patterns(type) abort "{{{4
  let disabled_styles = string(get(b:, 'foldpeek_disabled_whiteout_styles',
        \ g:foldpeek#disabled_whiteout_styles))
  let overrided_styles = string(get(b:, 'foldpeek_overrided_whiteout_styles',
        \ g:foldpeek#overrided_whiteout_styles))

  if disabled_styles =~# a:type .'\|ALL'
    return []

  elseif overrided_styles =~# a:type .'\|ALL'
    " Note: without deepcopy(), {'g:foldpeek#whiteout_patterns_'. (a:type)} will
    " increase their values infinitely.
    return deepcopy(get(b:, 'foldpeek_whiteout_patterns_'. a:type,
          \ {'g:foldpeek#whiteout_patterns_'. a:type}))
  endif

  return get(b:, 'foldpeek_whiteout_patterns_'. a:type, [])
        \ + {'g:foldpeek#whiteout_patterns_'. a:type}
endfunction

function! s:whiteout_left(text, patterns) abort "{{{4
  let ret = ''

  for pat in a:patterns
    if type(pat) == type('')
      let ret = matchstr(a:text, pat)

    elseif type(pat) == type([])
      for p in pat
        let l:match = matchstr(a:text, p)

        if empty(l:match)
          let ret = ''
          continue
        endif

        let ret .= l:match
      endfor

    else
      throw 'type of pattern to be left must be either String or List'
    endif

    if !empty(ret) | break | endif
  endfor

  return ret
endfunction

function! s:whiteout_omit(text, patterns) abort "{{{4
  let ret = a:text
  for pat in a:patterns
    let matchlen = len(matchstr(ret, pat))

    while matchlen > 0
      let ret .= repeat(' ', matchlen)
      let ret  = substitute(ret, pat, '', '')
      let matchlen = len(matchstr(ret, pat))
    endwhile
  endfor

  return ret
endfunction

function! s:whiteout_fill(text, patterns) abort "{{{4
  let ret = a:text
  for pat in a:patterns
    let ret = substitute(ret, pat, repeat(' ', len('\0')), 'g')
  endfor
  return  ret
endfunction

function! s:whiteout_substitute(text, lists) abort "{{{4
  let ret = a:text

  for l:list in a:lists
    let pat   = l:list[0]
    let sub   = l:list[1]
    let flags = l:list[2]

    let ret = substitute(ret, pat, sub, flags)
  endfor

  return ret
endfunction

function! s:set_style_for_foldmarker() abort "{{{4
  let ret = get(b:, 'foldpeek_whiteout_style_for_foldmarker',
        \ g:foldpeek#whiteout_style_for_foldmarker)

  if index(s:whiteout_styles, ret) < 0
    return 'omit'
  endif

  return ret
endfunction

function! s:foldmarkers_on_buffer() abort "{{{4
  if exists('b:foldpeek__foldmarkers')
    return b:foldpeek__foldmarkers
  endif

  let cms = split(&commentstring, '%s')
  " Note:  at end-of-line, replace cms which is besides foldmarker
  let foldmarkers = map(split(&foldmarker, ','),
        \ "'['. cms[0] .' ]*'.  v:val .'\\d*['. cms[len(cms) - 1] .' ]*$'")
  " TODO: except at end-of-line, constantly make a whitespace replace markers
  let foldmarkers += map(split(&foldmarker, ','),
        \ "'\\<'.  v:val .'\\d*\\>'")

  let b:foldpeek__foldmarkers = foldmarkers
  return b:foldpeek__foldmarkers
endfunction

function! s:skippattern(line) abort "{{{3
  if get(b:, 'foldpeek_override_skip_patterns', g:foldpeek#override_skip_patterns)
    let patterns = get(b:, 'foldpeek_skip_patterns', g:foldpeek#skip_patterns)
  else
    let patterns = get(b:, 'foldpeek_skip_patterns', [])
          \ + g:foldpeek#skip_patterns
  endif

  for pat in patterns
    if a:line =~# pat | return 1 | endif
  endfor
  return 0
endfunction

function! s:decorations(num) abort "{{{2
  let head = get(b:, 'foldpeek_head', g:foldpeek#head)
  let tail = get(b:, 'foldpeek_tail', g:foldpeek#tail)

  for num in keys(head)
    if a:num >= num
      let head = exists('b:foldpeek_head')
            \ ? b:foldpeek_head[num]
            \ : g:foldpeek#head[num]
    endif
  endfor

  for num in keys(tail)
    if a:num >= num
      let tail = exists('b:foldpeek_tail')
            \ ? b:foldpeek_tail[num]
            \ : g:foldpeek#tail[num]
    endif
  endfor

  let head = s:substitute_as_table(head)
  let tail = s:substitute_as_table(tail)
  let head = substitute(head, '%PEEK%', a:num, 'g')
  let tail = substitute(tail, '%PEEK%', a:num, 'g')

  "for part in ['head', 'tail']
  "  let {part} = get(b:, {'foldpeek_'. part}, {'g:foldpeek#'. part})

  "  for num in keys(part)
  "    if a:num >= num
  "      let {part} = exists({'b:foldpeek_'. part})
  "            \ ? {'b:foldpeek_'. part}[num]
  "            \ : {'g:foldpeek#'. part}[num]
  "    endif
  "  endfor

  "  " Note: if empty(), head/tail shows '0'
  "  let {part} = empty(part) ? '' : eval(substitute(part, '%PEEK%', a:num, 'g'))
  "endfor

  let ret = []
  for part in [head, tail]
    try
      " Note: at failure of eval(), 0 is added to 'ret'
      call add(ret, eval(part))
    catch
      call add(ret, part)
    endtry
    call filter(ret, 'type(v:val) == type('')')
  endfor

  return ret
endfunction

function! s:substitute_as_table(line) abort "{{{3
  let dict = g:foldpeek#table

  if empty(a:line)
    return ''
  elseif empty(dict)
    return a:line
  endif

  let ret = a:line
  for l:key in sort(keys(dict), 'N')
    let l:val = dict[l:key]
    let pat = '%'. substitute(l:key, '^\d\d', '', 'g') .'%'
    if l:val =~# pat
      " FIXME: make the `:echoerr` work
      echoerr 'You set a recursive value in g:foldpeek#table at' l:key
    endif

    try
      " FIXME: only use eval() after this function outside
      let wanted = eval(l:val)
    catch
      let wanted = l:val
    endtry

    " TODO: enable 'expr' in recursive substitution, for example,
    "   {'result' : (%baz% > 0 ? '%foo% / %bar% : %foobar%)'} will work as
    "   '%result%'.
    let ret = substitute(ret, pat, wanted, 'g')
  endfor

  return ret
endfunction

function! s:return_text(head, body, tail) abort "{{{2
  " TODO: show all the text in correct width.
  "   len() only returns according to hex numbers which you can see by `g8`;
  "   thus, ambiwidth in len() returns 2 and unicode returns 3.
  " Note: the replacement of some chars with whitespaces has be done in the
  "   selection of peekline.
  let foldtextwidth = s:width_without_col()
  " TODO: get correct width of head and tail;
  let headwidth = len(a:head)
  let tailwidth = len(a:tail)
  let decorwidth = headwidth + tailwidth
  let bodywidth  = foldtextwidth - decorwidth

  let body = s:adjust_textlen(a:body, bodywidth)
  "let head = s:adjust_textlen(a:head, headwidth)
  "let tail = s:adjust_textlen(a:tail, tailwidth)

  let indent_with_head = get(b:, 'foldpeek_indent_with_head',
        \ g:foldpeek#indent_with_head)

  let without_tail = indent_with_head ? (body . a:head) : (a:head . body)
  return without_tail . a:tail
endfunction

function! s:width_without_col() abort "{{{3
  let numberwidth  = &number ? max([&numberwidth, len(line('$'))]) : 0
  let signcolwidth = s:signcolwidth()

  " FIXME: when auto_foldcolumn is true, &foldcolumn could be increased later.
  let nocolwidth = winwidth(0) - &foldcolumn - signcolwidth - numberwidth
  let maxwidth   = eval(g:foldpeek#maxwidth)
  return maxwidth > 0
        \ ? min([nocolwidth, maxwidth])
        \ : nocolwidth
endfunction

function! s:signcolwidth() abort "{{{4
  let ret = 0

  if &signcolumn =~# 'yes'
    let ret = matchstr(&signcolumn, '\d')
    return ret

  elseif &signcolumn !~# 'auto' | return ret | endif

  let maxwidth = matchstr(&signcolumn, '\d')
  if maxwidth < 1 | let maxwidth = 1 | endif

  redir => signs
  exe 'silent sign place buffer='. bufnr()
  redir END
  let signlist = split(signs, "\n")[2:]

  "let signlnum = map(signlist, "matchstr(v:val, 'line=\zs\d\+')")
  let signlnum = []
  for info in signlist
    call add(signlnum, matchstr(info, 'line=\zs\d\+'))
  endfor

  let i = 0
  " stop the loop at the second last in comparison with the first last
  while i < len(signlnum) - 2

    let ret = 1
    if ret >= maxwidth | break | endif

    if signlnum[i] == signlnum[i + 1]
      let duplnum   = signlnum[i]
      " count starts from twice
      let duptimes = 2
      let i += 2
      while duplnum == signlnum[i]
        let duptimes += 1
        let i += 1
      endwhile

      let ret = max(ret, duptimes)
    endif
  endwhile

  return ret
endfunction

function! s:adjust_textlen(body, bodywidth) abort "{{{3
  " Note: strdisplaywidth() returns up to &tabstop, &display and &ambiwidth
  let displaywidth = strdisplaywidth(a:body)
  if  a:bodywidth < displaywidth
    return s:ambiwidth_into_double(a:body, a:bodywidth)
  endif

  let lacklen       = strlen(a:body) - displaywidth
  let adjustedwidth = a:bodywidth + lacklen
  return printf('%-*s', adjustedwidth, a:body)
endfunction

function! s:ambiwidth_into_double(text, textwidth) abort "{{{4
  let [len, ret] = [0, '']
  for char in split(a:text, '\zs')
    " Note: strdisplaywidth() depends on &ambiwidth
    let len += strdisplaywidth(char)
    if len > a:textwidth | break | endif
    let ret .= char
  endfor
  " ambiwidth fills twice a width so that add a space for lack of length
  return strdisplaywidth(ret) ==# a:textwidth ? ret : ret .' '
endfunction

" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline "{{{1
" vim: expandtab tabstop=2 softtabstop=2 shiftwidth=2
" vim: foldmethod=marker textwidth=79
