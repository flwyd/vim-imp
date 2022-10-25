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
let s:logger = maktaba#log#Logger('imp#handler#gitgrep')
let s:warnedNotExecutable = 0

function! imp#handler#gitgrep#IsAvailable(context) abort
  let l:git = s:plugin.Flag('gitgrep[command]')
  if !executable(l:git)
    if !s:warnedNotExecutable
      let s:warnedNotExecutable = 1
      call maktaba#error#Warn('%s is not executable', l:git)
    endif
    return 0
  endif
  return 1
endfunction

function! imp#handler#gitgrep#Suggest(context, symbol) abort
  " TODO Consider checking if git was built with PCRE support and use it if
  " available, in case a Pattern handler wants to use lookaround
  let l:pat = imp#pattern#FromPreferred(a:context, 'posix', a:symbol)
  if empty(l:pat)
    return []
  endif
  " -E extended regexp, -h no filename
  let l:args = ['-E', '-h', '--no-color', '--no-line-number']
  " git grep doesn't have multiline support
  if get(l:pat, 'ignorecase', 0)
    call add(l:args, '--ignore-case')
  else
    call add(l:args, '--no-ignore-case')
  endif
  for l:pattern in l:pat.patterns
    let l:args += ['-e', l:pattern]
  endfor
  " Final arguments to git grep are pathspecs; instead of having separate
  " arguments to specify file patterns and directory hierarchies we need to join
  " all preferred directories with all fileglobs to make a set of pathspecs.
  call add(l:args, '--')
  let l:dirs = imp#dir#PreferredLocations(a:context)
  for l:glob in get(l:pat, 'fileglobs', [])
    if empty(l:dirs)
      call add(l:args, ':(glob)**/' . l:glob)
    else
      for l:dir in l:dirs
        call add(l:args, printf(':(glob)%s/**/%s', l:dir, l:glob))
      endfor
    endif
  endfor
  return imp#pattern#ParseMatches(a:context, l:pat, a:symbol, s:runGrep(l:args))
endfunction

function! s:runGrep(args) abort
  let l:grep = imp#util#ArgsList(s:plugin.Flag('gitgrep[command]'),
        \ s:plugin.Flag('gitgrep[grep]'), s:plugin.Flag('gitgrep[args]'))
  let l:cmd = maktaba#syscall#Create(l:grep + a:args)
  call s:logger.Warn('Running command %s', l:cmd.GetCommand())
  let l:result = l:cmd.Call(0)
  " grep exit value is 0 if text is found, 1 if not found, 129 for other errors
  if v:shell_error && v:shell_error != 1
    call maktaba#error#Warn('Error running %s', l:cmd.GetCommand())
    if !empty(l:result.stderr)
      call maktaba#error#Warn(l:result.stderr)
    endif
    return []
  endif
  return split(l:result.stdout, '\r\?\n')
endfunction
