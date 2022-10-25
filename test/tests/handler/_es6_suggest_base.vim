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

" This file defines Suggest handler tests for ES6 imports based on the examples
" in the fixtures/es6 directory.  Suggest handler implementations which search
" the filesystem should define appropriate before_each and after_each methods,
" source this script, and then
" call Es6SuggestTests(s:suite, 'name#of#handler#Suggest')
" and also call the Es6MultiLineTests function if the handler supports multiline
" searches.

if exists('g:_es6_suggest_base')
  finish
endif
let g:_es6_suggest_base = 1

call themis#helper('command')
let s:expect = themis#helper('expect')

" *** SINGLE LINE TESTS ***
function Es6SuggestTests(suite, suggestfunc) abort
  function a:suite.__es6__() abort closure
    let l:child = themis#suite('es6')
    function l:child.before_each() abort
      exec 'edit' FixturePath('es6/empty.js')
    endfunction

    function l:child.named() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'banana'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('banana', 'import {banana} from "fruit.js";', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'uk'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('uk', "import {britain as uk} from 'countries.ts';", {'count': 1})])
      " only alias should match, not original
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'britain'])
      call s:expect(l:found).to_be_empty()
    endfunction

    function l:child.default() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Default'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Default', "import Default from 'just-default.js';", {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'DefaultTs'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('DefaultTs', 'import DefaultTs from "just-default.ts";', {'count': 1})])
    endfunction

    function l:child.wildcard() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Wildcard'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Wildcard', "import * as Wildcard from 'just-wildcard.js';", {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'WildcardTs'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('WildcardTs', "import * as WildcardTs from 'just-wildcard.ts';", {'count': 1})])
      Skip 'TODO support $ in ES6 identifiers'
      " This line is 'import $Default, * as wildcard ..."
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'wildcard'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('wildcard', 'import * as wildcard from "default-and-widlcard.js";', {'count': 1})])
      " This identifier has a $ in it
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'wildcard$'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('wildcard$', "import * as wildcard$ from 'dtfault-and-widlcard.ts';", {'count': 1})])
    endfunction

    function l:child.find_js_and_ts() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'apple'])
      call sort(l:found, {x, y -> len(x.statement) - len(y.statement)})
      call s:expect(l:found).to_equal([
            \ imp#NewImport('apple', "import apple from 'os.ts';", {'count': 1}),
            \ imp#NewImport('apple', 'import {apple} from "fruit.js";', {'count': 1}),
            \ ])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'congo'])
      call sort(l:found, {x, y -> len(x.statement) - len(y.statement)})
      call s:expect(l:found).to_equal([
            \ imp#NewImport('congo', "import {congo} from 'countries.ts';", {'count': 1}),
            \ imp#NewImport('congo', "import * as congo from 'the-jungle.js';", {'count': 1}),
            \ ])
    endfunction

    function l:child.dollar_sign_identifier() abort closure
      Skip 'TODO Support $ in ES6 identifiers'
      let l:found = call(a:suggestfunc, [imp#NewContext(), '$Default'])
      call sort(l:found, {x, y -> len(x.statement) - len(y.statement)})
      call s:expect(l:found).to_equal([
            \ imp#NewImport('$Default', "import $Default from 'default-and-named.ts';", {'count': 1}),
            \ imp#NewImport('$Default', "import $Default from 'default-and-wildcard.js';", {'count': 1}),
            \ ])
    endfunction

    function l:child.ignore_renamed_and_dynamic() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'a'])
      call sort(l:found, {x, y -> len(x.statement) - len(y.statement)})
      call s:expect(l:found).to_be_empty()
    endfunction

  endfunction
endfunction

" *** MULTI LINE TESTS ***
function Es6MultiLineTests(suite, suggestfunc) abort
  function a:suite.__es6_multiline__() abort closure
    let l:child = themis#suite('es6_multiline')
    function l:child.before_each() abort
      exec 'edit' FixturePath('es6/empty.js')
    endfunction

    function l:child.multiline_named() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'multi_start'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('multi_start', 'import {multi_start} from "multi/start-end.js";', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'multi_end'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('multi_end', 'import {multi_end} from "multi/start-end.js";', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'multi_a'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('multi_a', 'import {a as multi_a} from "multi/named.js";', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'multi_c'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('multi_c', 'import {multi_c} from "multi/named.js";', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'multiline_y'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('multiline_y', 'import {multiline_y} from "multi/left-aligned.js";', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'multiline_z'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('multiline_z', 'import {multiline_z} from "multi/left-aligned.js";', {'count': 1})])
    endfunction

    function l:child.multiline_multiple_occurrences() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'multiline_default'])
      call sort(l:found, {x, y -> len(x.statement) - len(y.statement)})
      call s:expect(l:found).to_equal([
            \ imp#NewImport('multiline_default', 'import multiline_default from "multi/default.js";', {'count': 1}),
            \ imp#NewImport('multiline_default', 'import multiline_default from "multi/left-aligned.js";', {'count': 1}),
            \ ])
    endfunction

  endfunction
endfunction
