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

""
" 'top' is an inserter implementation which inserts import statements at the
" beginning of the file. If 'position' is present in the context, it will
" append after that line, then sets position to the next line so that multiple
" import operations with the same context are added in order. If 'position' is
" not in context, inserts the statement prior to the first line of the buffer,
" or after the first line if the file starts with a #! line.
function! imp#handler#top#Insert(context, imports) abort
  " TODO check if the statement is already present
  let l:position = get(a:context, 'position', 0)
  if l:position == 0 && maktaba#string#StartsWith(getline(1), '#!')
    let l:position = 1
  endif
  for l:import in a:imports
    let l:lines = split(l:import.statement, "\n")
    call append(l:position, l:lines)
    let l:position += len(l:lines)
  endfor
  " If adding several statements in one command, insert in order, not reversed
  let a:context.position = l:position
  let a:context.imported += a:imports
  return 1
endfunction
