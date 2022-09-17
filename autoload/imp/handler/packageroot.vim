function! imp#handler#packageroot#Location(context) abort
  let l:root = imp#dir#AncestorMatching('imp#dir#IsPackageRoot', a:context.path)
  return empty(l:root) ? [] : [l:root]
endfunction
