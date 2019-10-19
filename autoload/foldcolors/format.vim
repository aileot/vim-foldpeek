" ============================================================================
" File: autoload/foldcolors/format.vim
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

if expand('<sfile>:p') !=# expand('%:p') && exists('g:loaded_foldcolors') | finish | endif
let g:loaded_foldcolors = 1
" save 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

scriptencoding utf-8
"=============================================================================
let g:foldcolors_text_maxchars = get(g:, 'foldcolors_text_maxchars', 78)
let g:foldcolors_text_head = get(g:, 'foldcolors_text_head', 'v:folddashes. " "')
let g:foldcolors_text_tail = get(g:, 'foldcolors_text_tail', 'v:foldend - v:foldstart+1')
let g:foldcolors_text_enable_autofdc_adjuster = get(g:, 'foldcolors_text_enable_autofdc_adjuster', 0)
let g:foldcolors_navi_maxchars = get(g:, 'foldcolors_navi_maxchars', 60)


"=============================================================================
"Main:
function! foldcolors#format#text() "{{{
  if g:foldcolors_text_enable_autofdc_adjuster && v:foldlevel > &fdc-1
    let &fdc = v:foldlevel + 1
  endif
  let headline = getline(v:foldstart)
  let head = (g:foldcolors_text_head == '') ? '' : eval(g:foldcolors_text_head)
  let tail = (g:foldcolors_text_tail == '') ? '' : ' '. eval(g:foldcolors_text_tail)
  let headline = s:_adjust_headline(headline, strlen(head) + strlen(tail) )
  return substitute(headline, '^\s*\ze', '\0'. head, ''). tail
endfunction "}}}

function! foldcolors#format#info() "{{{
  let foldheads = s:info_headlines()
  if empty(foldheads)
    return ''
  endif
  return join(foldheads, ' > ')
endfunction "}}}

function! s:info_headlines() "{{{
  if !foldlevel('.')
    return []
  endif
  let view = winsaveview()
  let gatherer = s:newFoldGatherer()
  try
    call gatherer.gather_headlines()
    return gatherer.get_headlines()
  finally
    call winrestview(view)
  endtry
endfunction "}}}

"=============================================================================
"Misc:
function! s:_remove_commentstring_and_foldmarkers(str) "{{{
  let cms = matchlist(&cms, '\(.\{-}\)%s\(.\{-}\)')
  let [cmsbgn, cmsend] = cms==[] ? ['', ''] : [substitute(cms[1], '\s', '', 'g'), cms[2] ]
  let foldmarkers = split(&foldmarker, ',')
  return substitute(a:str, '\%('.cmsbgn.'\)\?\s*'.foldmarkers[0].'\%(\d\+\)\?\s*\%('.cmsend.'\)\?', '','')
endfunction "}}}
function! s:colwidth() "{{{
  return winwidth(0) - &foldcolumn - (!&number ? 0 : max([&numberwidth, len(line('$'))]) ) - 1
endfunction
"}}}
function! s:_remove_multibyte_garbage(str) "{{{
  return substitute(substitute(strtrans(a:str), '^\%(<\x\x>\)\+\|\%(<\x\x>\)\+$', '', 'g'), '\^I', "\t", 'g')
endfunction
"}}}
function! s:_adjust_headline(headline, reducelen) "{{{
  let headline = s:_remove_commentstring_and_foldmarkers(a:headline)
  let colwidth = s:colwidth()
  let truncatelen = (colwidth < g:foldcolors_text_maxchars ? colwidth : g:foldcolors_text_maxchars) - a:reducelen
  let dispwidth = strdisplaywidth(headline)
  if dispwidth < truncatelen
    let multibyte_widthgap = strlen(headline) - dispwidth
    let headlinewidth = truncatelen + multibyte_widthgap
    return printf('%-*s', headlinewidth, headline)
  end
  let ret = ''
  let len = 0
  for char in split(headline, '\zs')
    let len += strdisplaywidth(char)
    if len > truncatelen
      break
    end
    let ret .= char
  endfor
  return strdisplaywidth(ret)==truncatelen ? ret : ret.' '
endfunction
"}}}

let s:FoldGatherer = {}
function! s:newFoldGatherer() "{{{
  let obj = copy(s:FoldGatherer)
  let obj.headlines = []
  return obj
endfunction
"}}}
function! s:FoldGatherer._register_headline(headline) "{{{
  let headline = s:_remove_commentstring_and_foldmarkers(a:headline)
  let headline = substitute(substitute(headline, '^\s*\|\s$', '', 'g'), '\s\+', ' ', 'g')
  let multibyte_widthgap = len(headline) - strdisplaywidth(headline)
  let truncatelen = g:foldcolors_navi_maxchars + multibyte_widthgap
  let headline = s:_remove_multibyte_garbage(headline[:truncatelen])
  call insert(self.headlines, headline)
endfunction
"}}}
function! s:FoldGatherer._gather_outer_headlines() "{{{
  if mode() =~ '[sS]' "FIXME: ad hoc for E523 on :norm! in selectmode.
    return
  endif
  let row = 0
  try
    while 1
      keepj normal! [z
      if row == line('.')
        "FIXME: ad hoc for endless loop when multi foldmarkers are in the same line.
        break
      endif
      call self._register_headline(getline('.'))
      if foldlevel('.') == 1
        break
      endif
      let row = line('.')
    endwhile
  catch
    throw 'See: g:foldcolors_err'
    let g:foldcolors__err = v:exception
  endtry
endfunction
"}}}
function! s:FoldGatherer.gather_headlines() "{{{
  let closed_row = foldclosed('.')
  if closed_row == -1
    call self._gather_outer_headlines()
    return
  endif
  call self._register_headline(getline(closed_row))
  if foldlevel('.') == 1
    return
  endif
  "閉じた折り畳みの中の、途中の行にいた場合
  keepj normal! [z
  if foldclosed('.') == closed_row
    return
  endif
  call self._gather_outer_headlines()
  return
endfunction
"}}}
function! s:FoldGatherer.get_headlines() "{{{
  return self.headlines
endfunction
"}}}

"=============================================================================
" restore 'cpoptions' {{{
let &cpo = s:save_cpo
unlet s:save_cpo
"}}}
" vim: ts=2 sts=2 sw=2 et fdm=marker
