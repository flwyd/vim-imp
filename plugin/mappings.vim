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
" @section Mappings, mappings
" @plugin(stylized) provides default normal-mode mappings that can be enabled
" with the plugin[mappings] flag, for example by |Glaive|: >
"   Glaive @plugin(name) plugin[mappings]
" <
" which will use |<leader>|i as a prefix by default. Set plugin[mappings]=_
" to use a different prefix.
"
" `\ii` suggests imports for the symbol under (or next to) the cursor. If you
" select one of the suggested imports, it will be inserted. See
" @command(ImpSuggest). This is also available as `<Plug>(imp-suggest-current)`.
"
" `\if` queries suggested imports for the symbol under (or next to) the cursor.
" Picks the first suggestion and inserts it. See @command(ImpFirst). This is
" also available as `<Plug>(imp-first-current)`.
"
" This plugin does not provide any insert-mode mappings, but consider adding
" one for a keystroke of your choice to add an import for the symbol you just
" typed, without disrupting editing flow: >
"   inoremap <C-X><C-X> <Plug>(imp-suggest-current)
"   inoremap <F3> <Plug>(imp-first-current)
" <

let s:prefix = s:plugin.MapPrefix('i')

""
" Suggest imports for the symbol under (or next to) the cursor. If you select
" one of the suggested imports, it will be inserted. See |:ImpSuggest|
execute 'nnoremap <unique> <silent> ' . s:prefix . 'i' ':ImpSuggest<CR>'

""
" Queries suggested imports for the symbol under (or next to) the cursor.
" Picks the first suggestion and inserts it. See |:ImpFirst|
execute 'nnoremap <unique> <silent> ' . s:prefix . 'f' ':ImpFirst<CR>'
