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

" This file defines Suggest handler tests for Bazel Build imports based on the
" examples in the fixtures/bzl directory.  Suggest handler implementations which
" search the filesystem should define appropriate before_each and after_each
" methods, source this script, and then
" call BzlSuggestTests(s:suite, 'name#of#handler#Suggest')
" as well as BzlMultiLineTests if the handler supports multiline.

if exists('g:_bzl_suggest_base')
  finish
endif
let g:_bzl_suggest_base = 1

let s:expect = themis#helper('expect')

" *** Single line import tests ***
function BzlSuggestTests(suite, suggestfunc) abort
  function a:suite.__bzl__() abort closure
    let l:child = themis#suite('bzl')

    function l:child.simple_load() abort closure
      exec 'edit' FixturePath('bzl/empty.bzl')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'one_rule'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('one_rule', 'load("//path/to:rules.bzl", "one_rule")', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'bar'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('bar', 'load("//path/to:more_rules", "bar")', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'baz'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('baz', 'load("//path/to:more_rules", "baz")', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'bar_library'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('bar_library', 'load("@repo//my/rules:foo.bzl", "bar_library")', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'baz_library'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('baz_library', 'load("@repo//my/rules:foo.bzl", "baz_library")', {'count': 1})])
    endfunction

    function l:child.renamed_imports() abort closure
      exec 'edit' FixturePath('bzl/empty.bzl')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'foo_lib'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('foo_lib', 'load("@repo//somewhere:stuff", foo_lib = "foo")', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'normal'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('normal', 'load("@repo//somewhere:stuff", "normal")', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'renamed'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('renamed', 'load("@repo//somewhere:stuff", renamed = "_rename_me")', {'count': 1})])
    endfunction

  endfunction
endfunction

" *** Multi-lline import tests ***
function BzlMultiLineTests(suite, suggestfunc) abort
  function a:suite.__bzl_multiline__() abort closure
    let l:child = themis#suite('bzl_multiline')

    function l:child.target_on_initial_line() abort closure
      exec 'edit' FixturePath('bzl/empty.bzl')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'initial_line'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('initial_line', 'load("//initial:rules", "initial_line")', {'count': 1})])
    endfunction

    function l:child.each_on_own_line() abort closure
      exec 'edit' FixturePath('bzl/empty.bzl')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'apple'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('apple', 'load("@repo//everything/on/its/own:line.bzl", "apple")', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'cavendish'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('cavendish', 'load("@repo//everything/on/its/own:line.bzl", cavendish = "banana")', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'cherry'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('cherry', 'load("@repo//everything/on/its/own:line.bzl", "cherry")', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'durian'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('durian', 'load("@repo//everything/on/its/own:line.bzl", "durian")', {'count': 1})])
    endfunction

  endfunction
endfunction
