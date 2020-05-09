" Helper Functions {{{1
function! s:update_all_folds() abort
  " Expects to be used for s:caches.is_updating()
  let s:update_pos = v:foldstart
endfunction
"}}}1

function! foldpeek#cache#text() abort "{{{1
  let folds = get(w:, 'foldpeek_folds', {})
  let cache = get(folds, v:foldstart, {})

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
        \ || (v:foldend != a:cache.foldend)
        \ || s:is_updating()
        \ || s:has_git_updated()
    return 1
  endif

  let peeked_lnum = v:foldstart + a:cache.offset
  return s:compare_lines(a:cache, peeked_lnum)
endfunction

function! s:compare_lines(cache, depth) abort "{{{2
  let lnum = v:foldstart
  while lnum <= a:depth
    if getline(lnum) !=# a:cache.lines[lnum]
      return 1
    endif

    let lnum += 1
  endwhile

  return 0
endfunction

function! s:is_updating() abort "{{{2
  if !exists('s:update_pos')
    return 0
  endif

  if v:foldstart <= s:update_pos
    unlet s:update_pos
  endif

  return 1
endfunction

function! s:has_git_updated() abort "{{{2
  if !exists('*foldpeek#git#status()')
        \ || !exists('*GitGutterGetHunkSummary()')
        \ || (GitGutterGetHunkSummary() == get(s:, 'summary', [0, 0, 0]))
    return 0
  endif

  let s:summary = GitGutterGetHunkSummary()
  call s:update_all_folds()

  return 1
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

  let w:foldpeek_folds = get(w:, 'foldpeek_folds', {})
  call extend(w:foldpeek_folds, {v:foldstart : dict})
endfunction
