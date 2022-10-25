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
" Import suggester which prompts the user for a statement with just the import
" symbol as a suggestion. This is typically used as a fallback if other
" suggesters don't find a match.
function! imp#handler#prompt#Suggest(context, symbol) abort
  let l:statement = input(printf('Import for %s: ', a:symbol), a:symbol)
  return empty(l:statement) ? [] : [imp#NewImport(a:symbol, l:statement)]
endfunction
