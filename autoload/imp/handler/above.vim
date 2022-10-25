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
" 'above' is an inserter implementation which inserts import statements on the
" line before the cursor position.
function! imp#handler#above#Insert(context, imports) abort
  for l:import in a:imports
    let l:lines = split(l:import.statement, "\n")
    call append(line('.') - 1, l:lines)
  endfor
  let a:context.imported += a:imports
  return 1
endfunction
