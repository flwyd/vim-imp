""
" 'inputlist' is a picker implementation that presents numbered suggestions
" using a vim `inputlist()`.
function! imp#handler#inputlist#Pick(context, suggestions) abort
  if empty(a:suggestions)
    return []
  endif
  if len(a:suggestions) == 1
    return a:suggestions
  endif
  let l:symbol = a:suggestions[0].symbol
  let l:opts = ['Choose import for ' . l:symbol]
  for l:i in range(1, len(a:suggestions))
    let l:imp = a:suggestions[l:i - 1]
    call add(l:opts, printf('%2d: %s', l:i, l:imp.statement))
  endfor
  let l:choiceidx = inputlist(l:opts)
  if l:choiceidx <= 0 || l:choiceidx > len(a:suggestions)
    return []
  endif
  return [a:suggestions[l:choiceidx - 1]]
endfunction
