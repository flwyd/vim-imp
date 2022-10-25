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

" This file defines Suggest handler tests for Kotlin imports based on the examples
" in the fixtures/kotlin directory.  Suggest handler implementations which search
" the filesystem should define appropriate before_each and after_each methods,
" source this script, and then
" call KotlinSuggestTests(s:suite, 'name#of#handler#Suggest')
"
" This test sets the filetype because runtime/filetype.vim didn't add Kotlin
" until Vim 8.2.0190

if exists('g:_kotlin_suggest_base')
  finish
endif
let g:_kotlin_suggest_base = 1

let s:expect = themis#helper('expect')

function KotlinSuggestTests(suite, suggestfunc) abort
  function a:suite.__kotlin__() abort closure
    let l:child = themis#suite('kotlin')

    function l:child.no_file_matches() abort closure
      exec 'edit' FixturePath('missing/dir/DoesNotExist.kt')
      exec 'setfiletype kotlin'
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'List'])
      call s:expect(l:found).to_be_empty()
    endfunction

    function l:child.basic_imports() abort closure
      exec 'edit' FixturePath('kotlin/Empty.kt')
      exec 'setfiletype kotlin'
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'MyClass'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('MyClass', 'import foo.bar.baz.sub.MyClass', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'baz'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('baz', 'import foo.baz', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'conflict'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('conflict', 'import foo.bar.conflict', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'CONSTANT_VALUE'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('CONSTANT_VALUE', 'import some.long.name.CONSTANT_VALUE', {'count': 1})])
    endfunction

    function l:child.aliased_imports() abort closure
      exec 'edit' FixturePath('kotlin/Empty.kt')
      exec 'setfiletype kotlin'
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'JavaList'])
      call s:expect(l:found).to_equal([
            \ imp#NewImport('JavaList', 'import java.util.List as JavaList', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'conflict_renamed'])
      call s:expect(l:found).to_equal([
            \ imp#NewImport('conflict_renamed', 'import bar.baz.conflict as conflict_renamed', {'count': 1})])
    endfunction

  endfunction
endfunction
