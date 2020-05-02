function! foldpeek#default#head() abort
  let hunk_sign = ''
  if foldpeek#git#status().has_diff
    let hunk_sign = '(*) '
  endif

  if v:foldlevel == 1
    return empty(hunk_sign) ? (v:folddashes .' ') : hunk_sign
  endif

  return v:foldlevel .') '. hunk_sign
endfunction

function! foldpeek#default#tail() abort
  let foldlines = v:foldend - v:foldstart + 1
  if g:foldpeek_lnum == 1
    let fold_info = '['. foldlines .']'
  else
    let fold_info = '['. (g:foldpeek_lnum) .'/'. foldlines .']'
  endif

  let git_info = ''
  let git_stat = foldpeek#git#status()
  if git_stat.has_diff
    let git_info = '(+%a ~%m -%r)'
    let git_info = substitute(git_info, '%a', git_stat.Added,    'g')
    let git_info = substitute(git_info, '%m', git_stat.Modified, 'g')
    let git_info = substitute(git_info, '%r', git_stat.Removed,  'g')
  endif

  return ' '. git_info . fold_info
endfunction
