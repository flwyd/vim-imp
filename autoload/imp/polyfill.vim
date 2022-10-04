if exists('*flattennew')
  function! imp#polyfill#Flattennew(list, ...) abort
    return call('flattennew', [a:list] + a:000)
  endfunction
else
  ""
  " Polyfill for |flattennew()| for users before Vim 8.2.2449.  Flattens
  " {list} up to [maxdepth] levels.  Without [maxdepth], flattens all levels.
  " Returns a new list; the original is not changed.
  " @public
  function! imp#polyfill#Flattennew(list, ...) abort
    let l:result = []
    for l:i in a:list
      if type(l:i)  == v:t_list
        if a:0 == 0
          call extend(l:result, imp#polyfill#Flattennew(l:i))
        elseif a:1 > 0
          call extend(l:result, imp#polyfill#Flattennew(l:i, a:1 - 1))
        else
          call add(l:result, l:i)
        endif
      else
        call add(l:result, l:i)
      endif
    endfor
    return l:result
  endfunction
endif
