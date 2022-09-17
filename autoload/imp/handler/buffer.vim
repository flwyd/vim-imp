let s:plugin = maktaba#plugin#Get('imp')
let s:logger = maktaba#log#Logger('imp#handler#buffer')

function! imp#handler#buffer#IsAvailable(context) abort
  return 1
endfunction

function! imp#handler#buffer#Suggest(context, symbol) abort
  let l:pat = imp#pattern#FromPreferred(a:context, 'vim', a:symbol)
  if empty(l:pat)
    return []
  endif
  let l:matches = []
  let l:filepats = maktaba#function#Map(
        \ get(l:pat, 'fileglobs', []), {x -> glob2regpat(x)})
  let l:mybufnr = bufnr()
  for l:buf in getbufinfo()
    if l:buf.bufnr == l:mybufnr
      continue " don't search current file
    endif
    let l:relevant = 0
    if !empty(a:context.filetype)
      if getbufvar(l:buf.bufnr, '&filetype') ==# a:context.filetype
        let l:relevant = 1
      endif
    endif
    if !l:relevant && !empty(l:buf.name)
      for l:re in l:filepats
        if fnamemodify(l:buf.name, ':t') =~ l:re
          let l:relevant = 1
          break
        endif
      endfor
    endif
    if l:relevant
      call s:logger.Debug('Searching for %s in %s', a:symbol, l:buf.name)
      if s:plugin.Flag('buffer[load]')
        call bufload(l:buf.bufnr)
      endif
      " TODO if l:pat.multiline then join lines in the buffer and search that
      " string. May need adjustments to some style='vim' patterns to use \_s for
      " space-including-newline and \_^ for start-of-line in mid-string.
      " TODO Figure out why \_^ doesn't match inside join(l:lines, "\n").
      let l:lines = getbufline(l:buf.bufnr, 1, '$')
      for l:line in l:lines
        for l:re in l:pat.patterns
          try
            let l:match = matchstr(l:line, l:re)
            if !empty(l:match)
              call add(l:matches, l:match)
            endif
          catch /E871:/
            " TODO Deal with the 'Can't have a multi follow a multi' error in
            " the keyword variant of the bzl pattern
            call s:logger.Debug(
                  \ 'Vim regex format error for %s %s', l:re, v:exception)
          endtry
        endfor
      endfor
    endif
  endfor
  return imp#pattern#ParseMatches(a:context, l:pat, a:symbol, l:matches)
endfunction
