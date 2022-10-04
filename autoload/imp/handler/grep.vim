let s:plugin = maktaba#plugin#Get('imp')
let s:logger = maktaba#log#Logger('imp#handler#grep')
let s:warnedNotExecutable = 0
let s:grepFlavor = ''

function! imp#handler#grep#IsAvailable(context) abort
  let l:grep = s:plugin.Flag('grep[command]')
  if !executable(l:grep)
    if !s:warnedNotExecutable
      let s:warnedNotExecutable = 1
      call maktaba#error#Warn('%s is not executable', l:grep)
    endif
    return 0
  endif
  if empty(s:grepFlavor)
    let l:grep = imp#util#ArgsList(s:plugin.Flag('grep[command]'), '--version')
    let l:cmd = maktaba#syscall#Create(l:grep)
    call s:logger.Debug('Running command %s', l:cmd.GetCommand())
    let l:result = l:cmd.Call(0)
    " e.g. 'grep (BSD grep) 2.5.1-FreeBSD' or 'grep (GNU grep) 3.4'
    let s:grepFlavor = substitute(matchstr(l:result.stdout, '\v\(\w+ grep\)'),
          \ '\v\((.*) grep\)', '\1', '')
    echomsg 'grep flavor is' s:grepFlavor
  endif
  return 1
endfunction

function! imp#handler#grep#Suggest(context, symbol) abort
  " TODO Consider checking --pcre2-version and use it if available, in case a
  " Pattern handler wants to use lookaround
  let l:pat = imp#pattern#FromPreferred(a:context, 'posix', a:symbol)
  if empty(l:pat)
    return []
  endif
  " -E extended regexp, -R recursive, -h no filename
  let l:args = ['-E', '-R', '-h']
  " TODO find a way to handle multiline with grep
  if get(l:pat, 'ignorecase', 0)
    call add(l:args, '-i')
  endif
  for l:glob in get(l:pat, 'fileglobs', [])
    call add(l:args, '--include=' . l:glob)
  endfor
  for l:pattern in l:pat.patterns
    let l:args += ['-e', l:pattern]
  endfor
  let l:dirs = imp#dir#PreferredLocations(a:context)
  if empty(l:dirs)
    let l:dirs = ['.']
  endif
  " Ignore hidden dot dirs, e.g. for VCS state. A simple '.*' pattern would skip
  " everything because we're searching '.'
  " Unfortunately, GNU grep applies --exclude-dir to command-line args while
  " BSD grep applies them to paths encountered during recursion. This makes
  " tests fail with GNU grep if run from the .vim directory, so hack around
  " that problem here.
  if s:grepFlavor !=# 'GNU' || match(l:dirs, '\v(^|/)\.[0-9A-Za-z]') == -1
    let l:args += ['--exclude-dir', '.[0-9A-Za-z]*']
  endif
  let l:args += l:dirs
  return imp#pattern#ParseMatches(a:context, l:pat, a:symbol, s:runGrep(l:args))
endfunction

function! s:runGrep(args) abort
  let l:grep = imp#util#ArgsList(
        \ s:plugin.Flag('grep[command]'), s:plugin.Flag('grep[args]'))
  let l:cmd = maktaba#syscall#Create(l:grep + a:args)
  call s:logger.Debug('Running command %s', l:cmd.GetCommand())
  let l:result = l:cmd.Call(0)
  " grep exit value is 0 if text is found, 1 if not found, >1 for other errors
  if v:shell_error && v:shell_error != 1
    call maktaba#error#Warn('Error running %s', l:cmd.GetCommand())
    if !empty(l:result.stderr)
      call maktaba#error#Warn(l:result.stderr)
    endif
    return []
  endif
  return split(l:result.stdout, '\r\?\n')
endfunction
