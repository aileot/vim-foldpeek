let s:caches = {
      \ 'return': '',
      \ 'offset': 0,
      \ 'foldend': 0,
      \ 'lines': {},
      \ 'summary': [0, 0, 0],
      \ }

" Helper Functions {{{1
function! s:caches.update_all_folds() abort
  " Expects to be used for s:caches.is_updating()
  let s:caches.update_pos = v:foldstart
endfunction
"}}}1

function! foldpeek#cache#text() abort "{{{1
  let cache = get(s:caches, v:foldstart, {})

  if s:has_cache(cache) && !s:has_changed(cache)
    return cache.return
  endif
endfunction

function! s:has_cache(cache) abort "{{{2
  let ret = get(a:cache, 'return')
  return !empty(ret)
endfunction

function! s:has_changed(cache) abort "{{{2
  if g:foldpeek#cache#disable
        \ || s:caches.is_updating()
        \ || s:has_git_updated()
        \ || (v:foldend != a:cache.foldend)
    return 1
  endif

  let peeked_lnum = v:foldstart + a:cache.offset
  return s:compare_lines(a:cache, peeked_lnum)
endfunction

function! s:caches.is_updating() abort "{{{3
  if !exists('s:caches.update_pos')
    return 0
  endif

  if v:foldstart <= s:caches.update_pos
    unlet s:caches.update_pos
  endif

  return 1
endfunction

function! s:has_git_updated() abort "{{{3
  if !exists('*foldpeek#git#status()')
        \ || !exists('*GitGutterGetHunkSummary()')
        \ || (GitGutterGetHunkSummary() == s:caches.summary)
    return 0
  endif

  let s:caches.summary = GitGutterGetHunkSummary()
  call s:caches.update_all_folds()

  return 1
endfunction

function! s:compare_lines(cache, depth) abort "{{{3
  let lnum = v:foldstart
  while lnum <= a:depth
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
