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

function! imp#handler#fzf#IsAvailable(context) abort
  return exists('*fzf#run')
endfunction

function! imp#handler#fzf#Pick(Continue, context, suggestions) abort
  if empty(maktaba#ensure#IsList(a:suggestions))
    call maktaba#function#Apply(a:Continue, [])
  endif
  let l:symbol = a:suggestions[0].symbol
  let l:statements = maktaba#function#Map(a:suggestions, {s -> s.statement})
  let l:options = printf('--multi --no-sort --prompt=%s',
        \ shellescape(l:symbol . '> '))
  let l:Sink = function('s:handleResults',
        \ [a:Continue, a:context, a:suggestions])
  call fzf#run(fzf#wrap(
        \ {'source': l:statements, 'sink*': l:Sink, 'options': l:options}))
endfunction

function! s:handleResults(Continue, context, suggestions, statements) abort
  " FZF operates on strings, so match FZF chosen with input suggestions
  let l:imports = {}
  for l:s in a:suggestions
    let l:imports[l:s.statement] = l:s
  endfor
  let l:choices = []
  for l:statement in a:statements
    if has_key(l:imports, l:statement)
      let l:choices += [l:imports[l:statement]]
    else
      let l:choices += [imp#NewImport(l:statement, l:statement)]
    endif
  endfor
  call maktaba#function#Apply(a:Continue, l:choices)
endfunction
