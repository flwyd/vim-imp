""
" 'lucky' is a picker implementation that just picks the first suggestion.
function! imp#handler#lucky#Pick(context, suggestions) abort
  return empty(a:suggestions) ? [] : [a:suggestions[0]]
endfunction
