let s:plugin = maktaba#plugin#Get('imp')
let s:logger = maktaba#log#Logger('imp#handler#hggrep')
let s:warnedNotExecutable = 0

function! imp#handler#hggrep#IsAvailable(context) abort
  let l:hg = s:plugin.Flag('hggrep[command]')
  if !executable(l:hg)
    if !s:warnedNotExecutable
      let s:warnedNotExecutable = 1
      call maktaba#error#Warn('%s is not executable', l:hg)
    endif
    return 0
  endif
  return 1
endfunction

function! imp#handler#hggrep#Suggest(context, symbol) abort
  " TODO Consider checking --pcre2-version and use it if available, in case a
  " Pattern handler wants to use lookaround
  let l:pat = imp#pattern#FromPreferred(a:context, 'python', a:symbol)
  if empty(l:pat)
    return []
  endif
  let l:args = ['--color=never', '--pager=never', '--print0']
  " Multiline is on automatically, no flag to turn it off
  if get(l:pat, 'ignorecase', 0)
    call add(l:args, '--ignore-case')
  else
    call add(l:args, '--no-ignore-case')
  endif
  for l:glob in get(l:pat, 'fileglobs', [])
    if l:glob !~# '/'
      " hg help pattern explains that file patterns are evaluated on the whole
      " path, not individual files, so need leading **/ wildcard
      let l:glob = '**/' . l:glob
    endif
    let l:args += ['--include', l:glob]
  endfor
  let l:dirs = imp#dir#PreferredLocations(a:context)
  " Unlike grep, hg grep lacks a way to provide multiple patterns on the command
  " line so run hg grep for each pattern and merge the results
  let l:filematches = {}
  for l:pattern in l:pat.patterns
    " With --print0, output alternates between file path and full match text
    let l:output = s:runHg(l:args + ['--', l:pattern] + l:dirs)
    for l:i in range(0, len(l:output) - 1, 2)
      let l:filename = l:output[l:i]
      let l:text = l:output[l:i + 1]
      if !has_key(l:filematches, l:filename)
        let l:filematches[l:filename] = []
      endif
      call add(l:filematches[l:filename], l:text)
    endfor
  endfor
  " Since we have to call hg once per pattern, and multiple patterns might
  " match the same import line, remove duplicates from a single file so
  " they don't rank higher just because they matched more patterns.
  for [l:key, l:val] in items(l:filematches)
    let l:filematches[l:key] = uniq(sort(l:val))
  endfor
  let l:all = imp#polyfill#Flattennew(values(l:filematches))
  return imp#pattern#ParseMatches(a:context, l:pat, a:symbol, l:all)
endfunction

function! s:runHg(args) abort
  " Split command on spaces not preceeded by a backslash
  let l:hg = imp#util#ArgsList(s:plugin.Flag('hggrep[command]'),
        \ s:plugin.Flag('hggrep[grep]'), s:plugin.Flag('hggrep[args]'))
  let l:cmd = maktaba#syscall#Create(l:hg + a:args)
  call s:logger.Debug('Running command %s', l:cmd.GetCommand())
  let l:result = l:cmd.Call(0)
  " hg exit value is 0 if text is found, 1 for not found, and 255 for errors
  if v:shell_error && v:shell_error != 1
    call maktaba#error#Warn('Error running %s', l:cmd.GetCommand())
    if !empty(l:result.stderr)
      call maktaba#error#Warn(l:result.stderr)
    endif
    return []
  endif
  " --print0 uses NUL byte as a delimiter, but Vim uses C NUL-terminated strings
  " and converts NUL in output to byte value 1 aka SOH aka ^A
  return split(l:result.stdout, "\x01")
endfunction
