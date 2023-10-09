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

let s:expect = themis#helper('expect')
let s:suite = themis#suite('imp#re#Pattern')

" TODO move this to a common spot
function ExpectThrows(ActualFunc, expectedPattern) abort
  try
    call a:ActualFunc()
    return 0 " did not throw
  catch
    return v:exception =~# a:expectedPattern
  endtry
endfunction
call themis#helper#expect#define_matcher('to_throw', function('ExpectThrows'))

function s:suite.simple_literal() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('hello'), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('hello').to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^hello$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^hello$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^hello$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^hello$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^hello$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^hello$')
endfunction

function s:suite.escaped_literal() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('($5.99 + 3)*$2?'), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('($5.99 + 3)*$2?').to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^(\$5\.99 + 3)\*\$2?$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^\(\$5\.99 \+ 3\)\*\$2\?$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^\(\$5\.99 \+ 3\)\*\$2\?$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^\(\$5\.99 \+ 3\)\*\$2\?$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^\(\$5\.99 \+ 3\)\*\$2\?$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^\(\$5\.99 \+ 3\)\*\$2\?$')
endfunction

function s:suite.multiple_literals() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('Hello'),
        \ imp#re#Literal(', '),
        \ imp#re#Literal('world!'), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('Hello, world!').to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^Hello, world!$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^Hello, world\!$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^Hello, world\!$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^Hello, world\!$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^Hello, world\!$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^Hello, world!$')
endfunction

