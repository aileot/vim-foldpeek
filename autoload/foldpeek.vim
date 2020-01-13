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

let g:foldpeek#maxspaces       = get(g:, 'foldpeek#maxspaces', &shiftwidth)
let g:foldpeek#auto_foldcolumn = get(g:, 'foldpeek#auto_foldcolumn', 0)

let g:foldpeek#maxwidth        = get(g:, 'foldpeek#maxwidth',
      \ '&textwidth > 0 ? &tw : 79'
      \ )
let g:foldpeek#skip_patterns   = get(g:, 'foldpeek#skip_patterns', [
      \ '^[\-=/{!* \t]*$',
      \ ])
let g:foldpeek#whiteout_patterns_fill =
      \ get(g:, 'foldpeek#whiteout_patterns_fill', [])
let g:foldpeek#whiteout_patterns_omit =
      \ get(g:, 'foldpeek#whiteout_patterns_omit', [])
let g:foldpeek#whiteout_style_for_foldmarker =
      \ get(g:, 'foldpeek#whiteout_style_for_foldmarker', 'omit')

let g:foldpeek#indent_with_head = get(g:, 'foldpeek#indent_with_head', 0)
let g:foldpeek#head = get(g:, 'foldpeek#head', {
      \ 1: "v:foldlevel > 1 ? v:foldlevel .') ' : v:folddashes "
      \ })
let g:foldpeek#tail = get(g:, 'foldpeek#tail', {
      \ 1: "' ['. (v:foldend - v:foldstart + 1) .']'",
      \ 2: "' [%PEEK%/'. (v:foldend - v:foldstart + 1) .']'",
      \ })

let g:foldpeek#table = get(g:, 'foldpeek#table', {})

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
    " Note: replacement of whitespaces here for simpler pattern match
    let line = s:white_replace(line)
    if ! s:skippattern(line) | return [line, add + 1] | endif
    let add  += 1
    let line  = getline(v:foldstart + add)
  endwhile

  return [getline(v:foldstart), 1]
endfunction

function! s:white_replace(line) abort "{{{3
  let ret = a:line
  let cms = split(&commentstring, '%s')
  " Note:  at end-of-line, replace cms which is besides foldmarker
  let markers = map(split(&foldmarker, ','),
        \ "'['. cms[0] .' ]*'.  v:val .'\\d*[ '. cms[len(cms) - 1] .']*\\s*$'")
  " TODO: except at end-of-line, constantly make a whitespace replace markers
  let markers += map(split(&foldmarker, ','),
        \ "'\\s*'.  v:val .'\\d*'")

  let patterns_fill    = get(b:, 'foldpeek_whiteout_patterns_fill',
        \ g:foldpeek#whiteout_patterns_fill)
  let patterns_omit    = get(b:, 'foldpeek_whiteout_patterns_omit',
        \ g:foldpeek#whiteout_patterns_omit)

  let style_for_foldmarker = get(b:, 'foldpeek_whiteout_style_for_foldmarker',
        \ g:foldpeek#whiteout_style_for_foldmarker)

  if index(['omit', 'fill'], style_for_foldmarker)
    let style_for_foldmarker = 'omit'
  endif

  " Note: no visual effect on the marker at end of lines; only on those at
  "   head of lines or the others
  let {'patterns_'. style_for_foldmarker} += markers

  for pat in patterns_fill
    let ret = substitute(ret, pat, repeat(' ', len(matchstr(ret, pat))), 'g')
  endfor

  for pat in patterns_omit
    while len(matchstr(ret, pat))
      let ret .= repeat(' ', len(matchstr(ret, pat)))
      let ret  = substitute(ret, pat, '', '')
    endwhile
  endfor

  "if g:foldpeek#maxspaces >= 0
  "  " FIXME: keep the entire text length
  "  return substitute(ret,
  "        \ repeat('\s', g:foldpeek#maxspaces)  .'\+',
  "        \ repeat(' ',  g:foldpeek#maxspaces), 'g')
  "endif

  let ret = substitute(ret, '^\t', repeat(' ', &tabstop), '')
  return    substitute(ret,  '\t', repeat(' ', &shiftwidth), 'g')
endfunction

function! s:skippattern(line) abort "{{{3
  for pat in get(b:, 'foldpeek_skip_patterns', g:foldpeek#skip_patterns)
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
    try
      " FIXME: only use eval() after this function outside
      let l:val = eval(dict[l:key])
    catch
      let l:val = dict[l:key]
    endtry

    " TODO: enable 'expr' in recursive substituttion, for example,
    "   make {'result' : (%baz% > 0 ? '%foo% / %bar% : %foobar%)'} work at '%result%'
    let pat = substitute(l:key, '^\d\d', '', 'g')
    "while len(matchstr(ret, pat))
    let ret = substitute(ret, '%'. pat .'%', l:val, 'g')
    "endwhile
  endfor

  return ret
endfunction

function! s:return_text(head, body, tail) abort "{{{2
  " Note: the replacement of some chars with whitespaces has be done in the
  "   selection of peekline.
  let nocolwidth = s:nocolwidth()
  let bodywidth  = nocolwidth - a:decor_width
  " Note: strdisplaywidth() returns up to &tabstop, &display and &ambiwidth
  let displaywidth = strdisplaywidth(a:body)

  if bodywidth < displaywidth
    " set a line which includes ambiwidth chars
    let [len, ret] = [0, '']
    for char in split(a:body, '\zs')
      let len += strdisplaywidth(char)
      if len > bodywidth | break | endif
      let ret .= char
    endfor
    " ambiwidth fills twice a width
    return strdisplaywidth(ret) == bodywidth ? ret : ret .' '
  endif

  let indent_with_head = get(b:, 'foldpeek_indent_with_head',
        \ g:foldpeek#indent_with_head)
  return substitute(body, '^\s*\ze',
        \ (indent_with_head ? '\0'. a:head : a:head .'\0'),
        \ '') . a:tail
endfunction

function! s:nocolwidth() abort "{{{4
  let numberwidth  = &number ? max([&numberwidth, len(line('$'))]) : 0
  let signcolwidth = s:signcolwidth()

  " FIXME: when auto_foldcolumn is true, &foldcolumn could be increased later.
  let nocolwidth = winwidth(0) - &foldcolumn - signcolwidth - numberwidth
  let maxwidth   = eval(g:foldpeek#maxwidth)
  return maxwidth > 0
        \ ? min([nocolwidth, maxwidth])
        \ : nocolwidth
endfunction

function! s:signcolwidth() abort "{{{5
  let ret = 0

  if &signcolumn =~# 'yes'
    let ret = matchstr(&signcolumn, '\d')
    return ret
    " ambiwidth fills twice a width
    " ambiwidth fills twice a width
    " ambiwidth fills twice a width

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

" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline "{{{1
" vim: expandtab tabstop=2 softtabstop=2 shiftwidth=2
" vim: foldmethod=marker textwidth=79
