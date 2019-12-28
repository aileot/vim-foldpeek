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

let g:foldpeek#maxwidth        = get(g:, 'foldpeek#maxwidth', 78)
let g:foldpeek#maxspaces       = get(g:, 'foldpeek#maxspaces', &tabstop)
let g:foldpeek#auto_foldcolumn = get(g:, 'foldpeek#auto_foldcolumn', 0)
let g:foldpeek#skip_patterns   = get(g:, 'foldpeek#skip_patterns', [
      \ '^[\-=/{!* ]*$',
      \ ])

let g:foldpeek#head = get(g:, 'foldpeek#head', {
      \ 1: "v:foldlevel > 1 ? v:foldlevel .') ' : v:folddashes "
      \ })
let g:foldpeek#tail = get(g:, 'foldpeek#tail', {
      \ 1: "' ['. (v:foldend - v:foldstart + 1) .']'",
      \ 2: "' [%lnum%/'. (v:foldend - v:foldstart + 1) .']'",
      \ })

function! foldpeek#text() abort "{{{1
  if g:foldpeek#auto_foldcolumn && v:foldlevel > (&foldcolumn - 1)
    let &foldcolumn = v:foldlevel + 1
  endif

  let [body, peeklnum] = s:peekline()
  let [head, tail]     = s:decorations(peeklnum)

  return s:return_text(body, [head, tail])
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
  " Note: only replace cms which is besides foldmarker
  let markers = map(split(&foldmarker, ','),
        \ "'['. cms[0] .' ]*'.  v:val .'\\d*[ '. cms[len(cms) - 1] .']*'")

  for pat in markers
    let ret = substitute(ret, pat, repeat(' ', len(matchstr(ret, pat))), 'g')
  endfor

  "if g:foldpeek#maxspaces >= 0
  "  " FIXME: keep the entire text length
  "  return substitute(ret,
  "        \ repeat('\s', g:foldpeek#maxspaces)  .'\+',
  "        \ repeat(' ',  g:foldpeek#maxspaces), 'g')
  "endif

  return substitute(ret, '\t', repeat(' ', &tabstop), 'g')
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

  for num in sort(keys(head))
    if a:num >= num
      " overrides return value
      let head = eval(exists('b:foldpeek_head')
            \ ? get(b:foldpeek_head, num, g:foldpeek#head[num])
            \ : g:foldpeek#head[num]
            \ )
    endif
  endfor

  for num in sort(keys(tail))
    if a:num >= num
      let tail = eval(exists('b:foldpeek_tail')
            \ ? get(b:foldpeek_tail, num, g:foldpeek#tail[num])
            \ : g:foldpeek#tail[num]
            \ )
    endif
  endfor

  " Note: empty() makes sure head/tail not to show '0'
  let head = empty(head) ? '' : substitute(head, '%lnum%', a:num, 'g')
  let tail = empty(tail) ? '' : substitute(tail, '%lnum%', a:num, 'g')

  "" TODO: bundle head and tail in for-loop
  "for part in ['head', 'tail']
  "exe 'let' part "=
  "      \ get(b:, eval('foldpeek_'. part), eval('g:foldpeek#'. part)
  "      \ )"
  "  for num in sort(keys(part))
  "    if a:num >= num
  "      " overrides return value
  "      exe 'let' part "= eval(exists('b:foldpeek_'. part)
  "            \ ? get(eval('b:foldpeek_'. part), num, eval('g:foldpeek#'. part)[num])
  "            \ : eval('g:foldpeek#'. part)[num]
  "            \ )"
  "    endif
  "  endfor
  "exe 'let' part "= empty(part) ? ''
  "      \ : substitute(part, '%lnum%', a:num, 'g')"
  "endfor

  return [head, tail]
endfunction

function! s:return_text(text, decor) abort "{{{2
  let [head, tail] = a:decor

  let body = s:adjust_bodylen(a:text, strlen(head) + strlen(tail))

  return substitute(body, '^\s*\ze',
        \ (get(g:, 'foldpeek#indent_head', 0) ? '\0'. head : head .'\0'),
        \ '') . tail
endfunction

function! s:adjust_bodylen(body, decor_width) abort "{{{3
  " Note: the replacement of some chars by whitespaces is done in the selection
  "   of peekline.
  let nocolwidth = s:nocolwidth()
  let bodywidth  = nocolwidth - a:decor_width
  " Note: strdisplaywidth() returns up to &tabstop, &display and &ambiwidth
  let displaywidth = strdisplaywidth(a:body)

  if bodywidth < displaywidth
    let [len, ret] = [0, '']
    for char in split(a:body, '\zs')
      let len += strdisplaywidth(char)
      if len > bodywidth | break | endif
      let ret .= char
    endfor
    return strdisplaywidth(ret) == bodywidth ? ret : ret .' '
  endif

  " TODO: show in correct width for multibyte characters
  let lacklen = strlen(a:body) - displaywidth
  let bodywidth += lacklen
  return printf('%-*s', bodywidth, a:body)
endfunction

function! s:nocolwidth() abort "{{{4
  let numberwidth = &number ? max([&numberwidth, len(line('$'))]) : 0
  let signcolwidth = s:signcolwidth()

  " FIXME: when auto_foldcolumn is true, &foldcolumn could be increased later.
  let nocolwidth = winwidth(0) - &foldcolumn - numberwidth - signcolwidth
  return g:foldpeek#maxwidth > 0
        \ ? min([nocolwidth, g:foldpeek#maxwidth])
        \ : nocolwidth
endfunction

function! s:signcolwidth() abort "{{{5
  let signcolwidth = 0

  if &signcolumn =~# 'yes'
    let signcolwidth = matchstr(&signcolumn, '\d')
    return

  elseif &signcolumn !~# 'auto' | return | endif

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
  let g:signlnum = signlnum

  let i = 0
  while i < len(signlnum) - 2
    " stop the loop at the second last in comparison with the first last
    if signlnum[i] == signlnum[i + 1]
      let duptimes = 1
      if duptimes > maxwidth | break | endif

      let duplnum  = signlnum[i]
      let i += 2
      while duplnum  == signlnum[i]
        let duptimes += 1
        let i += 1
      endwhile

      let signcolwidth = max(signcolwidth, duptimes)
    endif
  endwhile
endfunction

" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline "{{{1
" vim: expandtab tabstop=2 softtabstop=2 shiftwidth=2
" vim: foldmethod=marker textwidth=78
