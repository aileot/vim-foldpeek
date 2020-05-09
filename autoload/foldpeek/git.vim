function! foldpeek#git#status() abort "{{{1
  call s:set_git_stat_as_signs()
  return s:git_stat
endfunction

function! s:set_git_stat_as_signs() abort "{{{2
  let git_stat = s:reset_git_stat()
  let sign_name = git_stat.sign_name
  let signs = s:get_signs()

  for sign in signs
    if sign.name !~# sign_name | continue | endif
    if v:foldstart > sign.lnum || sign.lnum > v:foldend
      continue
    endif

    " Otherwise, 1 is only added no matter how many lines were removed.
    let git_stat.Removed = s:complete_stat_at_removed()

    for l:key in keys(git_stat)
      " e.g., git_stat['sign_name'] ==# 'GitGutterLine'
      if l:key ==# 'sign_name' | continue | endif
      if !git_stat.has_diff
        let git_stat.has_diff = (sign.name =~# l:key)
      endif
      " e.g., git_stat['Added'] += ('GitGutterLineAdded' =~# 'Added')
      if sign.name =~# 'Modified'
        " Take care of combined named signs like 'GitGutterLineModifiedRemoved'
        let git_stat[l:key] += l:key =~# 'Modified'
      elseif sign.name =~# 'Added'
        let git_stat[l:key] += sign.name =~# l:key
      endif
    endfor
  endfor

  return git_stat
endfunction

function! s:reset_git_stat() abort "{{{2
  " get signs by getbufinfo(bufnr('%'))[0].signs
  let dict = {'sign_name': 'NONE', 'has_diff': 0,
        \ 'Added': 0, 'Modified': 0, 'Removed': 0}
  if exists('b:gitgutter')
    call extend(dict, {'sign_name': 'GitGutterLine'})
  endif
  return dict
endfunction

function! s:get_signs() abort "{{{2
  " This function is extracted from https://raw.githubusercontent.com/airblade/vim-gitgutter/f411d8680e57f64a4de03ae1f82186ff18396344/autoload/gitgutter/sign.vim @ 108
  let bufnr = bufnr('%')
  if exists('*getbufinfo')
    let bufinfo = getbufinfo(bufnr)[0]
    let signs = has_key(bufinfo, 'signs') ? bufinfo.signs : []

  else
    let signs = []

    redir => signlines
    silent execute 'sign place buffer='. bufnr
    redir END

    for signline in filter(split(signlines, '\n')[2:], 'v:val =~# "="')
      " We assume splitting is faster than a regexp.
      let components = split(signline)
      call add(signs, {
            \ 'lnum': str2nr(split(components[0], '=')[1]),
            \ 'id':   str2nr(split(components[1], '=')[1]),
            \ 'name':        split(components[2], '=')[1]
            \ })
    endfor
  endif
  return signs
endfunction

function! s:complete_stat_at_removed() abort "{{{2
  " Note:
  " The format of b:gitgutter is a list of
  "       [lnum_before, removed, lnum, added]
  " e.g., [[9, 0, 10, 4], [11, 1, 15, 1], [14, 2, 18, 2], [21, 1, 25, 3]]

  let Removed = 0
  let hunks = b:gitgutter.hunks
  for hunk_info in hunks
    if hunk_info[2] < v:foldstart || hunk_info[2] > v:foldend
      continue
    endif
    let removed = hunk_info[1]
    let added   = hunk_info[3]
    let diff = removed - added
    if diff > 0
      let Removed += diff
    endif
  endfor

  return Removed
endfunction
