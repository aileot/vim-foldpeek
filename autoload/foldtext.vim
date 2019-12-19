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

if expand('<sfile>:p') !=# expand('%:p') && exists('g:loaded_foldtext') | finish | endif
let g:loaded_foldtext = 1
" save 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

let g:foldtext#text_maxchars = get(g:, 'foldtext#text_maxchars', 78)
let g:foldtext#text_head = get(g:, 'foldtext#text_head', 'v:folddashes. " "')
let g:foldtext#text_tail = get(g:, 'foldtext#text_tail', 'v:foldend - v:foldstart+1')
let g:foldtext#text_enable_autofdc_adjuster = get(g:, 'foldtext#text_enable_autofdc_adjuster', 0)
let g:foldtext#navi_maxchars = get(g:, 'foldtext#navi_maxchars', 60)

function! foldtext#text() abort "{{{1
  if g:foldtext#text_enable_autofdc_adjuster && v:foldlevel > &fdc-1
    let &fdc = v:foldlevel + 1
  endif
  let headtext = getline(v:foldstart)
  let head = (g:foldtext#text_head == '') ? '' : eval(g:foldtext#text_head)
  let tail = (g:foldtext#text_tail == '') ? '' : ' '. eval(g:foldtext#text_tail)
  let headtext = s:_adjust_headtext(headtext, strlen(head) + strlen(tail) + 1)
  return substitute(headtext, '^\s*\ze', '\0'. head, ''). tail
endfunction
function! s:_remove_commentstring_and_foldmarkers(str) abort "{{{2
  let cms = matchlist(&cms, '\(.\{-}\)%s\(.\{-}\)')
  let [cmsbgn, cmsend] = cms==[] ? ['', ''] : [substitute(cms[1], '\s', '', 'g'), cms[2] ]
  let foldmarkers = split(&foldmarker, ',')
  return substitute(a:str, '\%('.cmsbgn.'\)\?\s*'.foldmarkers[0].'\%(\d\+\)\?\s*\%('.cmsend.'\)\?', '','')
endfunction
function! s:colwidth() abort "{{{2
  return winwidth(0) - &foldcolumn - (!&number ? 0 : max([&numberwidth, len(line('$'))]) ) - 1
endfunction

function! s:_remove_multibyte_garbage(str) abort "{{{2
  return substitute(substitute(strtrans(a:str), '^\%(<\x\x>\)\+\|\%(<\x\x>\)\+$', '', 'g'), '\^I', "\t", 'g')
endfunction

function! s:_adjust_headtext(headtext, reducelen) abort "{{{2
  let headtext = s:_remove_commentstring_and_foldmarkers(a:headtext)
  let colwidth = s:colwidth()
  let truncatelen = ((colwidth < g:foldtext#text_maxchars)? colwidth : g:foldtext#text_maxchars) - a:reducelen
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
  return strdisplaywidth(ret)==truncatelen ? ret : ret.' '
endfunction

function! foldtext#info() abort "{{{1
  let foldheads = s:info_headtexts()
  if empty(foldheads)
    return ' Not inside any fold'
  endif
  return join(foldheads, ' > ')
endfunction

function! s:info_headtexts() abort "{{{2
  if !foldlevel('.')
    return []
  endif
  let view_save = winsaveview()
  let gatherer = s:newFoldGatherer()
  try
    call gatherer.gather_headtexts()
    return gatherer.get_headtexts()
  finally
    call winrestview(view_save)
  endtry
endfunction

"=============================================================================
let s:FoldGatherer = {} "{{{2
function! s:newFoldGatherer() abort "{{{3
  let obj = copy(s:FoldGatherer)
  let obj.headtexts = []
  return obj
endfunction

function! s:FoldGatherer._register_headtext(headtext) abort "{{{3
  let headtext = s:_remove_commentstring_and_foldmarkers(a:headtext)
  let headtext = substitute(substitute(headtext, '^\s*\|\s$', '', 'g'), '\s\+', ' ', 'g')
  let multibyte_widthgap = len(headtext) - strdisplaywidth(headtext)
  let truncatelen = g:foldtext#navi_maxchars + multibyte_widthgap
  let headtext = s:_remove_multibyte_garbage(headtext[:truncatelen])
  call insert(self.headtexts, headtext)
endfunction

function! s:FoldGatherer._gather_outer_headtexts() abort "{{{3
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
      call self._register_headtext(getline('.'))
      if foldlevel('.') == 1
        break
      endif
      let row = line('.')
    endwhile
  catch
    throw 'See: g:foldtext_errmsg'
    let g:foldtext_errmsg = v:exception
  endtry
endfunction

function! s:FoldGatherer.gather_headtexts() abort "{{{3
  let closed_row = foldclosed('.')

  if closed_row == -1
    call self._gather_outer_headtexts()
    return
  endif

  call self._register_headtext(getline(closed_row))

  if foldlevel('.') == 1 | return | endif

  keepj norm! [z

  if foldclosed('.') == closed_row | return | endif

  call self._gather_outer_headtexts()
  return
endfunction

function! s:FoldGatherer.get_headtexts() abort "{{{3
  return self.headtexts
endfunction

" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline "{{{1
" vim: ts=2 sts=2 sw=2 et fdm=marker
