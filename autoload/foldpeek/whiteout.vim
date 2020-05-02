let s:whiteout_styles = ['left', 'omit', 'fill', 'substitute']

function! foldpeek#whiteout#at_patterns(line) abort "{{{1
  for type in keys(g:foldpeek#whiteout#patterns)
    let {'patterns_'. type} = s:set_whiteout_patterns(type)
  endfor
  let ret = a:line

  let match_for_left = s:whiteout_left(ret, patterns_left)

  if !empty(match_for_left)
    let ret = match_for_left

  else
    let style_for_foldmarker = s:set_style_for_foldmarker()
    let {'patterns_'. style_for_foldmarker} += s:foldmarkers_on_buffer()

    let ret = s:whiteout_omit(ret, patterns_omit)
    let ret = s:whiteout_fill(ret, patterns_fill)
  endif

  let ret = s:whiteout_substitute(ret, patterns_substitute)

  if &ts != &sw
    let ret = substitute(ret, '^\t', repeat(' ', &tabstop), '')
  endif
  return substitute(ret, '\t', repeat(' ', &shiftwidth), 'g')
endfunction

function! s:set_whiteout_patterns(type) abort "{{{2
  let disabled_styles = string(get(b:, 'foldpeek_disabled_whiteout_styles',
        \ g:foldpeek#disabled_whiteout_styles))
  let overrided_styles = string(get(b:, 'foldpeek_overrided_whiteout_styles',
        \ g:foldpeek#overrided_whiteout_styles))

  if disabled_styles =~# a:type .'\|ALL'
    return []

  elseif overrided_styles =~# a:type .'\|ALL'
    " Note: without deepcopy(), g:foldpeek#whiteout_patterns_foo will increase
    " their values infinitely.
    return deepcopy(get(b:, 'foldpeek_whiteout_patterns_'. a:type,
          \ {'g:foldpeek#whiteout_patterns_'. a:type}))
  endif

return get(b:, 'foldpeek_whiteout_patterns_'. a:type, [])
      \ + {'g:foldpeek#whiteout_patterns_'. a:type}
endfunction

function! s:whiteout_left(text, patterns) abort "{{{2
  let ret = ''

  for pat in a:patterns
    if type(pat) == type('')
      let ret = matchstr(a:text, pat)

    elseif type(pat) == type([])
      for p in pat
        let l:match = matchstr(a:text, p)

        if empty(l:match)
          let ret = ''
          continue
        endif

        let ret .= l:match
      endfor

    else
      throw 'type of pattern to be left must be either String or List'
    endif

    if !empty(ret) | break | endif
  endfor

  return ret
endfunction

function! s:whiteout_omit(text, patterns) abort "{{{2
  let ret = a:text
  for pat in a:patterns
    let matchlen = len(matchstr(ret, pat))

    while matchlen > 0
      let ret .= repeat(' ', matchlen)
      let ret  = substitute(ret, pat, '', '')
      let matchlen = len(matchstr(ret, pat))
    endwhile
  endfor

  return ret
endfunction

function! s:whiteout_fill(text, patterns) abort "{{{2
  let ret = a:text
  for pat in a:patterns
    let ret = substitute(ret, pat, repeat(' ', len('\0')), 'g')
  endfor
  return  ret
endfunction

function! s:whiteout_substitute(text, lists) abort "{{{2
  let ret = a:text

  for l:list in a:lists
    let pat   = l:list[0]
    let sub   = l:list[1]
    let flags = l:list[2]

    let ret = substitute(ret, pat, sub, flags)
  endfor

  return ret
endfunction

function! s:set_style_for_foldmarker() abort "{{{2
  let ret = get(b:, 'foldpeek_whiteout_style_for_foldmarker',
        \ g:foldpeek#whiteout_style_for_foldmarker)

  if index(s:whiteout_styles, ret) < 0
    return 'omit'
  endif

  return ret
endfunction

function! s:foldmarkers_on_buffer() abort "{{{2
  if exists('b:foldpeek__foldmarkers')
    return b:foldpeek__foldmarkers
  endif

  let cms = split(&commentstring, '%s')
  " Note:  at end-of-line, replace cms which is besides foldmarker
  let foldmarkers = map(split(&foldmarker, ','),
        \ "'['. cms[0] .' ]*'.  v:val .'\\d*['. cms[len(cms) - 1] .' ]*$'")
  " TODO: except at end-of-line, constantly make a whitespace replace markers
  let foldmarkers += map(split(&foldmarker, ','),
        \ "'\\<'.  v:val .'\\d*\\>'")

  let b:foldpeek__foldmarkers = foldmarkers
  return b:foldpeek__foldmarkers
endfunction
