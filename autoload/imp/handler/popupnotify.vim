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

function! imp#handler#popupnotify#IsAvailable(context) abort
  " TODO add a flag to use this even if timers is disabled (manually dismiss)
  return has('timers') && exists('*popup_notification')
endfunction

function! imp#handler#popupnotify#Report(context, imported, already) abort
  if empty(a:imported) && empty(a:already)
    let l:lines = ['No imports chosen']
    let l:result = 0
  else
    let l:lines = maktaba#function#Map(a:imported, {i -> i.statement})
    if !empty(a:context.already_imported)
      let l:already = maktaba#function#Map(
            \ a:context.already_imported, {i -> i.symbol})
      let l:lines += ['Already imported: ' . join(l:already, ' ')]
    endif
    let l:result = 1
  endif
  let l:minwidth = 10
  let l:width = max([l:minwidth,
        \ max(maktaba#function#Map(l:lines, {x -> len(x)}))])
  call popup_notification(l:lines, s:options(l:width, len(l:lines)))
  return l:result
endfunction

function! s:options(width, height) abort
  let l:pos = s:plugin.Flag('popupnotify[position]')
  if l:pos =~? 'top'
    let l:row = 1
  elseif l:pos =~? 'bottom'
    let l:row = &lines - a:height - 1
  else
    let l:row = max([1, (&lines - a:height - 1) / 2])
  endif
  if l:pos =~? 'left'
    let l:col = 1
  elseif l:pos =~? 'right'
    let l:col = max([1, &columns - a:width - 1])
  else
    let l:col = max([1, (&columns - a:width - 1) / 2])
  endif
  let l:time = s:plugin.Flag('popupnotify[time]')
  return {'line': l:row, 'col': l:col, 'minwidth': 10, 'time': l:time}
endfunction
