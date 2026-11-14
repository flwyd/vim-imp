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

let s:suite = themis#suite('imp#util')
let s:expect = themis#helper('expect')
" TODO add tests for other imp#util functions

function s:suite.AlwaysFalse() abort
  call assert_false(imp#util#AlwaysFalse(), 'no args')
  call assert_false(imp#util#AlwaysFalse(0), 'false arg')
  call assert_false(imp#util#AlwaysFalse(1), 'true arg')
  call assert_false(imp#util#AlwaysFalse([]), 'empty arg')
  call assert_false(imp#util#AlwaysFalse('x', 'y'), 'multiple args')
endfunction

function s:suite.CompareLists() abort
  call s:expect(imp#util#CompareLists('imp#util#Cmp',
        \ ['apple', 'cucumber', 'durian', 'banana'],
        \ ['apple', 'cucumber', 'durian', 'banana'])).to_equal(0)
  call s:expect(imp#util#CompareLists('imp#util#Cmp',
        \ ['apple', 'cucumber', 'durian', 'banana'],
        \ ['apple', 'durian', 'cucumber', 'banana'])).to_be_less_than(0)
  call s:expect(imp#util#CompareLists('imp#util#Cmp',
        \ ['apple', 'durian', 'cucumber', 'banana'],
        \ ['apple', 'cucumber', 'durian', 'banana'])).to_be_greater_than(0)
  call s:expect(imp#util#CompareLists('imp#util#Cmp',
        \ ['apple', 'banana', 'cucumber', 'durian'],
        \ ['apple', 'banana', 'cucumber'])).to_be_greater_than(0)
  let l:ByLength = {a, b -> len(a) - len(b)}
  call s:expect(imp#util#CompareLists(l:ByLength,
        \ ['durian', 'banana', 'apple', 'cucumber'],
        \ ['banana', 'durian', 'apple', 'cucumber'])).to_equal(0)
  call s:expect(imp#util#CompareLists(l:ByLength,
        \ ['cucumber', 'apple', 'banana', 'durian'],
        \ ['durian', 'apple', 'banana', 'cucumber'])).to_be_greater_than(0)
  call s:expect(imp#util#CompareLists(l:ByLength,
        \ ['banana', 'cucumber', 'durian'],
        \ ['apple juice', 'cucumber', 'durian'])).to_be_less_than(0)
  call s:expect(imp#util#CompareLists(l:ByLength,
        \ ['cucumber', 'apple', 'banana', 'durian'],
        \ ['durian', 'apple', 'banana', 'cucumber'])).to_be_greater_than(0)
  call s:expect(imp#util#CompareLists(l:ByLength,
        \ ['durian', 'banana', 'apple', 'cucumber'],
        \ ['banana', 'durian', 'apple', 'cucumber', 'eggplant'])).to_be_less_than(0)
endfunction

