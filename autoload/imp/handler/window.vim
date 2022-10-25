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

function! imp#handler#window#IsAvailable(context) abort
  return has('timers') && exists('*maktaba#ui#selector#Create')
endfunction

function! imp#handler#window#Pick(Done, context, suggestions) abort
  if empty(maktaba#ensure#IsList(a:suggestions))
    call maktaba#function#Call(a:Done, [])
  endif
  let l:symbol = a:suggestions[0].symbol
  let l:items = maktaba#function#Map(a:suggestions, {i -> [i.statement, i]})
  let l:listener = {'Done': a:Done, 'choices': {}, 'matchids': {}}
  let l:listener.Select = maktaba#function#Create(
        \ function('s:selectCallback'), [], l:listener)
  let l:listener.Remove = maktaba#function#Create(
        \ function('s:removeCallback'), [], l:listener)
  let l:listener.Toggle = maktaba#function#Create(
        \ function('s:toggleCallback'), [], l:listener)
  let l:keys = {
        \ '<CR>': [l:listener.Select, 'Close',
              \ 'Insert statement and previous choices'],
        \ 'a': [l:listener.Select, 'NoOp', 'Add statement to choices'],
        \ 'd': [l:listener.Remove, 'NoOp', 'Remove statement from choices'],
        \ 'x': [l:listener.Toggle, 'NoOp', 'Toggle statement choice'],
        \ 'q': ['imp#util#AlwaysFalse', 'Close', 'Insert all choices'],
        \ }
  let l:selector = maktaba#ui#selector#Create(l:items)
        \ .WithMappings(l:keys)
        \ .WithExtraOptions(function('s:windowOptions', [l:listener]))
        \ .WithName('import ' . l:symbol)
  call l:selector.Show()
endfunction

function! s:selectCallback(line, import) abort dict
  let self.choices[a:line] = a:import
  if !get(self.matchids, a:line, 0)
    let self.matchids[a:line] = matchadd('Todo', '\V' . escape(a:line, '\'))
  endif
endfunction

function! s:removeCallback(line, import) abort dict
  if has_key(self.choices, a:line)
    unlet self.choices[a:line]
  endif
  if get(self.matchids, a:line, 0)
    call matchdelete(self.matchids[a:line])
    let self.matchids[a:line] = 0
  endif
endfunction

function! s:toggleCallback(line, import) abort dict
  if has_key(self.choices, a:line)
    call maktaba#function#Apply(self.Remove, a:line, a:import)
  else
    call maktaba#function#Apply(self.Select, a:line, a:import)
  endif
endfunction

" Need to call the continuation callback even if the user closes the buffer
" with :q which doesn't trigger an action callback, so listen to buffer delete
" events (fortunately Selector sets bufhidden=delete). This is triggered after
" a 0ms delay via timer_start because Selector closes the window before
" calling the action callback, but the <CR> action adds to choices, which
" needs to be included in the arg to the continuation callback.
" Also, without an async call, if any function along the continuation chain
" opens a new window (e.g. picking a second import), Vim will barf since the
" original buffer hasn't been deleted until after the BufDelete event
" listeners finish.
function! s:windowOptions(listener) abort
  function! s:WindowOptions_Quit() abort closure
    call timer_start(0,
          \ {_ -> maktaba#function#Apply(
            \ a:listener.Done, values(a:listener.choices))})
  endfunction
  autocmd BufDelete <buffer> call s:WindowOptions_Quit()
endfunction



