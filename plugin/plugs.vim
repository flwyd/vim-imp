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

let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

""
" Suggest imports for the symbol under (or next to) the cursor. If you select
" one of the suggested imports, it will be inserted. See |:ImpSuggest|
noremap <Plug>(imp-suggest-current) :ImpSuggest<CR>
if has('patch-8.2.1978')
  inoremap <Plug>(imp-suggest-current) <Cmd>:ImpSuggest<CR>
else
  inoremap <Plug>(imp-suggest-current) <C-\><C-O>:ImpSuggest<CR>
endif

""
" Queries suggested imports for the symbol under (or next to) the cursor.
" Picks the first suggestion and inserts it. See |:ImpFirst|
noremap <Plug>(imp-first-current) :ImpFirst<CR>
if has('patch-8.2.1978')
  inoremap <Plug>(imp-first-current) <Cmd>:ImpFirst<CR>
else
  inoremap <Plug>(imp-first-current) <C-\><C-O>:ImpFirst<CR>
endif
