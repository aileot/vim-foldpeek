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
function! s:set_default(var, default) abort "{{{2
  let prefix = matchstr(a:var, '^\w:')
  let suffix = substitute(a:var, prefix, '', '')
  if empty(prefix) || prefix ==# 'l:'
    throw 'l:var is unsupported'
  endif

  let {a:var} = get({prefix}, suffix, a:default)
endfunction

" Initialze Global Variables {{{1
call s:set_default('g:foldpeek#maxspaces', &shiftwidth)
call s:set_default('g:foldpeek#auto_foldcolumn', 0)
call s:set_default('g:foldpeek#maxwidth','&textwidth > 0 ? &tw : 79')
call s:set_default('g:foldpeek#cache#disable', 0)

call s:set_default('g:foldpeek#head', 'foldpeek#default#head()')
call s:set_default('g:foldpeek#tail', 'foldpeek#default#tail()')
call s:set_default('g:foldpeek#table', {}) " deprecated
call s:set_default('g:foldpeek#indent_with_head', 0)
call s:set_default('g:foldpeek#skip#patterns', [
      \ '^[>#\-=/{!* \t]*$',
      \ ])
call s:set_default('g:foldpeek#skip#override_patterns', 0)

call s:set_default('g:foldpeek#whiteout#patterns', {
      \ 'substitute': [
      \   ['{\s*$', '{...}', ''],
      \   ['[\s*$', '[...]', ''],
      \   ['(\s*$', '(...)', ''],
      \   ],
      \ })
call s:set_default('g:foldpeek#whiteout#disabled_styles', [])
call s:set_default('g:foldpeek#whiteout#overrided_styles', [])
call s:set_default('g:foldpeek#whiteout#style_for_foldmarker', 'omit')

function! foldpeek#status() abort "{{{1
  return {
        \ 'lnum': s:lnum,
        \ 'offset': s:offset,
        \ }
endfunction

function! foldpeek#text() abort "{{{1
  if !g:foldpeek#cache#disable
    let ret = foldpeek#cache#text(v:foldstart)
    if !empty(ret)
      return ret
    endif
  endif

  if g:foldpeek#auto_foldcolumn && v:foldlevel > (&foldcolumn - 1)
    let &foldcolumn = v:foldlevel + 1
  endif

  let body = s:peekline()
  let [head, tail] = s:decorations()

  let ret = !empty(s:deprecation_notice())
        \ ? s:deprecation_notice()
        \ : s:return_text(head, body, tail)

  if !g:foldpeek#cache#disable
    call foldpeek#cache#update(ret, s:offset)
  endif

  return ret
endfunction

function! s:peekline() abort "{{{2
  let offset = 0
  while offset <= (v:foldend - v:foldstart)
    let line = getline(v:foldstart + offset)

    if string(get(b:, 'foldpeek_whiteout_disabled_styles',
          \ g:foldpeek#whiteout#disabled_styles)) !~# 'ALL'
      " Profile: s:whiteout_at_patterns() is a bottle-neck according to
      "   `:profile`
      let line = foldpeek#whiteout#at_patterns(line)
    endif

    if !s:has_skip_patterns(line)
      let s:offset = offset
      let s:lnum = offset + 1
      return line
    endif

    let offset += 1
  endwhile

  let s:lnum = 1
  return getline(v:foldstart)
endfunction

function! s:has_skip_patterns(line) abort "{{{3
  if get(b:, 'foldpeek_skip_override_patterns',
        \ g:foldpeek#skip#override_patterns)
    let patterns = get(b:, 'foldpeek_skip_patterns', g:foldpeek#skip#patterns)
  else
    let patterns = get(b:, 'foldpeek_skip_patterns', [])
          \ + g:foldpeek#skip#patterns
  endif

  for pat in patterns
    if a:line =~# pat | return 1 | endif
  endfor
  return 0
endfunction

function! s:decorations() abort "{{{2
  let head = get(b:, 'foldpeek_head', g:foldpeek#head)
  let tail = get(b:, 'foldpeek_tail', g:foldpeek#tail)

  for num in keys(head)
    if s:lnum >= num
      let head = exists('b:foldpeek_head')
            \ ? b:foldpeek_head[num]
            \ : g:foldpeek#head[num]
    endif
  endfor

  for num in keys(tail)
    if s:lnum >= num
      let tail = exists('b:foldpeek_tail')
            \ ? b:foldpeek_tail[num]
            \ : g:foldpeek#tail[num]
    endif
  endfor

  let head = s:substitute_as_table(head) " deprecated
  let tail = s:substitute_as_table(tail) " deprecated
  let head = substitute(head, '%PEEK%', g:_foldpeek_lnum, 'g') " deprecated
  let tail = substitute(tail, '%PEEK%', g:_foldpeek_lnum, 'g') " deprecated

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

function! s:deprecation_notice() abort "{{{2
  let msg = 'Deprecated: '
  let msg_len = len(msg)

  let whiteout_styles = ['omit', 'fill']
  for style in whiteout_styles
    if exists({'b:foldpeek_whiteout_patterns_'. style})
      let msg .= {'b:foldpeek_whiteout_patterns_'. style}
            \ .' please use b:foldpeek_whiteout_patterns instead; '
    elseif exists({'g:foldpeek#whiteout_patterns_'. style})
      let msg .= {'g:foldpeek#whiteout_patterns_'. style}
            \ .' please use g:foldpeek#whiteout#patterns instead; '
    endif
  endfor

  if exists('g:foldpeek#whiteout_style_for_foldmarker')
    let msg .= 'g:foldpeek#whiteout_style_for_foldmarker'
          \ .' please use g:foldpeek#whiteout#style_for_foldmarker instead;'
  endif

  for part in ['head', 'tail']
    if type(get(b:, 'foldpeek_'. part)) == type({})
      let msg .= 'b:foldpeek_'. part .' in Dict; '
    elseif type({'g:foldpeek#'. part}) == type({})
      let msg .= 'g:foldpeek#'. part .' in Dict; '
    endif
    let str = get(b:, 'foldpeek_'. part, {'g:foldpeek#'. part})
    if !empty(matchstr(str, '%PEEK%'))
      let msg .= '%PEEK% please use g:foldpeek_lnum instead;'
    endif
  endfor

  if !empty(g:foldpeek#table)
    let msg .= 'g:foldpeek#table; '
  endif

  return msg_len == len(msg)
        \ ? ''
        \ : msg .'`:h foldpeek-compatibility` for more detail'
endfunction
" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline "{{{1
" vim: expandtab tabstop=2 softtabstop=2 shiftwidth=2
" vim: foldmethod=marker textwidth=79
