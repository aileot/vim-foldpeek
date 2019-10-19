

setlocal foldmethod=expr
setlocal foldexpr=GetPosFold(v:lnum)

hi LineH1 gui=bold guibg=red
hi LineH2 gui=underline guibg=green
hi LineH3 gui=underline guibg=yellow

"============================================================================
"
" Checks a string for the number of openChar minus the number of closeChar.
" Stops counting if it sees a commentChar.
"
"============================================================================
function! CountForCharDiff(lstr, openChar, closeChar, commentChar)

     let stringLen    = strlen(a:lstr)
     let index        = 0
     let bracketCount = 0

     " loop over the length of the string to find the open
     " close and comment charaters
     while index < stringLen

         let lchar = strpart(a:lstr, index, 1)

         if lchar =~? a:commentChar
             break
         elseif lchar =~? a:openChar
             let bracketCount += 1
         elseif lchar =~? a:closeChar
             let bracketCount -= 1
         endif

         let index += 1
     endwhile

     return bracketCount

endfunction

"============================================================================
"
" Counts the fold level change by summing the { and } brackets on the
" line.
"
"============================================================================

function! SumBracketOnLine(lnum)

    return CountForCharDiff(getline(a:lnum), '{', '}', '#')

endfunction


"============================================================================
"
" Compares two PosBracketFold items on the line number (in the initial
" position, or [0])
"
"============================================================================

function! MyListCompare(i1, i2)
    return a:i1[0] == a:i2[0] ? 0 : a:i1[0] > a:i2[0] ? 1 : -1
endfunc

"============================================================================
"
" returns a sorted array bsed on the b:PosBracketFold which is the
" buffer's information for the fold level changes.
"
"============================================================================

function! GetSortedPosBracketFold()
    return sort(map(items(b:PosBracketFold),'[str2nr(v:val[0]),v:val[1]]'),"MyListCompare")
endfunc

"============================================================================
"
" A look up function to turn fold levels into highlights, this requires
" the highlights to work first
"
"============================================================================

function! GetMatchString (ref)
    let ret = ""

    if a:ref == "4"
        let ret = "LineH1"
    elseif a:ref == "3"
        let ret = "LineH2"
    elseif a:ref == "2"
        let ret = "LineH3"
    endif

    return l:ret
endfunc


"============================================================================
"
" ApplyMatches
"
" function applies selected highlighting for various lines based on the fold
" or bracket levels.
"
"============================================================================

function! ApplyMatches ()

    " makes sure that the correct PosBracketFold array has been generated before we
    " start
    let l:j = 0
    while l:j < line("w$")
        let l:dummy = GetPosFold(l:j)
        let l:j += 1
    endwhile

    " now get the sorted array of the folds
    let l:posList  = GetSortedPosBracketFold()
    let l:i        = 0

    " debug
    "echo l:posList

    " Now loop over all the arrays found and apply highlighting
    while l:i < len(l:posList)
        let l:level = l:posList[l:i][1]

        " debug
        " echo "================="
        " echo "checking level: " . l:level

        " find the start and end of the current fold level
        let l:j = l:i + 1

        while l:j < len(l:posList)

            if l:level > l:posList[l:j][1]
                break
            endif

            let l:j += 1
        endwhile

        let l:startLine = l:posList[l:i][0]
        let l:endLine   = (l:posList[l:j][0] - 1)

        " debug
        " echo "starting at " . l:startLine
        " echo "ending at   " . l:endLine

        let l:matchString = ''

        " change this as needed, for testing i only let level 3 and 4 appear
        if l:level == 4 || l:level == 3 || l:level == 2
            " now create the match string via a loop
            let l:k = l:startLine
            while l:k < l:endLine

                if GetLevel( l:k ) == l:level
                    let l:matchString = l:matchString . '\%' . l:k . 'l\|'
                endif
                let l:k += 1
            endwhile
            let l:matchString = l:matchString . '\%' . l:k . 'l'

            " debug
            " echo "match string is " . l:matchString

            " apply the match string, using the GetMatchString function
            " to select the highlighting to apply
            let l:m = matchadd(GetMatchString(l:level),l:matchString, -1)
        endif

        " tidy up, now remove the entries we have dealt with
        let l:dummy = remove(l:posList,l:i)
        let l:dummy = remove(l:posList,(l:j-1))

        " debug
        " echo "================="
        " echo l:posList

    endwhile

endfunc


"============================================================================
"
" Gets the local position fold
"
" lnum -  the line number being calculated
" sum  -  An offset to change the fold level after the calculation
"
"
"============================================================================

function! GetFoldDepth(lnum, sum, update)

    " always make sure the global array exists
    if exists('b:PosBracketFold') == 0
        let b:PosBracketFold = {}
    endif

    let l:foldLevel = 0
    let l:i         = (len(b:PosBracketFold) - 1)
    let l:posList   = GetSortedPosBracketFold()

    " b:PosBracketFold is an array of {line number, fold level} containing all the bracket changes
    " so scan over that to find the right fold level
    while l:i > -1

        if a:lnum > l:posList[l:i][0]
            let l:foldLevel = l:posList[l:i][1]
            break
        endif
        let l:i -= 1
    endwhile

    " apply the offset
    let l:foldLevel += a:sum

    " if update is toggled on then update the PosBracketFold array
    " but only do so in 2 cases
    " 1) if there is an old bracket change that needs to be removed
    " 2) if there is a new bracket change that needs to be added
    if a:update == 1
        if a:sum == 0 && has_key(b:PosBracketFold,a:lnum)
            unlet b:PosBracketFold[a:lnum]
        elseif a:sum != 0
            let b:PosBracketFold[a:lnum] = l:foldLevel
        endif
    endif

    return l:foldLevel

endfunction

"============================================================================
"
" Gets the local position fold depth
"
" Takes account of the next depth level or the previous one to give the right
" answer.
"
" lnum -  the line number being calculated
"
"============================================================================
function! GetPosFold(lnum)

    " checks if there is open/close brackets on the next line
    let nextSum = 0
    if a:lnum < line('$')
        let nextSum = SumBracketOnLine(a:lnum + 1)
    endif

    " checks the number of lines on the previous line
    let prevSum = 0
    if a:lnum > 0
        let prevSum = SumBracketOnLine(a:lnum - 1)
    endif

    " if the next line is positive we are opening a new fold level
    " so use the special character > to indicate this and show the
    " correct text
    if nextSum > 0
        return '>' . GetFoldDepth(a:lnum, nextSum,1)

    " else if the previous line is negative then we are closing a fold
    elseif prevSum < 0
        return GetFoldDepth(a:lnum, prevSum,1)
    else

    " else we are not changing fold level so we just return the fold depth
        return GetFoldDepth(a:lnum, 0,1)
    endif

endfunction

set laststatus=2


"============================================================================
"
" Gets the local position fold depth
"
" Always returns the correct fold level for the line number
"
" lnum -  the line number being calculated
"
"============================================================================
function! GetLevel( lnum )

    let ret  = GetPosFold(a:lnum)

    if strpart(ret,0,1) == '>'
        let ret = strpart(ret,1)
    endif

    return ret

endfunction


"============================================================================
"
" Gets the status line string, currently just the fold level
"
"============================================================================
function! GetStatusLine()

    let lnum = line('.')
    return GetLevel(lnum)

endfunction

set statusline=
set statusline+=%{GetStatusLine()}

