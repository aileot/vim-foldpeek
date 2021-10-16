" Note: Keep the variable name being capitalized.
" Variable which a funcref once assigned to cannot be copied to
" another, uncapitalized variable in VimScript. Currently, it works here
" without being capitalized; however, keep the variable capitalized because,
" if careless modifications should caused errors with this VimScript specific
" problem, the cause would be hardly found.
" @param Expr string|number|function
" @return any
function! foldpeek#util#eval_or_raw(Expr) abort
  try
    if type(a:Expr) == v:t_func
      return call(a:Expr, [])
    endif
    return eval(a:Expr)
  catch
    return a:Expr
  endtry
endfunction
