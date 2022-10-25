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

" This file defines Suggest handler tests for Java imports based on the examples
" in the fixtures/java directory.  Suggest handler implementations which search
" the filesystem should define appropriate before_each and after_each methods,
" source this script, and then
" call JavaSuggestTests(s:suite, 'name#of#handler#Suggest')

if exists('g:_java_suggest_base')
  finish
endif
let g:_java_suggest_base = 1

let s:expect = themis#helper('expect')

function JavaSuggestTests(suite, suggestfunc) abort
  function a:suite.__java__() abort closure
    let l:child = themis#suite('java')

    function l:child.no_file_matches() abort closure
      exec 'edit' FixturePath('missing/dir/DoesNotExist.java')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'List'])
      call s:expect(l:found).to_be_empty()
    endfunction

    function l:child.static_imports() abort closure
      exec 'edit' FixturePath('java/Empty.java')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'copyOf'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('copyOf', 'import static java.util.List.copyOf;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'foo'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('foo', 'import static a.b.c.Stuff.foo;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'bar'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('bar', 'import static foo.Baz.bar;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'baz'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('baz', 'import static MyClass.baz;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'CONSTANT_VALUE'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('CONSTANT_VALUE', 'import static foo.bar.baz.MyClass.CONSTANT_VALUE;', {'count': 1})])
    endfunction

    function l:child.find_multiple_lists() abort closure
      exec 'edit' FixturePath('java/Empty.java')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'List'])
      " Matches are sorted by popularity; two classes import from java.util,
      " one from awt, but ignore 'import static java.util.List.copyOf'
      " and don't find the Python import of List, since filetype is java
      call s:expect(l:found).to_equal([
            \ imp#NewImport('List', 'import java.util.List;', {'count': 2}),
            \ imp#NewImport('List', 'import java.awt.List;', {'count': 1})])
    endfunction

  endfunction
endfunction