function s:suite.Intersection() abort
  call assert_equal([], imp#util#Intersection([], []), 'empty lists')
  call assert_equal([], imp#util#Intersection([], ['x']), 'empty and nonempty')
  call assert_equal([], imp#util#Intersection(['x'], []), 'empty and nonempty')
  call assert_equal(['x'], imp#util#Intersection(['x'], ['x']), 'equal single')
  call assert_equal([], imp#util#Intersection(['x'], ['y']), 'no match single')
  call assert_equal(['x', 'y'], imp#util#Intersection(['x', 'y'], ['y', 'x']),
        \ 'equal different order')
  call assert_equal(['x', 'z'],
        \ imp#util#Intersection(['x', 'y', 'z'], ['z', 'x']),
        \ 'first is superset')
  call assert_equal(['x', 'z'],
        \ imp#util#Intersection(['x', 'z'], ['z', 'y', 'x']),
        \ 'first is subset')
  call assert_equal(['x'],
        \ imp#util#Intersection(['a', 'b', 'c', 'x'], ['x', 'y', 'z']),
        \ 'overlapping')
  call assert_equal([0, 2, 4],
        \ imp#util#Intersection(range(0, 5), range(0, 6, 2)), 'numbers')
  call assert_equal([],
        \ imp#util#Intersection(range(0, 5), ['0', '2','4']), 'type mismatch')
  call assert_equal([['foo', 42], [137, 6.28, 'baz']], imp#util#Intersection(
        \ [['foo', 42], ['bar', 1, 2, 3], [137, 6.28,'baz'], []],
        \ [['bar', 1, 2], [137, 6.28, 'baz'], [[]], ['foo', 42]]),
        \ 'list of lists')
  call assert_equal([{'a': 1, 'b': 2}], imp#util#Intersection(
        \ [{'x': 5, 'y': 6}, {'a': 1, 'b': 2}],
        \ [{'a': 1, 'b': 2}, {'x': 5, 'y': 6, 'z': 7}]), 'dicts')
  let l:a = ['a', 'b', 'c', 'm', 'n', 'o']
  let l:b = ['z', 'y', 'x', 'o', 'n', 'm']
  call assert_equal(['m', 'n', 'o'], imp#util#Intersection(l:a, l:b), 'long')
  call assert_equal(['a', 'b', 'c', 'm', 'n', 'o'], l:a,
        \ "don't modify first arg")
  call assert_equal(['z', 'y', 'x', 'o', 'n', 'm'], l:b,
        \ "don't modify second arg")
endfunction

function s:suite.SharedPrefix() abort
  call assert_equal('', imp#util#SharedPrefix('foo', ''), 'empty string')
  call assert_equal('', imp#util#SharedPrefix('foo', 'bar'), 'no shared prefix string')
  call assert_equal('foo', imp#util#SharedPrefix('food', 'foo'), 'full prefix string')
  call assert_equal('foo', imp#util#SharedPrefix('food', 'footloose'), 'shared prefix string')
  call assert_equal('food', imp#util#SharedPrefix('food', 'food'), 'equal string')
  call assert_equal('F', imp#util#SharedPrefix('Foo', 'FOO'), 'case sensitive string')
  call assert_equal([], imp#util#SharedPrefix([], ['foo']), 'empty list')
  call assert_equal([], imp#util#SharedPrefix(['foo'], ['bar']), 'no shared prefix list')
  call assert_equal(['foo'], imp#util#SharedPrefix(['foo'], ['foo', 'bar']), 'full prefix list')
  call assert_equal(['foo'], imp#util#SharedPrefix(['foo', 'bar'], ['foo']), 'full prefix list')
  call assert_equal([54, 46], imp#util#SharedPrefix([54, 46, 42], [54, 46, 65]), 'shared prefix numbers list')
  call assert_equal(['foo', 'BAR'], imp#util#SharedPrefix(['foo', 'BAR', 'baz'], ['foo', 'BAR', 'BAZ']), 'case sensitive list')
endfunction

function s:suite.SharedSuffix() abort
  call assert_equal('', imp#util#SharedSuffix('foo', ''), 'empty string')
  call assert_equal('', imp#util#SharedSuffix('', 'foo'), 'empty string')
  call assert_equal('', imp#util#SharedSuffix('food', 'foo'), 'different ending strings')
  call assert_equal('foo', imp#util#SharedSuffix('foo', 'foo'), 'equal string')
  call assert_equal('oon', imp#util#SharedSuffix('cocoon', 'spoon'), 'shared string')
  call assert_equal('on', imp#util#SharedSuffix('cocoon', 'SPOon'), 'shared string with case')
  call assert_equal('', imp#util#SharedSuffix('cocoon', 'SPOON'), 'case sensitive string')
  call assert_equal([], imp#util#SharedSuffix(['foo'], []), 'empty list')
  call assert_equal([], imp#util#SharedSuffix([], ['foo']), 'empty list')
  call assert_equal([], imp#util#SharedSuffix([3, 2, 1, 0], [3, 2, 1]), 'different ending lists')
  call assert_equal(['apple'], imp#util#SharedSuffix(['apple'], ['apple']), 'equal list')
  call assert_equal(['banana', 'cherry'], imp#util#SharedSuffix(['banana', 'cherry'], ['banana', 'cherry']), 'equal list')
  call assert_equal(['banana', 'cherry', 'durian'], imp#util#SharedSuffix(
        \ ['apple', 'banana', 'cherry', 'durian'],
        \ ['apricot', 'banana', 'cherry', 'durian']), 'shared list')
  call assert_equal(['durian'], imp#util#SharedSuffix(
        \ ['apple', 'banana', 'cherry', 'durian'],
        \ ['apple', 'banana', 'CHERRY', 'durian']), 'shared list with case')
  call assert_equal([], imp#util#SharedSuffix(
        \ ['apple', 'banana', 'cherry', 'DURIAN'],
        \ ['apple', 'banana', 'cherry', 'durian']), 'empty list with case')
endfunction

" TODO test the other functions
