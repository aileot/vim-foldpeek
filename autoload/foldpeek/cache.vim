let s:cache = {}

" Helper Functions {{{1
let s:update_all_folds = {} "{{{2

function! s:update_all_folds.prepare() abort
  " Expects to be used for s:is_cache_updating()
  let self.start_point = v:foldstart
endfunction

function! s:update_all_folds.in_progress() abort
  " Use it with self.prepare(); this function is preferable to be used only for test.

  if !exists('s:update_all_folds.start_point')
    return 0
  endif

  if s:foldstart <= self.start_point
    unlet self.start_point
  endif

  return 1
endfunction

let s:textwidth = {} "{{{2
function! s:textwidth.is_changed() abort "{{{3
  " TODO: Also detect either signcolumn or foldcolumn changes; if that's
  " difficult, rewrite foldpeek#cache#update() to cache on 'head', 'body' and
  " 'tail' than on 'foldtext'.

  if self.has_winwidth_changed()
    call s:update_all_folds.prepare()
    return 1
  endif

  return 0
endfunction

function! s:textwidth.has_winwidth_changed() abort "{{{3
  let winwidth = winwidth(0)

  if winwidth < g:foldpeek#maxwidth && !exists('w:foldpeek_winwidth')
    let w:foldpeek_winwidth = winwidth
    return 1
  endif

  if exists('w:foldpeek_winwidth') && winwidth != w:foldpeek_winwidth
    unlet w:foldpeek_winwidth
    call s:update_all_folds.prepare()
  endif

  return 0
endfunction

let s:text_diff = {} "{{{2
function! s:text_diff.has_changed() abort  "{{{3
  if s:foldend != s:cache.tracking_fold.foldend
    return 1

  elseif self.compare_lines()
    return 1
  endif

  return self.has_git_updated()
endfunction

function! s:text_diff.compare_lines() abort  "{{{3
  let offset = 0
  let max = s:cache.tracking_fold.offset
  let cached_lines = s:cache.tracking_fold.lines
  while offset <= max
    let lnum = s:foldstart + offset
    if getline(lnum) !=# cached_lines[offset]
      return 1
    endif

    let offset += 1
  endwhile

  return 0
endfunction

function! s:text_diff.has_git_updated() abort "{{{3
  " TODO: Accept other diff-management plugins like coc-git, vim-signify.
  " The src should be managed in autoload/foldpeek/git.vim.
  if !exists('g:autoloaded_foldpeek_git')
        \ || !exists('*GitGutterGetHunkSummary()')
        \ || (GitGutterGetHunkSummary()
        \   == get(w:, 'foldpeek_git_summary', [0, 0, 0]))
    return 0
  endif

  let w:foldpeek_git_summary = GitGutterGetHunkSummary()
  call s:update_all_folds.prepare()

  return 1
endfunction
"}}}1

function! foldpeek#cache#text(lnum) abort "{{{1
  let s:foldstart = foldclosed(a:lnum)
  let s:foldend = foldclosedend(a:lnum)

  return s:cache.return()
endfunction

function! s:cache.return() abort  "{{{2
  let self.folds = w:foldpeek_folds
  let self.tracking_fold = get(self.folds, s:foldstart, {})

  if self.is_available()
    call self.refresh()
    return self.tracking_fold.return
  endif

  return {}
endfunction

function! s:cache.is_available() abort  "{{{2
  return self.is_saved()
        \ && !s:update_all_folds.in_progress()
        \ && !s:textwidth.is_changed()
        \ && !s:text_diff.has_changed()
endfunction

function! s:cache.is_saved() abort  "{{{2
  let ret = get(self.tracking_fold, 'return')
  return !empty(ret)
endfunction

function! s:cache.refresh() abort "{{{2
  return filter(self.folds,
        \ 'foldclosed(v:key) == v:key'
        \ .' && v:key >= line("w0")'
        \ .' && v:key <= line("w$")'
        \ )
endfunction

function! foldpeek#cache#update(dict) abort "{{{1
  " Extends a key, s:foldstart, with dict as {s:foldstart : dict}

  let dict = {
        \ 'return': a:dict.foldtext,
        \ 'offset': a:dict.offset,
        \ 'foldstart': v:foldstart,
        \ 'foldend': v:foldend,
        \ 'lines': [],
        \ }

  let lnum = v:foldstart
  " let max_lnum = g:foldpeek#cache#max_saved_offset < (v:foldend - v:foldstart)
  "      \ ? v:foldstart + g:foldpeek#cache#max_saved_offset
  "      \ : v:foldend
  let max_lnum = lnum + a:dict.offset
  while lnum <= max_lnum
    call add(dict.lines, getline(lnum))
    let lnum += 1
  endwhile

  let w:foldpeek_folds = get(w:, 'foldpeek_folds', {})
  call extend(w:foldpeek_folds, {v:foldstart : dict})
endfunction
