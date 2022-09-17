function! imp#handler#vcsroot#Location(context) abort
  let l:root = imp#dir#AncestorMatching('imp#dir#IsVcsRoot', a:context.path)
  return empty(l:root) ? [] : [l:root]
endfunction
