let s:caches = {}

function! foldpeek#cache#text() abort "{{{1
  let cache = get(s:caches, v:foldstart, {})
  if !s:has_cache(cache) || !s:has_changed(cache)
    return cache.return
  endif
endfunction

function! s:has_cache(cache) abort "{{{2
  let ret = get(a:cache, 'return')
  return !empty(ret)
endfunction

function! s:has_changed(cache) abort "{{{2
  if g:foldpeek#cache#disable
        \ || (v:foldend != a:cache.foldend)
    return 1
  endif

  if exists('*foldpeek#git#status')
    " TODO: update as git's status, too
  endif

  let lnum = v:foldstart
  let peeked_lnum = v:foldstart + a:cache.offset
  while lnum <= peeked_lnum
    if getline(lnum) !=# a:cache.lines[lnum]
      return 1
    endif
    let lnum += 1
  endwhile

  return 0
endfunction

function! foldpeek#cache#update(text, offset) abort "{{{1
  " Extends a key, v:foldstart, with dict as {v:foldstart : dict}
  let dict = {
        \ 'return':  a:text,
        \ 'offset':  a:offset,
        \ 'foldend': v:foldend,
        \ 'lines':   {},
        \ }

  let lnum = v:foldstart
  while lnum <= (v:foldstart + a:offset)
    " {v:foldstart     : getline(v:foldstart)    },
    " {v:foldstart + 1 : getline(v:foldstart + 1)},
    " ...
    " {v:foldstart + s:offset : getline(v:foldstart + a:offset)}
    call extend(dict.lines, {lnum : getline(lnum)})
    let lnum += 1
  endwhile

  call extend(s:caches, {v:foldstart : dict})
endfunction
