let s:whiteout = {}
let s:whiteout_styles_available = ['match', 'omit', 'fill', 'substitute']

function! foldpeek#whiteout#at_patterns(line) abort "{{{1
  let patterns = {}
  for type in s:whiteout_styles_available
    let patterns[type] = s:set_whiteout_patterns(type)
  endfor
  let ret = a:line

  let matched = s:whiteout.match(ret, patterns.match)

  if !empty(matched)
    let ret = matched

  else
    let patterns[s:style_for_foldmarker()] += s:foldmarkers_on_buffer()

    let ret = s:whiteout.omit(ret, patterns.omit)
    let ret = s:whiteout.fill(ret, patterns.fill)
  endif

  let ret = s:whiteout.substitute(ret, patterns.substitute)

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
  let g_patterns = get(g:foldpeek#whiteout#patterns, a:type, [])

  let ret = []
  if disabled_styles =~# a:type .'\|ALL'
    return []
  elseif !exists('b:foldpeek_whiteout_patterns')
    let ret = g_patterns
  elseif overrided_styles =~# a:type .'\|ALL'
    let ret = get(b:foldpeek_whiteout_patterns, a:type, g_patterns)
  else
    let ret = get(b:foldpeek_whiteout_patterns, a:type, []) + g_patterns
  endif

  if type(ret) != type([])
    return 'Not a List: '. ret
  endif

  return ret
endfunction

function! s:whiteout.match(text, patterns) abort "{{{2
  let ret = ''

  for pat in a:patterns
    if type(pat) == type('')
      let ret = matchstr(a:text, pat)
    else
      return 'Not a String: '. pat
    endif

    if !empty(ret) | break | endif
  endfor

  return ret
endfunction

function! s:whiteout.omit(text, patterns) abort "{{{2
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

function! s:whiteout.fill(text, patterns) abort "{{{2
  let ret = a:text
  for pat in a:patterns
    let ret = substitute(ret, pat, repeat(' ', len('\0')), 'g')
  endfor
  return  ret
endfunction

function! s:whiteout.substitute(text, lists) abort "{{{2
  let ret = a:text

  if type(a:lists) != type([])
    return 'Not a List: '. a:lists
  endif

  for l:list in a:lists
    try
      let pat   = l:list[0]
      let sub   = l:list[1]
      let flags = l:list[2]
    catch /E684/
      return 'Invalid patterns: '. l:list
            \ .'; you must set in [{pat}, {sub}, {flags}]'
    endtry

    let ret = substitute(ret, pat, sub, flags)
  endfor

  return ret
endfunction

function! s:style_for_foldmarker() abort "{{{2
  let ret = get(b:, 'foldpeek_whiteout_style_for_foldmarker',
        \ g:foldpeek#whiteout#style_for_foldmarker)

  if ret !=# 'fill'
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
