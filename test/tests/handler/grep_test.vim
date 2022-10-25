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

call themis#helper('command')
let s:expect = themis#helper('expect')
let s:suite = themis#suite('imp#handler#grep')

source <sfile>:h/_bzl_suggest_base.vim
call BzlSuggestTests(s:suite, 'imp#handler#grep#Suggest')
source <sfile>:h/_es6_suggest_base.vim
call Es6SuggestTests(s:suite, 'imp#handler#grep#Suggest')
" grep doesn't support multiline
source <sfile>:h/_java_suggest_base.vim
call JavaSuggestTests(s:suite, 'imp#handler#grep#Suggest')
source <sfile>:h/_kotlin_suggest_base.vim
call KotlinSuggestTests(s:suite, 'imp#handler#grep#Suggest')
source <sfile>:h/_php_suggest_base.vim
call PhpSuggestTests(s:suite, 'imp#handler#grep#Suggest')
source <sfile>:h/_python_suggest_base.vim
call PythonSuggestTests(s:suite, 'imp#handler#grep#Suggest')

function s:suite.before_each() abort
  if !imp#handler#grep#IsAvailable(imp#NewContext())
    Skip 'grep is not available'
  endif
  " Look one level up, in the test/fixtures dir
  Glaive imp Location[default]=parent parent[levels]=1
  " start with no buffers
  %bwipe!
endfunction

function s:suite.after_each() abort
  " get rid of all buffer changes
  %bwipe!
endfunction

function s:suite.no_filetype() abort
  let l:found = imp#handler#grep#Suggest(imp#NewContext(), 'List')
  call s:expect(l:found).to_be_empty()
endfunction

function s:suite.unsupported_filetype() abort
  exec 'edit' FixturePath('empty.pdf')
  let l:found = imp#handler#grep#Suggest(imp#NewContext(), 'List')
  call s:expect(l:found).to_be_empty()
endfunction
