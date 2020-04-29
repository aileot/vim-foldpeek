function! s:reset_hunk_info() abort
  if exists('g:loaded_gitgutter')
    return {'sign_name': 'GitGutterLine',
          \ 'Added': 0, 'Modified': 0, 'Removed': 0}
  endif
  return {}
endfunction

function! foldpeek#git#has_any_hunks() abort "{{{1
  return foldpeek#git#hunk_info() != s:reset_hunk_info()
endfunction

function! foldpeek#git#hunk_info() abort "{{{1
  let hunk_info = s:reset_hunk_info()
  let sign_name = hunk_info.sign_name
  let signs = s:get_signs()

  for sign in signs
    if sign.name !~# sign_name | continue | endif
    if v:foldstart > sign.lnum || sign.lnum > v:foldend
      continue
    endif

    for l:key in keys(hunk_info)
      " e.g., hunk_info['sign_name'] ==# 'GitGutterLine'
      if l:key ==# 'sign_name' | continue | endif
      " Make sure to count it uniquely with sign_name for any unexpected
      " failures.
      " e.g.,
      " hunk_info['Added'] += ('GitGutterLineAdded' =~# 'GitGutterLineAdded')
      let hunk_info[l:key] += (sign.name =~# sign_name . l:key)
    endfor
  endfor

  return hunk_info
endfunction

function! s:get_signs() abort "{{{2
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
      " Typical sign line before v8.1.0614:  line=88 id=1234 name=GitGutterLineAdded
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