function s:suite.character_any_times() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('o').AnyTimes(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('o').to_match(l:regex)
  call s:expect('oooo').to_match(l:regex)
  call s:expect('').to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^o*$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^o*$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^o*$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^o*$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^o*$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^o*$')
endfunction

function s:suite.metacharacter_any_times() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('.').AnyTimes(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('.').to_match(l:regex)
  call s:expect('....').to_match(l:regex)
  call s:expect('').to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^\.*$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^\.*$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^\.*$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^\.*$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^\.*$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^\.*$')
endfunction

function s:suite.literal_any_times() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('word ').AnyTimes(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('word ').to_match(l:regex)
  call s:expect('word word word ').to_match(l:regex)
  call s:expect('').to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^\(word \)*$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^(word )*$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^(?:word )*$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^(?:word )*$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^(?:word )*$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^(?:word )*$')
endfunction

function s:suite.character_at_least_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('x').AtLeastOnce(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('x').to_match(l:regex)
  call s:expect('xxxx').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^x\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^x+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^x+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^x+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^x+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^x+$')
endfunction

function s:suite.literal_at_least_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('_-').AtLeastOnce(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('_-').to_match(l:regex)
  call s:expect('_-_-_-_-_-').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^\(_-\)\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^(_-)+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^(?:_-)+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^(?:_-)+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^(?:_-)+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^(?:_-)+$')
endfunction

function s:suite.character_maybe_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('"').MaybeOnce(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('').to_match(l:regex)
  call s:expect('"').to_match(l:regex)
  call s:expect('""').not.to_match(l:regex)
  call s:expect('""""').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^"\{0,1\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^"?$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^"?$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^"?$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^"?$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^"?$')
endfunction

function s:suite.literal_maybe_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('Why?').MaybeOnce(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('').to_match(l:regex)
  call s:expect('Why?').to_match(l:regex)
  call s:expect('Why?Why?').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^\(Why?\)\{0,1\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^(Why\?)?$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^(?:Why\?)?$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^(?:Why\?)?$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^(?:Why\?)?$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^(?:Why\?)?$')
endfunction

function s:suite.character_repeated() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#AnyCharacter().Repeated(3,5), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('Foo').to_match(l:regex)
  call s:expect('(hi)').to_match(l:regex)
  call s:expect('AC/DC').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('.').not.to_match(l:regex)
  call s:expect('yo').not.to_match(l:regex)
  call s:expect('caribou').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^.\{3,5\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^.{3,5}$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^.{3,5}$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^.{3,5}$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^.{3,5}$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^.{3,5}$')
endfunction

function s:suite.literal_repeated() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('7*8').Repeated(2,3), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('7*87*8').to_match(l:regex)
  call s:expect('7*87*87*8').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('7*8').not.to_match(l:regex)
  call s:expect('2*32*3').not.to_match(l:regex)
  call s:expect('7*87*87*87*8').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^\(7\*8\)\{2,3\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^(7\*8){2,3}$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^(?:7\*8){2,3}$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^(?:7\*8){2,3}$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^(?:7\*8){2,3}$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^(?:7\*8){2,3}$')
endfunction

function s:suite.character_list_at_least_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#CharacterList('AEIOU').AtLeastOnce(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('A').to_match(l:regex)
  call s:expect('UI').to_match(l:regex)
  call s:expect('EEEE').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('a').not.to_match(l:regex)
  call s:expect('AX').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[AEIOU]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[AEIOU]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^[AEIOU]+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^[AEIOU]+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^[AEIOU]+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^[AEIOU]+$')
endfunction

function s:suite.character_list_negate() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#CharacterList('AEIOU').Negate().AtLeastOnce(),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('a').to_match(l:regex)
  call s:expect('BCD').to_match(l:regex)
  call s:expect('Zoo').to_match(l:regex)
  call s:expect('!@#$%^&*()').to_match(l:regex)
  call s:expect('A').not.to_match(l:regex)
  call s:expect('UI').not.to_match(l:regex)
  call s:expect('EEEE').not.to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('AX').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[^AEIOU]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[^AEIOU]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^[^AEIOU]+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^[^AEIOU]+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^[^AEIOU]+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^[^AEIOU]+$')
endfunction

function s:suite.character_list_escapes() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#CharacterList('^\[]').AtLeastOnce(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('[]').to_match(l:regex)
  call s:expect(']^[').to_match(l:regex)
  call s:expect('\').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('[x]').not.to_match(l:regex)
  call s:expect('^ ^').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[[.^.]\\[.[.][.].]]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[[.^.]\\[.[.][.].]]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^[\^\\\[\]]+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^[\^\\\[\]]+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^[\^\\\[\]]+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^[\^\\\[\]]+$')
endfunction

function s:suite.character_range_any_times() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#CharacterRange('j', 's').AnyTimes(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('q').to_match(l:regex)
  call s:expect('mojo').to_match(l:regex)
  call s:expect('knolls').to_match(l:regex)
  call s:expect('').to_match(l:regex)
  call s:expect('t').not.to_match(l:regex)
  call s:expect('Moon').not.to_match(l:regex)
  call s:expect('poop?').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[j-s]*$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[j-s]*$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^[j-s]*$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^[j-s]*$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^[j-s]*$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^[j-s]*$')
endfunction

function s:suite.character_range_negaetd() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#CharacterRange('j', 's').Negate().AtLeastOnce(),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('z').to_match(l:regex)
  call s:expect('it').to_match(l:regex)
  call s:expect('egad!').to_match(l:regex)
  call s:expect('NOON').to_match(l:regex)
  call s:expect('q').not.to_match(l:regex)
  call s:expect('mojo').not.to_match(l:regex)
  call s:expect('knolls').not.to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('Moon').not.to_match(l:regex)
  call s:expect('poop?').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[^j-s]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[^j-s]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^[^j-s]+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^[^j-s]+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^[^j-s]+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^[^j-s]+$')
endfunction

function s:suite.character_range_escapes() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#CharacterRange('Z', '^').AtLeastOnce(), imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('[]').to_match(l:regex)
  call s:expect(']^[').to_match(l:regex)
  call s:expect('\Z').to_match(l:regex)
  call s:expect('\\\\\').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('[x]').not.to_match(l:regex)
  call s:expect('^ ^').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[Z-[.^.]]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[Z-[.^.]]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^[Z-\^]+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^[Z-\^]+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^[Z-\^]+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^[Z-\^]+$')
endfunction


function s:suite.character_class_at_least_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#CharacterClass('alpha').AtLeastOnce(),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('A').to_match(l:regex)
  call s:expect('zoo').to_match(l:regex)
  call s:expect('downUPdown').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect(' ').not.to_match(l:regex)
  call s:expect('7').not.to_match(l:regex)
  call s:expect('nr2chr').not.to_match(l:regex)
  call s:expect('a-ha').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[[:alpha:]]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[[:alpha:]]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^[[:alpha:]]+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^[[:alpha:]]+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^[[:alpha:]]+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^[[:alpha:]]+$')
endfunction

function s:suite.digit_at_least_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#AsciiDigit().AtLeastOnce(),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('0').to_match(l:regex)
  call s:expect('42').to_match(l:regex)
  call s:expect('10000').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect(' ').not.to_match(l:regex)
  call s:expect('x').not.to_match(l:regex)
  call s:expect('2legit2').not.to_match(l:regex)
  call s:expect('867-5309').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[[:digit:]]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[[:digit:]]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^\d+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^\d+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^\d+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^\d+$')
endfunction

function s:suite.not_digit_at_least_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#AsciiDigit().Negate().AtLeastOnce(),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect(' ').to_match(l:regex)
  call s:expect('x').to_match(l:regex)
  call s:expect('!?').to_match(l:regex)
  call s:expect('eight').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('0').not.to_match(l:regex)
  call s:expect('42').not.to_match(l:regex)
  call s:expect('10000').not.to_match(l:regex)
  call s:expect('2legit2').not.to_match(l:regex)
  call s:expect('867-5309').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[^[:digit:]]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[^[:digit:]]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^\D+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^\D+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^\D+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^\D+$')
endfunction

function s:suite.word_at_least_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#AsciiWord().AtLeastOnce(),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('0').to_match(l:regex)
  call s:expect('x').to_match(l:regex)
  call s:expect('nr2chr').to_match(l:regex)
  call s:expect('2_legit_2').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect(' ').not.to_match(l:regex)
  call s:expect('interrobang?!').not.to_match(l:regex)
  call s:expect('a-ha').not.to_match(l:regex)
  call s:expect('867-5309').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[[:alnum:]_]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[[:alnum:]_]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^\w+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^\w+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^\w+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^\w+$')
endfunction

function s:suite.not_word_at_least_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#AsciiWord().Negate().AtLeastOnce(),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect(' ').to_match(l:regex)
  call s:expect('"').to_match(l:regex)
  call s:expect('!?').to_match(l:regex)
  call s:expect(':-/').to_match(l:regex)
  call s:expect('<=> * >-<').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('0').not.to_match(l:regex)
  call s:expect('x').not.to_match(l:regex)
  call s:expect('nr2chr').not.to_match(l:regex)
  call s:expect('2_legit_2').not.to_match(l:regex)
  call s:expect('interrobang?!').not.to_match(l:regex)
  call s:expect('a-ha').not.to_match(l:regex)
  call s:expect('867-5309').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[^[:alnum:]_]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[^[:alnum:]_]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^\W+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^\W+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^\W+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^\W+$')
endfunction

function s:suite.whitespace_at_least_once() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#AsciiWhitespace().AtLeastOnce(),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect(' ').to_match(l:regex)
  call s:expect(' ').to_match(l:regex)
  call s:expect("\t").to_match(l:regex)
  call s:expect("\t ").to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('x').not.to_match(l:regex)
  call s:expect(' 4 ').not.to_match(l:regex)
  call s:expect('\tStart').not.to_match(l:regex)
  call s:expect('x > y').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[[:space:]]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[[:space:]]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^\s+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^\s+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^\s+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^\s+$')
endfunction

function s:suite.character_set_combine_list_range() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#CharacterSet([
          \ imp#re#CharacterList('!@#$%^&*()'),
          \ imp#re#CharacterRange('0', '9')]),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('@').to_match(l:regex)
  call s:expect('^').to_match(l:regex)
  call s:expect('(').to_match(l:regex)
  call s:expect(')').to_match(l:regex)
  call s:expect('0').to_match(l:regex)
  call s:expect('5').to_match(l:regex)
  call s:expect('9').to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[!@#$%[.^.]&*()0-9]$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[!@#$%[.^.]&*()0-9]$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^[!@#$%\^&*()0-9]$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^[!@#$%\^&*()0-9]$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^[!@#$%\^&*()0-9]$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^[!@#$%\^&*()0-9]$')
endfunction

function s:suite.character_set_no_nesetd_negation() abort
  let l:pat = imp#re#CharacterSet([
        \ imp#re#CharacterRange('a', 'z').Negate(),
        \ imp#re#CharacterRange('0', '9').Negate()])
  call s:expect({-> l:pat.InStyle('posix_basic')}).to_throw('BadValue')
  call s:expect({-> l:pat.InStyle('posix')}).to_throw('BadValue')
  call s:expect({-> l:pat.InStyle('pcre')}).to_throw('BadValue')
  call s:expect({-> l:pat.InStyle('perl')}).to_throw('BadValue')
  call s:expect({-> l:pat.InStyle('re2')}).to_throw('BadValue')
  call s:expect({-> l:pat.InStyle('rust')}).to_throw('BadValue')
  call s:expect({-> l:pat.InStyle('vim')}).to_throw('BadValue')
endfunction

function s:suite.sequence_single() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Sequence([imp#re#Literal('7').AnyTimes()]),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('').to_match(l:regex)
  call s:expect('7').to_match(l:regex)
  call s:expect('7777').to_match(l:regex)
  call s:expect('71').not.to_match(l:regex)
  call s:expect('27').not.to_match(l:regex)
  call s:expect('seven').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^7*$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^7*$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^7*$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^7*$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^7*$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^7*$')
endfunction

function s:suite.sequence_multiple() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Sequence([
        \ imp#re#CharacterList('<({[').AtLeastOnce(),
        \ imp#re#Literal('BIG WORD'),
        \ imp#re#CharacterList('>)}]').AtLeastOnce()]),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('<BIG WORD>').to_match(l:regex)
  call s:expect('{{{BIG WORD}}}').to_match(l:regex)
  call s:expect('{[BIG WORD]}').to_match(l:regex)
  call s:expect('(<BIG WORD}]').to_match(l:regex)
  call s:expect('<<<<BIG WORD)))))))').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('{}').not.to_match(l:regex)
  call s:expect('BIG WORD').not.to_match(l:regex)
  call s:expect('(BIG WORD').not.to_match(l:regex)
  call s:expect('BIG WORD]').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^[<({[.[.]]\{1,\}BIG WORD[>)}[.].]]\{1,\}$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^[<({[.[.]]+BIG WORD[>)}[.].]]+$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^[<({\[]+BIG WORD[>)}\]]+$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^[<({\[]+BIG WORD[>)}\]]+$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^[<({\[]+BIG WORD[>)}\]]+$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^[<({\[]+BIG WORD[>)}\]]+$')
endfunction

function s:suite.group_repeated() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('"'),
        \ imp#re#Group([
          \ imp#re#Literal('ABC'),
          \ imp#re#CharacterRange('1', '3').AtLeastOnce(),
          \ imp#re#Literal('!')]).Repeated(2, 3),
        \ imp#re#Literal('"'),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('"ABC123!ABC2!"').to_match(l:regex)
  call s:expect('"ABC1!ABC2!ABC3!"').to_match(l:regex)
  call s:expect('"ABC333!ABC2222!ABC1!"').to_match(l:regex)
  call s:expect('"ABC1!ABC2!ABC3!ABC1!"').not.to_match(l:regex)
  call s:expect('"ABC123!"').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^"\(ABC[1-3]\{1,\}!\)\{2,3\}"$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^"(ABC[1-3]+\!){2,3}"$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^"(?:ABC[1-3]+\!){2,3}"$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^"(?:ABC[1-3]+\!){2,3}"$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^"(?:ABC[1-3]+\!){2,3}"$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^"(?:ABC[1-3]+!){2,3}"$')
endfunction

function s:suite.capture_identifier() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('import'),
        \ imp#re#AsciiWhitespace().AtLeastOnce(),
        \ imp#re#Capture([imp#re#AsciiWord().AtLeastOnce()]),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('import foo').to_match(l:regex)
  call s:expect('import snake_case').to_match(l:regex)
  call s:expect('import   abc123').to_match(l:regex)
  call s:expect("import\tstuff").to_match(l:regex)
  call s:expect('import {foo}').not.to_match(l:regex)
  call s:expect('import ').not.to_match(l:regex)
  call s:expect(substitute('import word', l:regex, '\1', 'g')).to_equal('word')
  call s:expect(substitute('import A_Z', l:regex, '\1', 'g')).to_equal('A_Z')
  call s:expect(l:pat.InStyle('posix_basic')).to_equal(
        \ '^import[[:space:]]\{1,\}\([[:alnum:]_]\{1,\}\)$')
  call s:expect(l:pat.InStyle('posix')).to_equal(
        \ '^import[[:space:]]+([[:alnum:]_]+)$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^import\s+(\w+)$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^import\s+(\w+)$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^import\s+(\w+)$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^import\s+(\w+)$')
endfunction

function s:suite.capture_named() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('say'),
        \ imp#re#AsciiWhitespace(),
        \ imp#re#Capture([
          \ imp#re#CharacterList('"'''),
          \ imp#re#AnyCharacter().AnyTimes(),
          \ imp#re#CharacterList('"''')]).Named('quote'),
        \ imp#re#Literal('!'),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('say "foo"!').to_match(l:regex)
  call s:expect('say ''mixed-quotes"!').to_match(l:regex)
  call s:expect('say "!^&#*$"!').to_match(l:regex)
  call s:expect('say ""!').to_match(l:regex)
  call s:expect("say 'HI THERE'!").to_match(l:regex)
  call s:expect('say (foo)!').not.to_match(l:regex)
  call s:expect('say"nospace"!').not.to_match(l:regex)
  " Vim doesn't support named captures so continue using numbered groups
  call s:expect(substitute('say "word"!', l:regex, '\1', 'g')).to_equal('"word"')
  call s:expect(substitute("say 'A_Z'!", l:regex, '\1', 'g')).to_equal('''A_Z''')
  " POSIX doesn't support named captures either
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^say[[:space:]]\(["''].*["'']\)!$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^say[[:space:]](["''].*["''])\!$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^say\s(?<quote>["''].*["''])\!$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^say\s(?<quote>["''].*["''])\!$')
  call s:expect(l:pat.InStyle('java')).to_equal('^say\s(?<quote>["''].*["''])\!$')
  call s:expect(l:pat.InStyle('ecmascript')).to_equal('^say\s(?<quote>["''].*["''])\!$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^say\s(?P<quote>["''].*["''])\!$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^say\s(?P<quote>["''].*["''])!$')
  call s:expect(l:pat.InStyle('python')).to_equal('^say\s(?P<quote>["''].*["''])\!$')
endfunction

function s:suite.or_literals() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Or([imp#re#Literal('foo'), imp#re#Literal('bar')]),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('foo').to_match(l:regex)
  call s:expect('bar').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('foobar').not.to_match(l:regex)
  call s:expect('far').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal('^\(foo\|bar\)$')
  call s:expect(l:pat.InStyle('posix')).to_equal('^(foo|bar)$')
  call s:expect(l:pat.InStyle('perl')).to_equal('^(?:foo|bar)$')
  call s:expect(l:pat.InStyle('pcre')).to_equal('^(?:foo|bar)$')
  call s:expect(l:pat.InStyle('re2')).to_equal('^(?:foo|bar)$')
  call s:expect(l:pat.InStyle('rust')).to_equal('^(?:foo|bar)$')
endfunction

function s:suite.or_with_groups() abort
  let l:pat = imp#re#Pattern([imp#re#LineStart(),
        \ imp#re#Literal('START'),
        \ imp#re#Or([
        \ imp#re#Group([imp#re#Literal('{'), imp#re#AsciiWord().AnyTimes(), imp#re#Literal('}')]),
        \ imp#re#Capture([imp#re#Literal('('), imp#re#AsciiDigit().AtLeastOnce(), imp#re#Literal(')')]),
        \ imp#re#Literal('[]')]),
        \ imp#re#Literal('END'),
        \ imp#re#LineEnd()])
  let l:regex = l:pat.InStyle('vim')
  call s:expect('START{}END').to_match(l:regex)
  call s:expect('START{brace}END').to_match(l:regex)
  call s:expect('START(42)END').to_match(l:regex)
  call s:expect('START[]END').to_match(l:regex)
  call s:expect('').not.to_match(l:regex)
  call s:expect('STARTEND').not.to_match(l:regex)
  call s:expect('START(x)END').not.to_match(l:regex)
  call s:expect('START[9]END').not.to_match(l:regex)
  call s:expect('START{yo}(123)[]END').not.to_match(l:regex)
  call s:expect(l:pat.InStyle('posix_basic')).to_equal(
        \ '^START\(\({[[:alnum:]_]*}\)\|\(([[:digit:]]\{1,\})\)\|\[\]\)END$')
  call s:expect(l:pat.InStyle('posix')).to_equal(
        \ '^START((\{[[:alnum:]_]*\})|(\([[:digit:]]+\))|\[\])END$')
  call s:expect(l:pat.InStyle('perl')).to_equal(
        \ '^START(?:(?:\{\w*\})|(\(\d+\))|\[\])END$')
  call s:expect(l:pat.InStyle('pcre')).to_equal(
        \ '^START(?:(?:\{\w*\})|(\(\d+\))|\[\])END$')
  call s:expect(l:pat.InStyle('re2')).to_equal(
        \ '^START(?:(?:\{\w*\})|(\(\d+\))|\[\])END$')
  call s:expect(l:pat.InStyle('rust')).to_equal(
        \ '^START(?:(?:\{\w*\})|(\(\d+\))|\[\])END$')
endfunction
