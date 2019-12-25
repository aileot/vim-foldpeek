" ============================================================================
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

if v:version < 730 | finish | endif
" v7.3: for strdisplaywidth()

if exists('g:loaded_foldpeek') | finish | endif
let g:loaded_foldpeek = 1
" save 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

let g:foldpeek#maxwidth        = get(g:, 'foldpeek#maxwidth', 78)
let g:foldpeek#auto_foldcolumn = get(g:, 'foldpeek#auto_foldcolumn', 0)

let g:foldpeek#skipline_chars  = get(g:, 'foldpeek#skipline_chars',
      \ '\-=#/{\t\\ ')

let g:foldpeek#head = get(g:, 'foldpeek#head',
      \ "v:foldlevel > 1 ? v:foldlevel .') ' : v:folddashes ")
let g:foldpeek#tail = get(g:, 'foldpeek#tail', {
      \ 1: "' ['. (v:foldend - v:foldstart + 1) .']'",
      \ 2: "' [%lnum%/'. (v:foldend - v:foldstart + 1) .']'",
      \ })

function! foldpeek#text() abort "{{{1
  if g:foldpeek#auto_foldcolumn && v:foldlevel > (&foldcolumn - 1)
    let &foldcolumn = v:foldlevel + 1
  endif

  let [body, peeklnum] = s:peekline()
  let [head, tail] = s:decorations(peeklnum)

  return s:return_text(body, [head, tail])
endfunction

function! s:peekline() abort "{{{2
  let add  = 0
  let line = getline(v:foldstart)
  " Note: insert whitespace here for `pattern`
  let cms  = substitute(&commentstring, '%s', '', '')

  while add <= (v:foldend - v:foldstart)
    let chars   = cms . g:foldpeek#skipline_chars
    let pattern = '^['. chars .']*$'
    " Note: in [], `\s` only indicates a backslash and a 'literal s'
    " Note: have to use regexp (un)matches with [] between `^` and `$`
    if line !~# pattern | return [line, add + 1] | endif

    let add  += 1
    let line  = getline(v:foldstart + add)
  endwhile

  return [getline(v:foldstart), 1]
endfunction

function! s:decorations(num) abort "{{{2
  " TODO: bundle head and tail in for-loop
  " TODO: buflocal config
  let head = get(b:, 'foldpeek_head', g:foldpeek#head)
  let tail = get(b:, 'foldpeek_tail', g:foldpeek#tail)

  if type(head) == type({})
    for num in sort(keys(head))
      if num > a:num | break | endif
      let head = eval(get(b:, 'forkpeek_head.'. num, g:foldpeek#head[num]))
    endfor
  else
    let head = eval(get(b:, 'foldpeek_head', head))
  endif

  if type(tail) == type({})
    for num in sort(keys(tail))
      if num > a:num | break | endif
      let tail = eval(get(b:, 'forkpeek_tail.'. num, g:foldpeek#tail[num]))
    endfor
  else
    let tail = eval(get(b:, 'foldpeek_tail', tail))
  endif

  " Note: empty() makes sure head/tail not to show '0'
  let head = empty(head) ? '' : substitute(head, '%lnum%', a:num, 'g')
  let tail = empty(tail) ? '' : substitute(tail, '%lnum%', a:num, 'g')

  return [head, tail]
endfunction

function! s:return_text(text, decor) abort "{{{2
  let [head, tail] = a:decor

  let body = s:adjust_bodylen(a:text, strlen(head) + strlen(tail))

  return substitute(body, '^\s*\ze',
        \ (get(g:, 'foldpeek#indent_head', 0) ? '\0'. head : head .'\0'),
        \ '') . tail
endfunction

function! s:adjust_bodylen(str, decor_width) abort "{{{3
  let body = s:white_replace(a:str)

  let availablewidth = s:availablewidth()
  let bodywidth      = availablewidth - a:decor_width
  let displaywidth   = strdisplaywidth(body)
  if displaywidth < bodywidth
    " TODO: show in correct width for multibyte characters
    let lacklen = strlen(body) - displaywidth
    let bodywidth += lacklen
    return printf('%-*s', bodywidth, body)
  endif

  let [len, ret] = [0, '']
  for char in split(body, '\zs')
    let len += strdisplaywidth(char)
    if len > bodywidth | break | endif
    let ret .= char
  endfor
  return strdisplaywidth(ret) == bodywidth ? ret : ret .' '
endfunction

function! s:white_replace(str) abort "{{{4
  let cms     = split(&commentstring, '%s')
  let fdmleft = substitute(&foldmarker, ',.*', '', '')

  let pattern = empty(cms)     ? fdmleft .'\%[\d]'
        \ : '\%['. cms[0] .' ]'. fdmleft .'\%[\d]\%[ '. cms[len(cms) - 1] .']'

  let str = substitute(a:str, pattern, repeat(' ', len(fdmleft)), 'g')
  return substitute(str, '\t', repeat(' ', &tabstop), 'g')
endfunction

function! s:availablewidth() abort "{{{1
  let numberwidth = &number ? max([&numberwidth, len(line('$'))]) : 0

  let signcolwidth = 0
  if !empty(sign_getplaced('%')[0].signs) || &signcolumn =~# 'yes'
    let signcolwidth = matchstr(&signcolumn, '\d')
    if empty(signcolwidth)
      let signcolwidth = 1
    endif
  endif

  let availablewidth = winwidth(0) - &foldcolumn - numberwidth - signcolwidth
  return g:foldpeek#maxwidth > 0
        \ ? min([availablewidth, g:foldpeek#maxwidth])
        \ : availablewidth
endfunction

" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline "{{{1
" vim: expandtab tabstop=2 softtabstop=2 shiftwidth=2
" vim: foldmethod=marker textwidth=78
