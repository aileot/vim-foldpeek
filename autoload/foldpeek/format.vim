" ============================================================================
" Repo: kaile256/vim-foldpeek
" File: autoload/foldpeek/format.vim
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

" save 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}1

let g:foldpeek#format#table = get(g:, 'foldpeek#format#table', {})

function! foldpeek#format#substitute(line) abort "{{{1
  let dict = g:foldpeek#format#table

  if empty(a:line)
    return ''
  elseif empty(dict)
    return a:line
  endif

  let ret = a:line
  for l:key in sort(keys(dict), 'N')
    try
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

" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline {{{1
" vim: expandtab tabstop=2 softtabstop=2 shiftwidth=2
" vim: foldmethod=marker textwidth=79
