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

" This file defines Suggest handler tests for PHP imports based on the examples
" in the fixtures/php directory.  Suggest handler implementations which search
" the filesystem should define appropriate before_each and after_each methods,
" source this script, and then
" call PhpSuggestTests(s:suite, 'name#of#handler#Suggest')
" and if the Suggest handler supports multiline,
" call PhpMultiLineTests(s:suite, 'name#of#handler#Suggest')

if exists('g:_php_suggest_base')
  finish
endif
let g:_php_suggest_base = 1

let s:expect = themis#helper('expect')

function PhpSuggestTests(suite, suggestfunc) abort
  function a:suite.__php__() abort closure
    let l:child = themis#suite('php')

    function l:child.no_file_matches() abort closure
      exec 'edit' FixturePath('missing/dir/doesnotexist.php')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'E_ALL'])
      call s:expect(l:found).to_be_empty()
    endfunction

    function l:child.in_comments_and_strings() abort closure
      exec 'edit' FixturePath('php/empty.php')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'SHOULD_NOT_BE_FOUND'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'CONSTANT_NOTT_DEFINED'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'CONST_IN_STRING'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Renamed'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'should_not_be_found'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'func_in_string'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'AComment'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'InComment'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'AString'])
      call s:expect(l:found).to_be_empty()
    endfunction

    function l:child.const_imports() abort closure
      exec 'edit' FixturePath('php/empty.php')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'E_ALL'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('E_ALL', 'use const E_ALL;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Const1'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Const1', 'use const Ns\With\Constants\Const1;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'PHP_MAJOR'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'PHP_MAJOR_VERSION'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('PHP_MAJOR_VERSION', 'use const PHP_MAJOR_VERSION;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'PHP_MINOR_VERSION'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('PHP_MINOR_VERSION', 'use const PHP_MINOR_VERSION;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'PHP_RELEASE_VERSION'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('PHP_RELEASE_VERSION', 'use const PHP_RELEASE_VERSION;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'OtherName'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('OtherName', 'use const Ns\With\Constants\Renamed as OtherName;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Renamed'])
      call s:expect(l:found).to_be_empty()
    endfunction

    function l:child.function_imports() abort closure
      exec 'edit' FixturePath('php/empty.php')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'explode'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('explode', 'use function explode;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'getSession'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('getSession', 'use function getSession;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'array_replace_recursive'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('array_replace_recursive', 'use function array_replace_recursive;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'array_replace'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'pick'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('pick', 'use function array_rand as pick;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'array_rand'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'escapeshellcmd'])
      " nameToString doesn't preserve the leading backslash
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('escapeshellcmd', 'use function escapeshellcmd;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'SomeFunction'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('SomeFunction', 'use function Path\To\SomeFunction;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'some_function'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('some_function', 'use function Path\To\some_function;', {'count': 1})])
    endfunction

    function l:child.class_imports() abort closure
      exec 'edit' FixturePath('php/empty.php')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Exception'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Exception', 'use Exception;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Baz'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Baz', 'use Foo\Bar\Baz;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Qux'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Qux', 'use Foo\Bar\Qux;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Bar'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'TypeName'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('TypeName', 'use NS\With\ClassImports\Deeper\TypeName;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'OtherBaz'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('OtherBaz', 'use NS\With\ClassImports\Baz as OtherBaz;', {'count': 1})])
    endfunction

    function l:child.grouped_imports() abort closure
      exec 'edit' FixturePath('php/empty.php')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Number1'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Number1', 'use Comma\Group\Number1;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'No2'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('No2', 'use Comma\Group\Number2 as No2;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Number2'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'More'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('More', 'use Comma\Group\More;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Whatever'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Whatever', 'use Unrelated\Whatever;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'BraceGroupOne'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('BraceGroupOne', 'use Brace\Group\BG1 as BraceGroupOne;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'BG2'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('BG2', 'use Brace\Group\BG2;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'BG3'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('BG3', 'use Brace\Group\BG3;', {'count': 1})])
    endfunction

  endfunction
endfunction

function PhpMultiLineTests(suite, suggestfunc) abort
  function a:suite.__php_multiline__() abort closure
    let l:child = themis#suite('php_multiline')

    function l:child.multiline_grouped_imports() abort closure
      exec 'edit' FixturePath('php/empty.php')
      " let l:found = call(a:suggestfunc, [imp#NewContext(), 'Com1'])
      " call s:expect(l:found).to_equal(
      "       \ [imp#NewImport('Com1', 'use Multi\Line\Comma1 as Com1;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Comma2'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Comma2', 'use Multi\Line\Comma2;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Comma3'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Comma3', 'use Multi\Line\Comma3;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Brace1'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Brace1', 'use Multi\Line\Brace1;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Brace2'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Brace2', 'use function Multi\Line\Brace2;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Brace3'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Brace3', 'use const Multi\Line\Brace3;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'RenamedBraceFunc'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('RenamedBraceFunc', 'use function Multi\Line\BraceFunc as RenamedBraceFunc;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'RenamedBraceConst'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('RenamedBraceConst', 'use const Multi\Line\BraceConst as RenamedBraceConst;', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'BraceFunc'])
      call s:expect(l:found).to_be_empty()
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'BraceConst'])
      call s:expect(l:found).to_be_empty()
    endfunction

  endfunction
endfunction
