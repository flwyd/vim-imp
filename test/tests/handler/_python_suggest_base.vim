" This file defines Suggest handler tests for Python imports based on the
" examples in the fixtures/python directory.  Suggest handler implementations
" which search the filesystem should define appropriate before_each and
" after_each methods, source this script, and then
" call PythonSuggestTests(s:suite, 'name#of#handler#Suggest')

if exists('g:_python_suggest_base')
  finish
endif
let g:_python_suggest_base = 1

let s:expect = themis#helper('expect')

function PythonSuggestTests(suite, suggestfunc) abort
  function a:suite.__python__() abort closure
    let l:child = themis#suite('python')
    function l:child.before_each() abort
      exec 'edit' FixturePath('python/empty.py')
    endfunction

    function l:child.no_file_matches() abort closure
      exec 'edit' FixturePath('missing/dir/does_not_exist.py')
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'os'])
      call s:expect(l:found).to_be_empty()
    endfunction

    function l:child.base_module() abort closure
      for l:module in ['io', 're', 'os', 'sys', 'time']
        let l:found = call(a:suggestfunc, [imp#NewContext(), l:module])
        call s:expect(l:found).to_equal(
              \ [imp#NewImport(l:module, 'import ' . l:module, {'count': 1})])
      endfor
    endfunction

    function l:child.child_module() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'os.path'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('os.path', 'import os.path', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'test.support'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('test.support', 'import test.support', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'unittest.mock'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('unittest.mock', 'import unittest.mock', {'count': 1})])
    endfunction

    function l:child.from_future() abort closure
      for l:feature in ['print_function', 'division', 'unicode_literals']
        let l:found = call(a:suggestfunc, [imp#NewContext(), l:feature])
        call s:expect(l:found).to_equal(
              \ [imp#NewImport(l:feature, 'from __future__ import ' . l:feature, {'count': 1})])
      endfor
    endfunction

    function l:child.from_base_module() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'List'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('List', 'from typing import List', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'path'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('path', 'from os import path', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'environ'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('environ', 'from os import environ', {'count': 1})])
    endfunction

    function l:child.from_child_module() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'Collection'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('Collection', 'from collections.abc import Collection', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'NO_VALUES'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('NO_VALUES', 'from jedi.inference.base_value import NO_VALUES', {'count': 1})])
      for l:sym in ['run_unittest', 'requires', 'TESTFN']
        let l:found = call(a:suggestfunc, [imp#NewContext(), l:sym])
        call s:expect(l:found).to_equal(
              \ [imp#NewImport(l:sym, 'from test.support import ' . l:sym, {'count': 1})])
      endfor
      for [l:fruit, l:alias] in items({'apple': 'a', 'banana': 'b', 'cherry': 'c', 'durian': 'd'})
        let l:found = call(a:suggestfunc, [imp#NewContext(), l:alias])
        call s:expect(l:found).to_equal(
              \ [imp#NewImport(l:alias, printf('from fruit.tree import %s as %s', l:fruit, l:alias), {'count': 1})])
      endfor
    endfunction

    function l:child.aliases() abort closure
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'tk'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('tk', 'import tkinter as tk', {'count': 1})])
      let l:found = call(a:suggestfunc, [imp#NewContext(), 'test_utils'])
      call s:expect(l:found).to_equal(
            \ [imp#NewImport('test_utils', 'from test.test_asyncio import utils as test_utils', {'count': 1})])
    endfunction

  endfunction
endfunction
