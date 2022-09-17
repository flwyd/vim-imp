let s:plugin = maktaba#plugin#Get('imp')
let s:logger = maktaba#log#Logger('imp#handler')

""
" Returns true if {handler} (a handler extension dict) is available with the
" given {context}, false otherwise.  If a string [method] is provied and is not
" empty, will return false if {handler} does not implement [method].
" @default method=''
function! imp#handler#IsAvailable(context, handler, ...) abort
  let l:method = get(a:, 1, '')
  call maktaba#ensure#IsDict(a:context)
  call maktaba#ensure#IsDict(a:handler)
  call maktaba#ensure#IsString(l:method)
  if !empty(l:method) && !has_key(a:handler, l:method)
    return 0
  endif
  if has_key(a:handler, 'IsAvailable')
    " TODO contribute maktaba#value#IsBool
    if type(a:handler.IsAvailable) == v:t_bool
      return a:handler.IsAvailable
    elseif maktaba#value#IsNumber(a:handler.IsAvailable)
      return a:handler.IsAvailable != 0
    else
      return maktaba#function#Call(a:handler.IsAvailable, [a:context])
    endif
  endif
  return 1
endfunction

""
" Returns an ordered list of handler extensions which implement {method} and
" support {context}.filetype.  Order and presence is determined by user
" preference flag values for {method}; extensions where `IsAvailable()` is false
" are excluded from the result.
function! imp#handler#Preferred(context, method) abort
  call maktaba#ensure#IsDict(a:context)
  call maktaba#ensure#IsString(a:method)
  let l:flag = s:plugin.flags[a:method].Get()
  let l:names = []
  let l:type = get(a:context, 'filetype', '')
  if !empty(l:type)
    let l:names = imp#util#ToList(get(l:flag, l:type, []))
  else
    let l:type = 'default'
  endif
  if empty(l:names)
    let l:names = imp#util#ToList(get(l:flag, 'default', []))
  endif
  let l:handlers = []
  for l:name in l:names
    try
      let l:handler = imp#handler#ForName(a:context, l:name, a:method)
    catch /ERROR(NotFound)/
      call maktaba#error#Warn('No %s handler named %s can handle filetype %s',
            \ a:method, l:name, l:type)
      continue
    endtry
    if !has_key(l:handler, a:method)
      call maktaba#error#Warn('Handler %s for filetype %s lacks %s method',
            \ l:name, l:type, a:method)
      continue
    endif
    if imp#handler#IsAvailable(a:context, l:handler, a:method)
      let l:handlers += [l:handler]
      call s:logger.Debug('%s handler %s handler is available for %s',
            \ a:method, l:name, l:type)
    else
      call s:logger.Debug('%s handler %s handler is not available for %s',
            \ a:method, l:name, l:type)
    endif
  endfor
  return l:handlers
endfunction

""
" Looks up a handler by name from the extension registry with an implementation
" for {method}.  If an extension is registered for specific filetypes, it is
" only returned if `a:context.filetype` is one of them.  Handlers with matching
" `filetypes` are returned in preference to handlers with no `filetypes`
" property.  This function does not check `IsAvailable`.
function! imp#handler#ForName(context, name, method) abort
  call maktaba#ensure#IsDict(a:context)
  call maktaba#ensure#IsString(a:name)
  let l:filetype = get(a:context, 'filetype', '')
  call s:logger.Debug('Look up handler name=%s filetype=%s', a:name, l:filetype)
  let l:fallback = {}
  for l:extension in s:plugin.GetExtensionRegistry().GetExtensions()
    if l:extension.name ==# a:name && has_key(l:extension, a:method)
      call s:logger.Debug('Found match %s ==# %s', l:extension.name, a:name)
      if has_key(l:extension, 'filetypes') && !empty(l:extension.filetypes)
        let l:ft = imp#util#ToList(l:extension.filetypes)
        if !maktaba#value#IsIn(l:filetype, l:ft)
          call s:logger.Debug('%s filetypes=%s missing %s',
                \ l:extension.name, l:extension.filetypes, l:filetype)
          continue
        endif
        call s:logger.Debug('Returning %s', l:extension)
        return l:extension
      elseif empty(l:fallback)
        " Prefer filetype handlers to generic handlers, but hang on to one
        let l:fallback = l:extension
      endif
    endif
  endfor
  if !empty(l:fallback)
    call s:logger.Debug('Returning non-filetype %s', l:fallback)
    return l:fallback
  endif
  throw maktaba#error#NotFound(
        \ 'No %s handler named %s available for filetype %s',
        \ a:method, a:name, l:filetype)
