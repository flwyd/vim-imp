""
" 'top' is an inserter implementation which inserts import statements at the
" beginning of the file. If 'position' is present in the context, it will
" append after that line, then sets position to the next line so that multiple
" import operations with the same context are added in order. If 'position' is
" not in context, inserts the statement prior to the first line of the buffer,
" or after the first line if the file starts with a #! line.
function! imp#handler#top#Insert(context, imports) abort
  " TODO check if the statement is already present
  let l:position = get(a:context, 'position', 0)
  if l:position == 0 && maktaba#string#StartsWith(getline(1), '#!')
    let l:position = 1
  endif
  for l:import in a:imports
    let l:lines = split(l:import.statement, "\n")
    call append(l:position, l:lines)
    let l:position += len(l:lines)
  endfor
  " If adding several statements in one command, insert in order, not reversed
  let a:context.position = l:position
  let a:context.imported += a:imports
  return 1
endfunction
