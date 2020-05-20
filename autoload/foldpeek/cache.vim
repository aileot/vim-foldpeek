" Helper Functions {{{1
function! s:update_all_folds() abort
  " Expects to be used for s:caches.is_updating()
  let s:update_pos = v:foldstart
endfunction
"}}}1

function! foldpeek#cache#text(lnum) abort "{{{1
  let s:foldstart = foldclosed(a:lnum)
  let s:foldend = foldclosedend(a:lnum)

  let folds = get(w:, 'foldpeek_folds', {})
  let cache = get(folds, s:foldstart, {})

  if s:has_cache(cache) && !s:has_changed(cache)
    let folds = s:refresh_caches(folds)
    return cache.return
  endif
endfunction

function! s:has_cache(cache) abort "{{{2
  let ret = get(a:cache, 'return')
  return !empty(ret)
endfunction

function! s:has_changed(cache) abort "{{{2
  if s:foldend != a:cache.foldend
    return 1
  elseif s:is_updating()
    return s:compare_lines(a:cache, s:foldend)
  elseif s:has_git_updated()
    return 1
  endif

  let peeked_lnum = s:foldstart + a:cache.offset
  return s:compare_lines(a:cache, peeked_lnum)
endfunction

function! s:compare_lines(cache, depth) abort "{{{3
  let lnum = s:foldstart
  while lnum <= a:depth
    if getline(lnum) !=# a:cache.lines[lnum]
      return 1
    endif

    let lnum += 1
  endwhile

  return 0
endfunction

function! s:is_updating() abort "{{{3
  if !exists('s:update_pos')
    return 0
  endif

  if s:foldstart <= s:update_pos
    unlet s:update_pos
  endif

  return 1
endfunction

function! s:has_git_updated() abort "{{{3
  " TODO: Pick up a fold which contains any change to update.
  if !exists('g:autoloaded_foldpeek_git')
        \ || !exists('*GitGutterGetHunkSummary()')
        \ || (GitGutterGetHunkSummary()
        \   == get(w:, 'foldpeek_git_summary', [0, 0, 0]))
    return 0
  endif

  let w:foldpeek_git_summary = GitGutterGetHunkSummary()
  call s:update_all_folds()

  return 1
endfunction

function! s:refresh_caches(folds) abort "{{{2
  return filter(a:folds,
        \ 'foldclosed(v:key) == v:key'
        \ .' && v:key >= line("w0")'
        \ .' && v:key <= line("w$")'
        \ )
endfunction

function! foldpeek#cache#update(text, offset) abort "{{{1
  " Extends a key, v:foldstart, with dict as {v:foldstart : dict}
  let dict = {
        \ 'return': a:text,
        \ 'offset': a:offset,
        \ 'foldstart': v:foldstart,
        \ 'foldend': v:foldend,
        \ 'lines': {},
        \ }

  let lnum = v:foldstart
  while lnum <= v:foldend
    " {v:foldstart     : getline(v:foldstart)    },
    " {v:foldstart + 1 : getline(v:foldstart + 1)},
    " ...
    " {v:foldstart + a:offset : getline(v:foldstart + a:offset)}
    call extend(dict.lines, {lnum : getline(lnum)})
    let lnum += 1
  endwhile

  let w:foldpeek_folds = get(w:, 'foldpeek_folds', {})
  call extend(w:foldpeek_folds, {v:foldstart : dict})
endfunction
