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

function! imp#handler#echo#Report(context, imported, already) abort
  if empty(a:imported) && empty(a:already)
    echo 'No imports chosen'
    return 0
  endif
  " Redraw first because added imports may trigger a redraw when the command
  " is done which will clear the echo area.
  redraw
  let l:lines = maktaba#function#Map(a:imported, {i -> i.statement})
  if !empty(a:context.already_imported)
    let l:already = maktaba#function#Map(
          \ a:context.already_imported, {i -> i.symbol})
    let l:lines += ['Already imported: ' . join(l:already, ' ')]
  endif
  echo join(l:lines, "\n")
  return 1
endfunction
