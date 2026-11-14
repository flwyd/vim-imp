" Copyright 2026 Trevor Stone
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"     http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.

" This file defines Suggest handler tests for Rust imports based on the examples
" in the fixtures/rust directory.  Suggest handler implementations which search
" the filesystem should define appropriate before_each and after_each methods,
" source this script, and then
" call RustSuggestTests(s:suite, 'name#of#handler#Suggest')
" and also call the RustMultiLineTests function if the handler supports
" multiline searches.

if exists('g:_rust_suggest_base')
  finish
endif
let g:_rust_suggest_base = 1

call themis#helper('command')
let s:expect = themis#helper('expect')

" *** SINGLE LINE TESTS ***
function RustSuggestTests(suite, suggestfunc) abort
  function a:suite.__rust_single__() abort closure
    let l:child = themis#suite('rust')
    function l:child.before_each() abort
      exec 'edit' FixturePath('rust/empty.rs')
    endfunction

    function l:child.basic() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Denver'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Denver', 'use us::co::denver::Denver;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Longmont'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Longmont', 'use us::co::boulder::Longmont;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Reno'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Reno', 'use us::nv::washoe::Reno;')])
      " us::co::jefferson::self isn't imported, so just us::mt::jefferson
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'jefferson'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('jefferson', 'use us::mt::jefferson;')])
      " Partially qualified; boulder::Lafayette won't match with group inside
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'lafayette::Lafayette'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('lafayette::Lafayette', 'use us::la::lafayette::Lafayette;')])
      " Nested as us::ut::{iron::CedarCity, washington::StGeorge}
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'CedarCity'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('CedarCity', 'use us::ut::iron::CedarCity;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'StGeorge'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('StGeorge', 'use us::ut::washington::StGeorge;')])
    endfunction

    function l:child.alias() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Joe'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Joe', 'use us::mt::custer::Ismay as Joe;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'LasVegas'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('LasVegas', 'use us::nv::clark::LasVegas;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'LasVegasNM'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('LasVegasNM', 'use us::nm::san_miguel::LasVegas as LasVegasNM;')])
    endfunction

    function l:child.case_sensitive() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'kiowa'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('kiowa', 'use us::co::kiowa;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Kiowa'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Kiowa', 'use us::co::elbert::Kiowa;')])
    endfunction

    function l:child.nested_self() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'boulder'])
      call s:expect(l:found).to_equal(
            \[imp#NewImport('boulder', 'use us::co::boulder;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'clark'])
      call s:expect(l:found).to_equal(
            \[imp#NewImport('clark', 'use us::nv::clark;')])
      " shouldn't find us::co::san_miguel::Telluride
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'san_miguel'])
      call s:expect(l:found).to_equal(
            \[imp#NewImport('san_miguel', 'use us::nm::san_miguel;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'san_miguel'])
      call s:expect(l:found).to_equal(
            \[imp#NewImport('san_miguel', 'use us::nm::san_miguel;')])
    endfunction

    function l:child.multiple_results() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Evergreen'])
      call sort(l:found, function('s:compareImports'))
      call s:expect(l:found).to_equal([
            \ imp#NewImport('Evergreen', 'use us::co::jefferson::Evergreen;'),
            \ imp#NewImport('Evergreen', 'use us::la::avoyelles::Evergreen;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Lafayette'])
      call sort(l:found, function('s:compareImports'))
      call s:expect(l:found).to_equal([
            \ imp#NewImport('Lafayette', 'use us::co::boulder::Lafayette;'),
            \ imp#NewImport('Lafayette', 'use us::la::lafayette::Lafayette;')])
      " but no match for BoulderCity or us::co::boulder::self
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Boulder'])
      call sort(l:found, function('s:compareImports'))
      call s:expect(l:found).to_equal([
            \ imp#NewImport('Boulder', 'use us::co::boulder::Boulder;'),
            \ imp#NewImport('Boulder', 'use us::mt::jefferson::Boulder;')])
    endfunction

    function l:child.wildcards() abort closure
      " Does not match wildcard::alone::*
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'alone'])
      call s:expect(l:found).to_equal([])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'with_self'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('with_self', 'use wildcard::with_self;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Card'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Card', 'use wildcard::with_others::Card;')])
    endfunction

    function l:child.no_match() abort closure
      " No 'use us;' or 'use us::self;'
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'us'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'nv'])
      call s:expect(l:found).to_be_empty()
      " us::co::denver::Denver but not us::co::denver
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'denver'])
      call s:expect(l:found).to_be_empty()
      " aliased to Joe, Montana
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Ismay'])
      call s:expect(l:found).to_be_empty()
      " Prefix, but not a full identifier
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Las'])
      call s:expect(l:found).to_be_empty()
      " us::ct::fairfield::Bridgeport is commented out
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Bridgeport'])
      call s:expect(l:found).to_be_empty()
    endfunction

  endfunction
endfunction

" *** MULTI LINE TESTS ***
function RustMultiLineTests(suite, suggestfunc) abort
  function a:suite.__rust_multiline__() abort closure
    let l:child = themis#suite('rust_multiline')
    function l:child.before_each() abort
      exec 'edit' FixturePath('rust/empty.rs')
    endfunction

    function l:child.multiline_ToRead() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'ToRead'])
      call sort(l:found, function('s:compareImports'))
      call s:expect(l:found).to_equal([
            \ imp#NewImport('ToRead', 'use multi::line::hard::ToRead;'),
            \ imp#NewImport('ToRead', 'use multi::line::mixed::okay::ToRead;'),
            \ imp#NewImport('ToRead', 'use multi::line::module::easy::ToRead;')])
    endfunction

    function l:child.multiline_alias() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'multi_line_alias'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('multi_line_alias', 'use multi::line::self as multi_line_alias;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Surprising'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Surprising', 'use multi::line::nested::ToRead as Surprising;')])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Okay'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Okay', 'use multi::line::nested::ToGrep as Okay;')])
    endfunction

  endfunction
endfunction

function! s:compareImports(a, b) abort
  if a:a.statement ==# a:b.statement
    return 0
  endif
  return a:a.statement < a:b.statement ? -1 : 1
endfunction