endfunction

""
" Implementation of @command(ImpHandlers).  Prints summary information for
" handlers which match [matches...], or all handlers if called with no
" arguments.  [matches] can be filetypes or handler method names.
" Output format subject to change.  Might be nice to show in a selector window
" rather than echo, maybe as :ImportHandlers!
function! imp#handler#PrintList(...) abort
  let l:methodabbr = {'Suggest': 'S', 'Pick': 'P', 'Insert': 'I', 'Report': 'R',
        \ 'Pattern': '/', 'Location': 'L'}
  let l:methods = ['Suggest', 'Pick', 'Insert', 'Report', 'Pattern', 'Location']
  let l:legend = join(maktaba#function#Map(
        \ l:methods, {x -> l:methodabbr[x] . '=' . x}), ' ')
  let l:filetypes = []
  let l:matchmethods = []
  for l:arg in a:000
    let l:method = substitute(l:arg, '\v^(.)(.*)', '\u\1\L\2', '')
    if maktaba#value#IsIn(l:method, l:methods)
      call add(l:matchmethods, l:method)
    else
      call add(l:filetypes, l:arg)
    endif
  endfor
  let l:lines = []
  let l:continuation = []
  let l:exts = maktaba#function#Sorted(
        \ s:plugin.GetExtensionRegistry().GetExtensions(),
        \ function('s:compareExtensions'))
  for l:ext in l:exts
    if !empty(l:matchmethods)
          \ && empty(imp#util#Intersection(keys(l:ext), l:matchmethods))
      continue
    endif
    let l:type = ''
    if has_key(l:ext, 'filetypes') && !empty(l:ext.filetypes)
      let l:ft = imp#util#ToList(l:ext.filetypes)
      if !empty(l:filetypes) && empty(imp#util#Intersection(l:ft, l:filetypes))
        continue
      endif
      let l:type = l:ft[0]
      if len(l:ft) > 1
        let l:continuation = ['', '', join(l:ft[1:], ','), '']
      endif
      let l:type = l:ft[0]
    endif
    let l:funcs = ''
    for l:func in l:methods
      if has_key(l:ext, l:func)
        let l:funcs .= l:methodabbr[l:func]
      endif
    endfor
    let l:lines += [[l:ext.name, l:funcs, l:type, l:ext.description]]
    if !empty(l:continuation)
      let l:lines += [l:continuation]
      let l:continuation = []
    endif
  endfor
  let l:header = ['Name', 'Func', 'Filetype', 'Description']
  let l:max = maktaba#function#Map(l:header, 'strdisplaywidth')
  for l:line in l:lines
    if !empty(l:line[0])
      for l:i in range(0, len(l:max) - 2)
        let l:max[l:i] = max([l:max[l:i], strdisplaywidth(l:line[l:i])])
      endfor
    endif
  endfor
  let l:format = call('printf',
        \ [join(repeat(['%%-%dS'], len(l:max)), ' ')] + l:max)
  echo l:legend
  echo maktaba#function#Call('printf', [l:format] + l:header)
  for l:line in l:lines
    echo maktaba#function#Call('printf', [l:format] + l:line)
  endfor
endfunction

function! s:compareExtensions(x, y) abort
  if a:x.name <? a:y.name
    return -1
  elseif a:x.name >? a:y.name
    return 1
  endif
  let l:xft = imp#util#ToList(get(a:x, 'filetypes', []))
  let l:yft = imp#util#ToList(get(a:y, 'filetypes', []))
  for l:i in range(0, min([len(l:xft), len(l:yft)]) - 1)
    if l:xft[l:i] <=? l:yft[l:i]
      return -1
    elseif l:xft[l:i] >=? l:yft[l:i]
      return 1
    endif
  endfor
  return len(l:xft) - len(l:yft)
endfunction
