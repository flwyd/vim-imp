let s:plugin = maktaba#plugin#Get('imp')
let s:logger = maktaba#log#Logger('imp#handler#ripgrep')
let s:warnedNotExecutable = 0
let s:warnedBase64 = 0

function! imp#handler#ripgrep#IsAvailable(context) abort
  let l:rg = s:plugin.Flag('ripgrep[command]')
  if !executable(l:rg)
    if !s:warnedNotExecutable
      let s:warnedNotExecutable = 1
      call maktaba#error#Warn('%s is not executable', l:rg)
    endif
    return 0
  endif
  return 1
endfunction

function! imp#handler#ripgrep#Suggest(context, symbol) abort
  " TODO Consider checking --pcre2-version and use it if available, in case a
  " Pattern handler wants to use lookaround
  let l:pat = imp#pattern#FromPreferred(a:context, 'rust', a:symbol)
  if empty(l:pat)
    return []
  endif
  let l:args = ['--json', '--crlf']
  if get(l:pat, 'multiline', 0)
    call add(l:args, '--multiline')
  endif
  if get(l:pat, 'ignorecase', 0)
    call add(l:args, '--ignore-case')
  else
    call add(l:args, '--case-sensitive')
  endif
  if empty(get(l:pat, 'fileglobs', []))
    let l:lang = get(a:context, 'filetype', '')
    if empty(l:lang)
      return []
    endif
    call add(l:args, '--type=' . l:lang)
  else
    for l:glob in l:pat.fileglobs
      call add(l:args, '--glob=' . l:glob)
    endfor
  endif
  for l:pattern in l:pat.patterns
    let l:args = extend(l:args, ['-e', l:pattern])
  endfor
  let l:args += imp#dir#PreferredLocations(a:context)
  let l:matches = s:parseRgJson(s:runRg(l:args))
  return imp#pattern#ParseMatches(a:context, l:pat, a:symbol, l:matches)
endfunction

function! s:runRg(args) abort
  let l:rg = imp#util#ArgsList(
        \ s:plugin.Flag('ripgrep[command]'), s:plugin.Flag('ripgrep[args]'))
  let l:cmd = maktaba#syscall#Create(l:rg + a:args)
  call s:logger.Debug('Running command %s', l:cmd.GetCommand())
  let l:result = l:cmd.Call(0)
  " rg exit value is 0 if text is found, 1 if not found, 2 for other errors
  if v:shell_error && v:shell_error != 1
    call maktaba#error#Warn('Error running %s', l:cmd.GetCommand())
    if !empty(l:result.stderr)
      call maktaba#error#Warn(l:result.stderr)
    endif
    return []
  endif
  return split(l:result.stdout, '\r\?\n')
endfunction

function! s:parseRgJson(result) abort
  " JSON format:
  " {type: "match",
  "  data: {
  "   path: {text: "foo/bar.py"},
  "   lines: {text: "import x\nimport y\n"},
  "   line_number: 1,
  "   absolute_offset: 0,
  "   submatches: [
  "    {match: {text: "import x", start: 0, end: 8}},
  "    {match: {text: "import y", start: 10, end: 18}}
  "   ]}}
  " Non-UTF8 content uses "bytes": "base64encoded" instead of "text"
  let l:matches = []
  for l:line in a:result
    let l:json = json_decode(l:line)
    if empty(l:json)
          \ || get(l:json, 'type', '') !=# 'match'
          \ || !has_key(l:json, 'data')
      continue
    endif
    let l:data = l:json.data
    if has_key(l:data, 'submatches')
      for l:m in l:data.submatches
        if has_key(l:m.match, 'text')
          call add(l:matches, l:m.match.text)
        elseif has_key(l:m.match, 'bytes')
          call add(l:matches, s:base64Decode(l:m.match.bytes))
        endif
      endfor
    elseif has_key(l:data, 'lines')
      if has_key(l:data.lines, 'text')
        call add(l:matches, l:json.lines.text)
      elseif has_key(l:data.lines, 'bytes')
        call add(l:matches, s:base64Decode(l:json.lines.bytes))
      endif
    endif
  endfor
  return maktaba#function#Filter(l:matches, {x -> !empty(x)})
endfunction

function! s:base64Decode(input) abort
  " Check for github.com/christianrondeau/vim-base64 plugin
  if exists('*base64#decode')
    return base64#decode(a:input)
  endif
  if executable('base64')
    let l:cmd = maktaba#syscall#Create(['base64', '--decode'])
          \ .WithStdin(a:input)
    let l:result = l:cmd.Call()
    if v:shell_error
      call s:logger.Warn('Error decoding base64 match "%s"', a:input)
      return ''
    endif
    return l:result.stdout
  endif
  if !s:warnedBase64
    call s:logger.Warn('Got base64 result from rg but cannot decode it, ' .
          \ 'consider installing https://github.com/christianrondeau/vim-base64')
  endif
  return ''
endfunction
