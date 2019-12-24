" ============================================================================
" File: autoload/foldtext.vim
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

if v:version < 700 | finish | endif

if exists('g:loaded_foldtext') | finish | endif
let g:loaded_foldtext = 1
" save 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

let g:foldtext#maxchars        = get(g:, 'foldtext#maxchars', 78)
let g:foldtext#auto_foldcolumn = get(g:, 'foldtext#auto_foldcolumn', 0)

let g:foldtext#head = get(g:, 'foldtext#head',
      \ "v:foldlevel > 1 ? v:foldlevel .') ' : v:folddashes ")
let g:foldtext#tail = get(g:, 'foldtext#tail',
      \ "' [%lnum%/'. (v:foldend - v:foldstart + 1) .']'")

let g:foldtext#head_in_indent = get(g:, 'foldtext#head_in_indent', 0)
let g:foldtext#nextline_chars = get(g:, 'foldtext#nextline_chars', '=#/{')

function! foldtext#text() abort "{{{1
  if g:foldtext#auto_foldcolumn && v:foldlevel > (&fdc - 1)
    let &fdc = v:foldlevel + 1
  endif

  let [shown_text, shown_lnum] = s:shown_line()

  let head = get(b:, 'foldtext_head', eval(g:foldtext#head))
  let tail = get(b:, 'foldtext_tail', eval(g:foldtext#tail))

  " Note: makes sure head/tail not to show '0'
  let head = empty(head) ? '' : substitute(head, '%lnum%', shown_lnum, 'g')
  let tail = empty(tail) ? '' : substitute(tail, '%lnum%', shown_lnum, 'g')

  let shown_text = s:adjust_textlen(shown_text, strlen(head) + strlen(tail) + 1)

  " TODO: virtually replace indent with `head`
  " Note: keep indent before `head`
  return substitute(shown_text, '^\s*\ze', '\0'. head, '') . tail
endfunction

function! s:shown_line() abort "{{{2
  let add = 0
  let line  = getline(v:foldstart)
  " Note: insert whitespace here for `pattern`
  let cms = substitute(&commentstring, '%s', ' ', '')

  while add <= (v:foldend - v:foldstart)
    let chars = cms . g:foldtext#nextline_chars
    let pattern = '^['. chars .'\t\\]*$'
    " Note: in [], `\s` only indicates a backslash and a 'literal s'
    " Note: have to use regexp (un)matches with [] between `^` and `$`
    if line !~# pattern | return [line, add + 1] | endif

    let add += 1
    let line   = getline(v:foldstart + add)
  endwhile

  return [getline(v:foldstart), 1]
endfunction

function! s:adjust_textlen(headtext, reducelen) abort "{{{2
  let headtext = s:remove_cms_and_fdm(a:headtext)
  let colwidth = s:colwidth()
  let truncatelen = ((colwidth < g:foldtext#maxchars) ? colwidth : g:foldtext#maxchars) - a:reducelen
  let dispwidth = strdisplaywidth(headtext)
  if dispwidth < truncatelen
    let multibyte_widthgap = strlen(headtext) - dispwidth
    let headtextwidth = truncatelen + multibyte_widthgap
    return printf('%-*s', headtextwidth, headtext)
  end
  let ret = ''
  let len = 0
  for char in split(headtext, '\zs')
    let len += strdisplaywidth(char)
    if len > truncatelen
      break
    end
    let ret .= char
  endfor
  return (strdisplaywidth(ret) == truncatelen) ? ret : ret .' '
endfunction

function! s:remove_cms_and_fdm(str) abort "{{{2
  let cms = matchlist(&commentstring, '\(.\{-}\)%s\(.\{-}\)')
  let [cmsbgn, cmsend] = (cms == [] )? ['', ''] : [substitute(cms[1], '\s', '', 'g'), cms[2] ]
  let fdm = split(&foldmarker, ',')
  return substitute(a:str, '\%('. cmsbgn .'\)\?\s*'. fdm[0] .'\%(\d\+\)\?\s*\%('. cmsend .'\)\?', '','')
endfunction

function! s:colwidth() abort "{{{2
  return winwidth(0) - &foldcolumn - (!&number ? 0 : max([&numberwidth, len(line('$'))]) ) - 1
endfunction

" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline "{{{1
" vim: ts=2 sts=2 sw=2 et fdm=marker
