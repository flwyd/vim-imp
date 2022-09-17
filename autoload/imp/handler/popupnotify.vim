function! imp#handler#popupnotify#IsAvailable(context) abort
  " TODO add a flag to use this even if timers is disabled (manually dismiss)
  return has('timers') && exists('*popup_notification')
endfunction

function! imp#handler#popupnotify#Report(context, imported, already) abort
  " TODO add a time flag
  if empty(a:imported) && empty(a:already)
    let l:lines = ['No imports chosen']
    let l:result = 0
  else
    let l:lines = maktaba#function#Map(a:imported, {i -> i.statement})
    if !empty(a:context.already_imported)
      let l:already = maktaba#function#Map(
            \ a:context.already_imported, {i -> i.symbol})
      let l:lines += ['Already imported: ' . join(l:already, ' ')]
    endif
    let l:result = 1
  endif
  let l:minwidth = 10
  let l:width = max([l:minwidth,
        \ max(maktaba#function#Map(l:lines, {x -> len(x)}))])
  let l:col = max([1, &columns - l:width - 1])
  let l:options = {'line': 1, 'col': l:col, 'minwidth': l:minwidth}
  call popup_notification(l:lines, l:options)
  return l:result
endfunction
