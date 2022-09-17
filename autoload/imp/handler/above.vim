""
" 'above' is an inserter implementation which inserts import statements on the
" line before the cursor position.
function! imp#handler#above#Insert(context, imports) abort
  for l:import in a:imports
    let l:lines = split(l:import.statement, "\n")
    call append(line('.') - 1, l:lines)
  endfor
  let a:context.imported += a:imports
  return 1
endfunction
