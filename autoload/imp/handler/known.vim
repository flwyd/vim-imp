" Filetype to dict of symbol to list of Imports
let s:data = {}

""
" @public
" Adds {statements} to the list of imports for filetype {lang} in the `known`
" Suggest handler.  {statements} can be a single @dict(Import), a list of
" Imports, a single string, a list of strings, or a dict with symbols as keys
" and either Imports or strings as values.  Strings will be converted to
" @dict(Import) values using a Pattern handler (@section(handlers-pattern))
" which has a Parse method; if no such Pattern handler is registered for {lang}
" then the string statements will be ignored with a warning.
function! imp#handler#known#Add(lang, statements) abort
  if !has_key(s:data, a:lang)
    let s:data[a:lang] = {}
  endif
  let l:known = s:data[a:lang]
  if maktaba#value#IsDict(a:statements)
    if s:isImport(a:statements)
      call s:addToKnown(l:known, a:statements)  " single import
    else
      for [l:k, l:v] in a:statements
        call s:addToKnown(
              \ l:known, s:isImport(l:v) ? l:v : imp#NewImport(l:k, l:v))
      endfor
    endif
  else
    let l:context = imp#NewContext({'filetype': a:lang})
    let l:pats = []
    let l:gotpats = 0
    for l:statement in imp#util#ToList(a:statements)
      if maktaba#value#IsDict(l:statement)
        if s:isImport(l:statement)
          call s:addToKnown(l:known, l:statement)
        else
          for [l:k, l:v] in l:statement
            call s:addToKnown(
                  \ l:known, s:isImport(l:v) ? l:v : imp#NewImport(l:k, l:v))
          endfor
        endif
      else
        if empty(l:pats)
          if !l:gotpats
            let l:pats = maktaba#function#Filter(
                  \ copy(imp#handler#Preferred(l:context, 'Pattern')),
                  \ {p -> has_key(p, 'Parse')})
            let l:gotpats = 1
            if empty(l:pats)
              call maktaba#error#Warn(
                    \ 'No registered Pattern for %s, cannot add %s',
                    \ a:lang, l:statement)
            endif
          endif
        endif
        if !empty(l:pats)
          let l:import = l:pats[0].Parse(l:statement)
          let l:known[l:import.symbol] = l:import
        endif
      endif
    endfor
  endif
endfunction

function! s:addToKnown(known, import) abort
  call maktaba#ensure#IsTrue(
        \ s:isImport(a:import), '%s is not an Import', a:import)
  if !has_key(a:known, a:import.symbol)
    let a:known[a:import.symbol] = []
  endif
  let l:list = a:known[a:import.symbol]
  let l:existing =
        \ imp#util#Find(l:list, maktaba#function#Method(a:import, 'Equals'))
  if empty(l:existing)
    call add(l:list, copy(a:import))
  else
    let l:existing.count += a:import.count
  endif
endfunction

function! imp#handler#known#Suggest(context, symbol) abort
  " TODO consider checking flags if not in s:data or l:known
  let l:known = get(s:data, a:context.filetype, {})
  if empty(l:known)
    return []
  endif
  let l:options = maktaba#function#Sorted(
        \ get(l:known, a:symbol, []), {x, y -> y.count - x.count})
  return l:options[0:a:context.max-1]
endfunction

function! s:isImport(x) abort
  return maktaba#value#IsDict(a:x)
        \ && has_key(a:x, 'symbol') && has_key(a:x, 'statement')
endfunction
