let s:suite = themis#suite('imp#util')
" TODO add tests for other imp#util functions

function s:suite.AlwaysFalse() abort
  call assert_false(imp#util#AlwaysFalse(), 'no args')
  call assert_false(imp#util#AlwaysFalse(0), 'false arg')
  call assert_false(imp#util#AlwaysFalse(1), 'true arg')
  call assert_false(imp#util#AlwaysFalse([]), 'empty arg')
  call assert_false(imp#util#AlwaysFalse('x', 'y'), 'multiple args')
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

" TODO test the other functions
