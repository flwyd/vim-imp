" Copyright 2022 Google LLC
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"      http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.

let s:plugin = maktaba#plugin#Get('imp')
let s:logger = maktaba#log#Logger('imp#handler#ack')
let s:warnedNotExecutable = 0
" Map from vim filetype to ack type from `ack --help-types`
" TODO make this map a plugin flag
let s:langMap = {
      \ 'c': 'cc',
      \ 'javascript': 'js', 'javascriptreact': 'js',
      \ 'typescript': 'ts', 'typescriptreact': 'ts',
      \ }

function! imp#handler#ack#IsAvailable(context) abort
  let l:ack = s:plugin.Flag('ack[command]')
  if !executable(l:ack)
    " TODO consider checking for ack-grep as a fallback
    if !s:warnedNotExecutable
      let s:warnedNotExecutable = 1
      call maktaba#error#Warn('%s is not executable', l:ack)
    endif
    return 0
  endif
  return 1
endfunction

function! imp#handler#ack#Suggest(context, symbol) abort
  " TODO Consider checking --pcre2-version and use it if available, in case a
  " Pattern handler wants to use lookaround
  let l:pat = imp#pattern#FromPreferred(a:context, 'perl', a:symbol)
  if empty(l:pat)
    return []
  endif
  let l:args = ['--group', '--with-filename', '--nocolor', '--no-smart-case']
  " ack does not support multiline
  if get(l:pat, 'ignorecase', 0)
    call add(l:args, '--ignore-case')
  else
    call add(l:args, '--no-ignore-case')
  endif
  if empty(get(l:pat, 'fileglobs', []))
    let l:lang = get(a:context, 'filetype', '')
    if empty(l:lang)
      return []
    endif
    call extend(l:args, ['--type', get(s:langMap, l:lang, l:lang)])
  else
    let l:args += ['--type', 'impsuggest']
    for l:glob in l:pat.fileglobs
      let l:args += ['--type-add', 'impsuggest:' . s:globToTypeAdd(l:glob)]
    endfor
  endif
  let l:dirs = imp#dir#PreferredLocations(a:context)
  " Unlike grep, ack lacks a way to provide multiple patterns on the command
  " line so run ack for each pattern and merge the results
  let l:filematches = {}
  for l:pattern in l:pat.patterns
    let l:matches = []
    let l:match = ''
    let l:filename = ''
    let l:prevnum = 0
    " Add an extra blank line to output to simplify 'blank line between file
    " output' loop logic
    for l:line in s:runAck(l:args + ['--match', l:pattern] + l:dirs) + ['']
      if empty(l:line)
        if !empty(l:match)
          call add(l:matches,l:match)
        endif
        " Since we have to call ack once per pattern, and multiple patterns
        " might match the same import line, remove duplicates from a single file
        " so they don't rank higher just because they matched more patterns.
        if has_key(l:filematches, l:filename)
          let l:matches = uniq(sort(l:filematches[l:filename] + l:matches))
        endif
        let l:filematches[l:filename] = l:matches
        let l:matches = []
        let l:match = ''
        let l:filename = ''
        let l:prevnum = 0
      elseif empty(l:filename)
        let l:filename = l:line
      else
        let l:m = matchlist(l:line, '\v^(\d+):(.*)')
        if !empty(l:m)
          let l:linenum = str2nr(l:m[1])
          let l:text = l:m[2]
          if l:prevnum == 0 || l:linenum - l:prevnum != 1
            if !empty(l:match)
              call add(l:matches, l:match)
            endif
            let l:match = l:text
          else
            if !empty(l:match)
              let l:match .= '\n'
            endif
            let l:match .= l:text
          endif
          let l:prevnum = l:linenum
        endif
      endif
    endfor
  endfor
  let l:all = imp#polyfill#Flattennew(values(l:filematches))
  return imp#pattern#ParseMatches(a:context, l:pat, a:symbol, l:all)
endfunction

function! s:runAck(args) abort
  let l:ack = imp#util#ArgsList(
        \ s:plugin.Flag('ack[command]'), s:plugin.Flag('ack[args]'))
  let l:cmd = maktaba#syscall#Create(l:ack + a:args)
  call s:logger.Debug('Running command %s', l:cmd.GetCommand())
  let l:result = l:cmd.Call(0)
  " ack exit value is 0 if text is found, 1 for not found, 255 for error
  if v:shell_error && v:shell_error != 1
    call maktaba#error#Warn('Error running %s', l:cmd.GetCommand())
    if !empty(l:result.stderr)
      call maktaba#error#Warn(l:result.stderr)
    endif
    return []
  endif
  return split(l:result.stdout, '\r\?\n')
endfunction

function s:globToTypeAdd(glob) abort
  if a:glob =~# '\v^(\w|[.=~+-])+$'
    return 'is:' . a:glob
  elseif a:glob =~# '\v^\*\.(\w|[.=~+-])+$'
    return 'ext:' . substitute(a:glob, '\v^\*\.', '', '')
  else
    return printf('match:/%s/', imp#pattern#GlobToRegex(a:glob))
  endif
endfunction
