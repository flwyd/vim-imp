let s:plugin = maktaba#plugin#Get('imp')

function! imp#handler#parent#Location(context) abort
  let l:levels = s:plugin.Flag('parent[levels]')
  call maktaba#ensure#IsTrue(l:levels >= 0,
        \ 'parent[levels] must be non-negative, not %d', l:levels)
  " use relative paths if we can, but absolute paths if not deep enough
  let l:heads = repeat(':h', l:levels + 1)
  let l:mod = l:levels > len(maktaba#path#Split(a:context.path))
        \ ? ':p' .  l:heads : l:heads
  return [fnamemodify(a:context.path, l:mod)]
endfunction
