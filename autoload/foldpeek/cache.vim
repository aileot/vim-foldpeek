let s:cache = {}

" Helper Functions {{{1
function! s:update_all_folds() abort
  " Expects to be used for s:is_cache_updating()
  let s:update_pos = v:foldstart
endfunction
"}}}1

function! foldpeek#cache#text(lnum) abort "{{{1
  let s:foldstart = foldclosed(a:lnum)
  let s:foldend = foldclosedend(a:lnum)

  return s:cache.return()
endfunction

function! s:cache.return() abort  "{{{2
  if !exists('w:foldpeek_folds')
    let w:foldpeek_folds = {}
  endif
  let self.folds = w:foldpeek_folds
  let self.tracking_fold = get(w:foldpeek_folds, s:foldstart, {})

  if self.is_available()
    call self.refresh()
    return self.tracking_fold.return
  endif

  return {}
endfunction

function! s:cache.is_available() abort  "{{{2
  return self.is_saved()
        \ && !self.has_text_changed()
endfunction

function! s:cache.is_saved() abort  "{{{2
  let ret = get(self.tracking_fold, 'return')
  return !empty(ret)
endfunction

function! s:cache.has_text_changed() abort  "{{{2
  if s:foldend != self.tracking_fold.foldend
    return 1

  elseif self.is_updating()
    " FIXME: Use the other logic below after the problem is fixed that folds
    " with git-diff status often fails to appear at first fold update to be in
    " cache.
    "
    " return len(a:cache.lines) < (s:foldend - s:foldstart)
    "      \ ? s:compare_lines(a:cache, s:foldend)
    "      \ : 1

    return 1

  elseif self.compare_lines()
    return 1
  endif

  return s:has_git_updated()
endfunction

function! s:cache.compare_lines() abort  "{{{2
  let offset = 0
  let max = self.tracking_fold.offset
  let cached_lines = self.tracking_fold.lines
  while offset <= max
    let lnum = s:foldstart + offset
    if getline(lnum) !=# cached_lines[offset]
      return 1
    endif

    let offset += 1
  endwhile

  return 0
endfunction

function! s:cache.is_updating() abort "{{{2
  " Use it with s:update_all_folds(); this function should be only for test.

  if !exists('s:update_pos')
    return 0
  endif

  if s:foldstart <= s:update_pos
    unlet s:update_pos
  endif

  return 1
endfunction

function! s:has_git_updated() abort "{{{2
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

function! s:cache.refresh() abort "{{{2
  return filter(self.folds,
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
        \ 'lines': [],
        \ }

  let lnum = v:foldstart
  let max_lnum = g:foldpeek#cache#max_saved_offset < (v:foldend - v:foldstart)
       \ ? v:foldstart + g:foldpeek#cache#max_saved_offset
       \ : v:foldend
  while lnum <= max_lnum
    call add(dict.lines, getline(lnum))
    let lnum += 1
  endwhile

  let w:foldpeek_folds = get(w:, 'foldpeek_folds', {})
  call extend(w:foldpeek_folds, {v:foldstart : dict})
endfunction
