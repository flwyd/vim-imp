function! imp#handler#echomsg#Report(context, imported, already) abort
  if empty(a:imported) && empty(a:already)
    echomsg 'No imports chosen'
    return 0
  endif
  " Redraw first because added imports may trigger a redraw when the command
  " is done which will clear the echo area.
  redraw
  let l:lines = maktaba#function#Map(a:imported, {i -> i.statement})
  if !empty(a:context.already_imported)
    let l:already = maktaba#function#Map(
          \ a:context.already_imported, {i -> i.symbol})
    let l:lines += ['Already imported: ' . join(l:already, ' ')]
  endif
  echomsg join(l:lines, "\n")
  return 1
endfunction
