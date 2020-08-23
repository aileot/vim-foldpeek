" save 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

" Helper Functions {{{1
function! s:set_component(gvar) abort
  " i.e., get(b:, 'foo_bar', g:foo#bar)
  return get(b:, substitute(a:gvar, '#', '_', 'ge'), {a:gvar})
endfunction
"}}}1

function! foldpeek#default#head() abort "{{{1
  let sign = ''
  if foldpeek#git#has_diff()
    let sign .= g:foldpeek#default#diff_sign
  endif
  return sign
endfunction

function! foldpeek#default#tail() abort "{{{1
  let foldlines = v:foldend - v:foldstart + 1
  let foldlevel = g:foldpeek#default#foldlevel_signs[v:foldlevel]

  let fold_info = foldlines . foldlevel
  let git_info = ''
  let git_diff = foldpeek#git#get_diff()
  if foldpeek#git#has_diff()
    let git_info = g:foldpeek#default#diff_status_format
    let git_info = substitute(git_info, '%a', git_diff.Added,    '')
    let git_info = substitute(git_info, '%m', git_diff.Modified, '')
    let git_info = substitute(git_info, '%r', git_diff.Removed,  '')
  endif

  let peeked_offset = foldpeek#get_offset()
  if peeked_offset > 0
    let peeked_depth = peeked_offset + 1
    let fold_info = peeked_depth .'/'. fold_info
  endif

  let ret = git_info . fold_info
  " let ret = foldpeek#whiteout#is_applied() ? (ret .'!') : (' '. ret)
  if foldpeek#whiteout#is_applied()
    let ret = '.'. ret
  endif

  return ret
endfunction

" restore 'cpoptions' {{{1
let &cpo = s:save_cpo
unlet s:save_cpo

" modeline {{{1
" vim: et ts=2 sts=2 sw=2 fdm=marker tw=79
