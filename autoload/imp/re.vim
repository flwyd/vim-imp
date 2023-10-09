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

""
" @section Regular Expressions, regex
" @stylized(plugin) handlers often need to build multiple regular expressions,
" reusing non-trivial sub-expressions.  For example, the `java` handler reuses
" a regex fragment like `(?:\w+\.)+\w+` (a qualified symbol like
" `java.util.List`) in two top-level regexes: one for static imports and one
" for class imports.  Building these regular expressions by simple string
" concatenation can lead to hard-to-read code, particularly since Pattern
" handlers need to produce patterns for different regex libraries; Vim's
" syntax for regex metacharacters in particular can be tricky to get right.
"
" @stylized(plugin) provides `imp#re`, a library for building abstract regular
" expression patterns from smaller components--either function calls inline or
" reference to variables for reusable sub-patterns.  While this code takes
" longer to write than a literal regex string, it should be significantly
" easier to read and maintain.  This library also takes care of all of the
" syntactic details for each regex engine, so a handler author only needs to
" write each pattern once, calling `InStyle(engine)` to generate syntactically
" valid input for any supported library.
"
" Motivating examples for using the `imp#re` library follow.  See help for
" each function for more details.  Note that the patterns below don't
" precisely match language identifier rules, e.g. accepting a leading digit
" and not accepting non-ASCII Unicode identifiers.  In practice, this isn't
" likely to matter.
"
" Java: >
"   " Instead of '^\s*import\s+(?:static\s+)?(?:\w+\.)+(List)\s*;'
"   let l:wantSymbol = imp#re#Literal('List')
"   let l:space = imp#re#AsciiWhitespace().AtLeastOnce()
"   let l:maybeSpace = imp#re#AsciiWhitespace().AnyTimes()
"   let l:javaIdent = imp#re#AsciiWord().AnyTimes()
"   let l:qualifiedSymbol = imp#re#Sequence([
"     imp#re#Group([l:javaIdent, imp#re#Literal('.')]).AnyTimes(),
"     l:javaIdent.Named('symbol')])
"   let l:staticImport = imp#re#Pattern([
"     imp#re#LineStart(), l:maybeSpace,
"     imp#re#Literal('import'), l:space,
"     imp#re#Literal('static'), l:space,
"     l:qualifiedSymbol, l:maybeSpace,
"     imp#re#Literal(';')])
"   let l:classImport = imp#re#Pattern([
"     imp#re#LineStart(), l:maybeSpace,
"     imp#re#Literal('import'), l:space,
"     l:qualifiedSymbol, l:maybeSpace,
"     imp#re#Literal(';')])
"   " Replace the patterns which map any import with one that just matches
"   " the symbol we want.
"   let l:patterns = mapnew([l:staticImport, l:classImport],
"     {p -> p.Replace('symbol', l:wantSymbol).InStyle('vim'))
"   " l:patterns now has two strings which map the two Java import styles with
"   " proper Vim metacharacters and escaping
" <
"
" Python: >
"   " Instead of '^\s*import\s+(?:\w+\.)*(\w+)\b'
"   " and '^\s*from\s+(?:\w+\.)*\w+\s+import\s+(\w+)(?:\s+as\s+(\w+))'
"   let l:pyIdent = imp#re#AsciiWord().AnyTimes()
"   let l:pkgPrefix = imp#re#Group([pyIdent, imp#re#Literal('.')])
"   let l:space = imp#re#AsciiWhitespace().AtLeastOnce(),
"   let l:style1 = imp#re#Sequence([
"     imp#re#LineStart(), imp#re#Space().AnyTimes(),
"     imp#re#Literal('import'), l:space,
"     (l:pkgPrefix).AnyTimes(),
"     l:pyIdent.Named('symbol'),
"     imp#re#LineEnd()])
"   let l:style2 = imp#re#Sequence([
"     imp#re#LineStart(), imp#re#Space().AnyTimes(),
"     imp#re#Literal('from'), l:space,
"     imp#re#AnyTimes(l:pkgPrefix),
"     l:pyIdent, l:space,
"     imp#re#Literal('import'), l:space,
"     l:pyIdent.Named('symbol'),
"     imp#re#LineEnd()])
"   " A single pattern to match any import in either style
"   let l:pat = imp#re#Pattern([imp#re#Or([l:pat1, l:pat2])])
"   " A string ready to pass to a program built with the PCRE library
"   let l:regex = l:pat.InStyle('pcre')
" <

""
" Atom is a "base class" for components of regular expressions.  The Atom
" constructor sets default properties and method references, overwritten and
" extended by anything in {properties}.  Atoms are immutable, but
" copy-to-mutate is a common pattern.
" @public
function! imp#re#Atom(properties) abort
  let l:self = {
        \ 'atoms': [],
        \ 'name': '',
        \ 'type': 'imp#re#Atom',
        \ 'InStyle': function('s:defaultInStyle'),
        \ 'MaybeGroupInStyle': function('s:notGroupedInStyle'),
        \ 'Named': function('s:named'),
        \ 'Replace': function('s:replace'),
        \ 'AnyTimes': function('s:anyTimes'),
        \ 'AtLeastOnce': function('s:atLeastOnce'),
        \ 'MaybeOnce': function('s:maybeOnce'),
        \ 'Repeated': function('s:repeated')}
  call extend(l:self, a:properties, 'force')
  lockvar l:self " atoms are immutable, with copy-to-mutate semantics
  return l:self
endfunction

function! s:defaultInStyle(...) dict abort
  throw maktaba#error#Message('AbstractAtom',
        \ '%s did not override InStyle methood', self.type)
endfunction

function! s:listInStyle(atoms, style, options) abort
  return join(
        \ maktaba#function#Map(a:atoms, {x -> x.InStyle(a:style, a:options)}),
        \ '')
endfunction

function! s:notGroupedInStyle(style, ...) dict abort
  return self.InStyle(a:style, a:0 == 0 ? {} : a:1)
endfunction

function! s:groupInStyle(style, ...) dict abort
    return s:groupNoCapture(self.InStyle(a:style, a:0 == 0 ? {} : a:1), a:style)
endfunction

function! s:groupNoCapture(text, style) abort
  if a:style ==# 'vim'
    return printf('%%(%s)', a:text)
  elseif a:style ==# 'posix'
    " BSD egrep allows (?:) for non-capturing groups but GNU egrep does not
    return printf('(%s)', a:text)
  elseif a:style ==# 'posix_basic'
    return printf('\(%s\)', a:text)
  else
    return printf('(?:%s)', a:text)
  endif
endfunction

function! s:clone(atom, newprops) abort
  let l:new = extend(copy(a:atom), a:newprops)
  lockvar l:new
  return l:new
endfunction

function! s:named(name) dict abort
  return s:clone(self, {'name': a:name})
endfunction

function! s:replace(name, replacement) dict abort
  let l:atoms = []
  for l:atom in self.atoms
    if l:atom.name ==# a:name
      call add(l:atoms, a:replacement)
    else
      call add(l:atoms, l:atom.Replace(a:name, a:replacement))
    endif
  endfor
  return s:clone(self, {'atoms': l:atoms})
endfunction

function! s:anyTimes() dict abort
  return imp#re#AnyTimes(self)
endfunction

function! s:atLeastOnce() dict abort
  return imp#re#AtLeastOnce(self)
endfunction

function! s:maybeOnce() dict abort
  return imp#re#MaybeOnce(self)
endfunction

function! s:repeated(min, max) dict abort
  return imp#re#Repeated(self, a:min, a:max)
endfunction

""
" Pattern is a complete regular expression, made up of one or more {atoms}.
" Pattern is not itself an Atom, and provides top-level methods:
" `Replace(name, atom)` to swap one part of a regex for a different atom, and
" `InStyle(style)` to convert the Pattern to a string suitable for
" interpretation by a particular library, e.g. `vim, posix, pcre, perl, rust`.
" @public
function! imp#re#Pattern(atoms) abort
  call imp#ensure#NotEmpty(maktaba#ensure#IsList(a:atoms),
        \ 'Pattern with no atoms')
  " Note: Pattern does not inherit Atom methods; Pattern handles top-level
  " logic that should not be repeated recursively.
  " TODO Pattern options like ignore-case?
  let l:self = {'atoms': [imp#re#Sequence(a:atoms)],
        \ 'type': 'imp#re#Pattern',
        \ 'Replace': function('s:replace'),
        \ 'InStyle': function('s:patternInStyle')}
  lockvar l:self
  return l:self
endfunction

function! s:patternInStyle(style, ...) dict abort
  let l:opts = a:0 > 0 ? a:1 : {}
  let l:prefix = ''
  if a:style ==# 'vim'
    let l:prefix .= '\v'
    if !get(l:opts, 'ignorecase', 0)
      let l:prefix .= '\C'
    endif
  endif
  return l:prefix . s:listInStyle(self.atoms, a:style, l:opts)
endfunction

""
" Anchors a regex at the beginning of a line.  Regex syntax: `^`
" @public
function! imp#re#LineStart() abort
  return imp#re#Atom({'type': 'imp#re#LineStart',
        \ 'value': '^',
        \ 'InStyle': function('s:anchorInStyle')})
endfunction

""
" Anchors a regex at the end of a line.  Regex syntax: `$`
" @public
function! imp#re#LineEnd() abort
  return imp#re#Atom({'type': 'imp#re#LineEnd',
        \ 'value': '$',
        \ 'InStyle': function('s:anchorInStyle')})
endfunction

function! s:anchorInStyle(style, ...) dict abort
  return self.value
endfunction

""
" Matches exactly {text}.  Escaping is performed so that no characters in text
" are treated as metacharacters.
" @public
function! imp#re#Literal(text) abort
  call maktaba#ensure#IsString(a:text)
  if empty(a:text)
    throw maktaba#error#BadValue('Empty literal')
  endif
  return imp#re#Atom({'type': 'imp#re#Literal',
        \ 'value': a:text,
        \ 'InStyle': function('s:literalInStyle'),
        \ 'MaybeGroupInStyle': function('s:literalMaybeGroupInStyle')})
endfunction

functio! s:literalInStyle(style, ...) dict abort
  " Common case: all alphanumeric text means no regex engine needs escapes
  if self.value =~# '\v^(\w| )+$'
    return self.value
  endif
  if a:style ==# 'vim'
    " use 'very nomagic' for Vim
    return '\V' . escape(self.value, '\') . '\v'
  elseif a:style ==# 'posix_basic'
    " POSIX basic mode (e.g. grep default) treats ?+|(){} as literals, and
    " treats \? \| \(\) etc. as metacharacters, so just escape specific chars.
    return escape(self.value, '^$.*[]\')
  elseif a:style ==# 'rust'
    " See https://github.com/rust-lang/regex/issues/501#issuecomment-1298208401
    " for context on Rust's 'unrecognized escape sequence' error.
    " TODO add rust to test suite
    return escape(self.value, '.+*?()|[]{}^$\')
  else
    " assume all non-alphanumerics should be escaped except space, underscore,
    " hyphen, comma, and quotes.  This could create a problem if a regex engine
    " treated \X (where X is some punctuation character) as special but X as
    " literal, but vim and posix_basic are the only such examples I'm aware
    " of.  See :help [:lower:] on why [[:lower:][:upper:]] is the way to match
    " Unicode letters.  This might mangle non-letter Unicode characters, e.g.
    " CJK identifiers (class Lo: Other Letter) in languages that support them.
    return substitute(self.value,
          \ '[^-_, ''"[:lower:][:upper:][:digit:]]', '\\&', 'g')
  endif
endfunction

function! s:literalMaybeGroupInStyle(style, ...) dict abort
  let l:text =  self.InStyle(a:style, a:0 == 0 ? {} : a:1)
  return len(l:text) == 1 || l:text =~# '\v^\\.$'
        \ ? l:text : s:groupNoCapture(l:text, a:style)
endfunction

""
" Matches a signle character.  Regex syntax: `.`
" @public
function! imp#re#AnyCharacter() abort
  return imp#re#Atom({'type': 'imp#re#AnyCharacter',
        \ 'InStyle': function('s:anyCharacterInStyle')})
endfunction

function! s:anyCharacterInStyle(style, ...) dict abort
  return '.'
endfunction

""
" Matches one or more {atoms} in sequence.  No special syntax is provided
" unless a method like `.AnyTimes()` turns a sequence into a group.
" Sequence is mostly useful when a single atom is needed for a reusable
" variable.
" @public
function! imp#re#Sequence(atoms) abort
  return imp#re#Atom({'type': 'imp#re#Sequence',
        \ 'atoms': copy(imp#ensure#NotEmpty(maktaba#ensure#IsList(a:atoms),
          \ 'Empty list for imp#re#Sequence')),
        \ 'InStyle': function('s:sequenceInStyle'),
        \ 'MaybeGroupInStyle': function('s:groupInStyle')})
endfunction

function! s:sequenceInStyle(style, ...) dict abort
  return s:listInStyle(self.atoms, a:style, a:0 == 0 ? {} : a:1)
endfunction

""
" A non-capturing group of {atoms} treated as a single atom.  Regex syntax
" (POSIX style): `(?:ab?c*)`.
" @public
function! imp#re#Group(atoms) abort
  return imp#re#Atom({'type': 'imp#re#Group',
        \ 'atoms': copy(imp#ensure#NotEmpty(maktaba#ensure#IsList(a:atoms),
          \ 'Empty list for imp#re#Group')),
        \ 'InStyle': function('s:grouplistInStyle'),
        \ 'MaybeGroupInStyle': function('s:grouplistInStyle')})
endfunction

function! s:grouplistInStyle(style, ...) dict abort
  let l:options = a:0 == 0 ? {} : a:1
  return s:groupNoCapture(s:listInStyle(self.atoms, a:style, l:options),
        \ a:style)
endfunction

""
" A capturing group of {atoms}.  All other grouping mechanisms, including
" `imp#re#Group` and methods like `AnyTimes()` will create non-capturing
" groups, making it feasible to count the index of Capture groups.  If this
" atom is `Named()` and the regex style supports named groups, the name will
" be used.  Regex syntax: `(ab?c*)`
" @public
function! imp#re#Capture(atoms) abort
  return imp#re#Atom({'type': 'imp#re#Capture',
        \ 'atoms': copy(imp#ensure#NotEmpty(maktaba#ensure#IsList(a:atoms),
          \ 'Empty list for imp#re#Capture')),
        \ 'InStyle': function('s:captureInStyle'),
        \ 'MaybeGroupInStyle': function('s:captureInStyle')})
endfunction

function! s:captureInStyle(style, ...) dict abort
  let l:text = s:listInStyle(self.atoms, a:style, a:0 == 0 ? {} : a:1)
  if !empty(self.name)
    if maktaba#value#IsIn(a:style, ['perl', 'pcre', 'java', 'ecmascript'])
      return printf('(?<%s>%s)', self.name, l:text)
    elseif maktaba#value#IsIn(a:style, ['python', 're2', 'rust'])
      return printf('(?P<%s>%s)', self.name, l:text)
    endif
  endif
  if a:style ==# 'vim'
    return printf('(%s)', l:text)
  elseif a:style ==# 'posix'
    return printf('(%s)', l:text)
  elseif a:style ==# 'posix_basic'
    return printf('\(%s\)', l:text)
  else
    return printf('(%s)', l:text)
  endif
endfunction

""
" Exactly one of {atoms}.  Regex syntax: `a|b+|c*`
" @public
function! imp#re#Or(atoms) abort
  return imp#re#Atom({'type': 'imp#re#Or',
        \ 'atoms': copy(imp#ensure#NotEmpty(maktaba#ensure#IsList(a:atoms),
          \ 'Empty list for imp#re#Or')),
        \ 'InStyle': function('s:orInStyle'),
        \ 'MaybeGroupInStyle': function('s:orInStyle')})
endfunction

function! s:orInStyle(style, ...) dict abort
  let l:opts = a:0 == 0 ? {} : a:1
  let l:bar = a:style ==# 'posix_basic' ? '\|' : '|'
  " If Or is the only thing in a pattern or outer group then the grouping is
  " technically unnecessary, but position in a sequence isn't known here
  return s:groupNoCapture(join(
        \ maktaba#function#Map(self.atoms, {x -> x.InStyle(a:style, l:opts)}),
        \ l:bar),
        \ a:style)
endfunction

""
" One character from {chars}.  Escaping is done so that any character in the
" list is matched literaly, not as a metacharacter.  The `Negate()` method
" matches any character NOT in the list  Regex syntax: `[abc]`
" @public
function! imp#re#CharacterList(chars) abort
  return imp#re#Atom({'type': 'imp#re#CharacterList',
        \ 'value': maktaba#ensure#IsString(a:chars),
        \ 'charset': 1,
        \ 'negate': 0,
        \ 'InStyle': function('s:characterListInStyle'),
        \ 'Negate': function('s:negate')})
endfunction

function! s:characterListInStyle(style, ...) dict abort
  let l:options = a:0 == 0 ? {} : a:1
  if self.negate && get(l:options, 'inbrackets', 0)
    " Some engines (e.g. Rust, Java) supports this via [a-z&&[^xyz]] or Perl's
    " 'Extended Bracketed Character Classes' but discourage use anyway
    throw maktaba#error#BadValue(
          \ 'Negated %s "%s" not allowed in another character set',
          \ self.type, self.value)
  endif
  let l:escaped = join(
        \ maktaba#function#Map(split(self.value, '\zs'),
        \ {x -> s:escapeBracketedChar(x, a:style)}),
        \ '')
  return get(l:options, 'inbrackets', 0) ? l:escaped
        \ : printf('[%s%s]', self.negate ? '^' : '', l:escaped)
endfunction

""
" A range of characters from {min} to {max} inclusive.  The `Negate()` method
" creates an atom matching any character NOT in range.  Regex syntax: `[a-c]`
" @public
function! imp#re#CharacterRange(min, max) abort
  if len(maktaba#ensure#IsString(a:min)) != 1
        \ || len(maktaba#ensure#IsString(a:max)) != 1
        \ || a:min >= a:max
    throw maktaba#error#BadValue(
          \ 'Character range should be single-character strings with min < max, not "%s", "%s"',
          \ a:min, a:max)
  endif
  return imp#re#Atom({'type': 'imp#re#CharacterRange',
        \ 'charmin': a:min,
        \ 'charmax': a:max,
        \ 'charset': 1,
        \ 'negate': 0,
        \ 'InStyle': function('s:characterRangeInStyle'),
        \ 'Negate': function('s:negate')})
endfunction

function! s:characterRangeInStyle(style, ...) dict abort
  let l:options = a:0 == 0 ? {} : a:1
  if self.negate && get(l:options, 'inbrackets', 0)
    " Rust and Java support this with [a-z&&[^x-z]] and Perl 'Extended
    " Bracketed Character Classes' handle this, but discourage use anyway
    throw maktaba#error#BadValue(
          \ 'Negated %s "%s-%s" not allowed in another character set',
          \ self.type, self.charmin, self.charmax)
  endif
  let l:range = printf('%s-%s', s:escapeBracketedChar(self.charmin, a:style),
        \ s:escapeBracketedChar(self.charmax, a:style))
  return get(l:options, 'inbrackets', 0) ? l:range
        \ : printf('[%s%s]', self.negate ? '^' : '', l:range)
endfunction

function s:escapeBracketedChar(char, style, ...) abort
  if type(a:style) != v:t_string || len(a:char) != 1
    throw printf('escapeBracketedChar(%s, %s)', a:char, a:style)
  endif
  if a:style ==# 'posix' || a:style ==# 'posix_basic'
    " See bracketed expression details in regex(7) or re_syntax(7)
    if index(['[', ']', '-', '^'], a:char) >= 0
      return printf('[.%s.]', a:char)
    endif
  endif
  " Vim has some surprising escaping rules in character ranges (:help \]):
  " [Z-\] means 'Z to backslash' (not 'Z to close bracket'), '\' does not
  " match '[Z-\\]', '[Z-^]' is 'Z to carat' and '[Z-\^]' means 'Z to backslash
  " and also carat' but '[^-z]' means 'not hyphen or z' and '[\^-z]' means
  " 'carat to z'. So just use decimal values for these metachars.
  if a:style ==# 'vim'
    if index(['[', ']', '-', '^', '\'], a:char) >= 0
      return printf('\d%d', char2nr(a:char))
    else
      return a:char
    endif
  endif
  " Perl-inspired bracketed expressions allow \ escapes
  return escape(a:char, '[]^-\')
endfunction

""
" A named character class.  {name} must be known by the regex engine, e.g.
" `digit` or `space`.  The `Negate()` method matches any character NOT in the
" class.  Regex syntax: `[[:name:]]`
" @public
function! imp#re#CharacterClass(name) abort
  if maktaba#ensure#IsString(a:name) !~# '\v^\w+$'
    throw maktaba#error#BadValue('Invalid character class %s', a:name)
  endif
  return imp#re#Atom({'type': 'imp#re#CharacterClass',
        \ 'value': a:name,
        \ 'charset': 1,
        \ 'negate': 0,
        \ 'InStyle': function('s:characterClassInStyle'),
        \ 'Negate': function('s:negate')})
endfunction

function! s:characterClassInStyle(style, ...) dict abort
  " TODO Java doesn't support [:class:] and uses \p{Class} instead
  " TODO JavaScript doesn't support POSIX classes and requires Unicode flag
  " for \p{Prop}
  let l:options = a:0 == 0 ? {} : a:1
  if self.negate && get(l:options, 'inbrackets', 0)
    " Perl, PCRE, and Rust support non-standard [[:^digit:]] but discourage this
    throw maktaba#error#BadValue(
          \ 'Negated %s [:%s:] not allowed in another character set',
          \ self.type, self.value)
  endif
  let l:class = printf('[:%s:]', self.value)
  return get(l:options, 'inbrackets', 0) ? l:class
        \ : printf('[%s%s]', self.negate ? '^' : '', l:class)
endfunction

""
" A single-{letter} character class.  Valid letters are `d` for digit, `s` for
" space, and `w` for word (letter, digit, or underscore).  Capital `D`, `S`,
" and `W` negate the character class.  The `Negate()` method switches between
" lower and upper case.  Regex syntax: `\w+\s+\S*`
" @public
function! imp#re#CharacterClassShortcut(letter) abort
  if len(maktaba#ensure#IsString(a:letter)) != 1
    throw maktaba#error#BadValue(
          \ 'Shortcut should be a single lettter like "w" not "\w"')
  endif
  call maktaba#ensure#IsIn(a:letter, ['d', 'D', 's', 'S', 'w', 'W'])
  return imp#re#Atom({'type': 'imp#re#CharacterClassShortcut',
        \ 'value': a:letter,
        \ 'charset': 1,
        \ 'InStyle': function('s:characterClassShortcutInStyle'),
        \ 'Negate': function('s:negateShortcut')})
endfunction

let s:shortcutClasses = {'d': 'digit', 's': 'space', 'w': 'word'}

function! s:characterClassShortcutInStyle(style, ...) dict abort
  let l:options = a:0 == 0 ? {} : a:1
  if get(l:options, 'inbrackets', 0) && self.value ==# toupper(self.value)
    " Some engines support [^\D] as not-not-digit, but this should be
    " discouraged since it's easy to accidentally allow almost everything
    throw maktaba#error#BadValue(
          \ 'Negated shortcut \%s not allowed in another character set',
          \ self.type, self.value)
  endif
  if maktaba#value#IsIn(a:style, ['posix', 'posix_basic']) ||
        \ (get(l:options, 'inbrackets', 0) && a:syle ==# 'vim')
    let l:class = s:shortcutClasses[tolower(self.value)]
    if tolower(self.value) ==# 'd'
      let l:atom = imp#re#CharacterClass('digit')
    elseif tolower(self.value) ==# 's'
      let l:atom = imp#re#CharacterClass('space')
    elseif tolower(self.value) ==# 'w'
      let l:atom = imp#re#CharacterSet([imp#re#CharacterClass('alnum'),
            \ imp#re#CharacterList('_')])
    endif
    if self.value ==# toupper(self.value)
      let l:atom = l:atom.Negate()
    endif
    return l:atom.InStyle(a:style, l:options)
  endif
  if a:style ==# 'vim' && self.value ==# 's'
    " Use space-or-newline to match \s behavior of other engines
    return '\_s'
  endif
  return '\' . self.value
endfunction

function! s:negateShortcut() dict abort
  if self.value ==# toupper(self.value)
    return imp#re#CharacterClassShortcut(tolower(self.value))
  endif
  return imp#re#CharacterClassShortcut(toupper(self.value))
endfunction

""
" Matches a single ASCII digit, 0 through 9.
" @public
function! imp#re#AsciiDigit() abort
  " TODO Rust (at least) treats \d \s \w as Unicode, not ASCII but uses
  " :code: for ASCII classes.  Consider restructuring ASCII/Unicode method
  " distinction and see what Perl/PCRE/RE2 do.
  return imp#re#CharacterClassShortcut('d')
endfunction

""
" Matches a single ASCII letter, digit, or underscore.
" @public
function! imp#re#AsciiWord() abort
  return imp#re#CharacterClassShortcut('w')
endfunction

""
" Matches a single ASCII whitespace character, e.g. space, tab, or newline.
" @public
function! imp#re#AsciiWhitespace() abort
  return imp#re#CharacterClassShortcut('s')
endfunction

""
" Matches one of a list of character set {atoms}.  The `Negate()` method
" matches any character not in the set.  For example,
" `imp#re#CharacterSet([imp#re#CharacterClass('digit'),
" imp#re#CharacterList('abcdef')])`.  Regex syntax: `[[:digit:]abcdef]`
" @public
function! imp#re#CharacterSet(atoms) abort
  call imp#ensure#AllItems(
        \ imp#ensure#NotEmpty(a:atoms, 'Empty list for imp#re#CharacterSet'),
        \ {x -> get(x, 'charset', 0)},
        \ 'All arguments to imp#re#CharacterSet must be charsets')
  return imp#re#Atom({'type': 'imp#re#CharacterSet',
        \ 'atoms': copy(a:atoms),
        \ 'charset': 1,
        \ 'negate': 0,
        \ 'InStyle': function('s:characterSetInStyle'),
        \ 'Negate': function('s:negate')})
endfunction

function! s:characterSetInStyle(style, ...) dict abort
  " Warn children if they're nested in an outer bracketed expression.  POSIX
  " and Vim don't support patterns like [\w\s] but do allow (\w|\s) or
  " [[:alnum:][:space:]].  Most regex engines don't support something like
  " [^a-z[^G-S]], although rust (e.g. ripgrep) seems to.
  let l:options = a:0 == 0 ? {} : a:1
  if get(l:options, 'inbrackets', 0)
    return s:mergeCharacterSet(self.atoms, a:style, l:options)
  endif
  let l:options = s:clone(l:options, {'inbrackets': 1})
  return printf('[%s%s]', self.negate ? '^' : '',
        \ s:mergeCharacterSet(self.atoms, a:style, l:options))
endfunction

function! s:mergeCharacterSet(atoms, style, ...) abort
  let l:options = a:0 == 0 ? {} : a:1
  return join(maktaba#function#Map(a:atoms,
        \ {x -> x.InStyle(a:style, l:options)}),
        \ '')
endfunction

""
" Matches zero or more occurrences of {atom}.  Regex syntax: `a*`
" Typically called as a method on an atom: `imp#re#Literal('a').AnyTimes()`.
" @public
function! imp#re#AnyTimes(atom) abort
  return imp#re#Atom({'type': 'imp#re#AnyTimes',
        \ 'atoms': [a:atom],
        \ 'InStyle': function('s:anyTimesInStyle'),
        \ 'MaybeGroupInStyle': function('s:groupInStyle')})
endfunction

function! s:anyTimesInStyle(style, ...) dict abort
  return self.atoms[0].MaybeGroupInStyle(a:style, a:0 == 0 ? {} : a:1) . '*'
endfunction

""
" Matches one or more occurrences of {atom}.  Regex syntax: `a+`
" Typically called as a method on an atom: `imp#re#Literal('a').AtLeastOnce()`.
" @public
function! imp#re#AtLeastOnce(atom) abort
  return imp#re#Atom({'type': 'imp#re#AtLeastOnce',
        \ 'atoms': [a:atom],
        \ 'InStyle': function('s:atLeastOnceInStyle'),
        \ 'MaybeGroupInStyle': function('s:groupInStyle')})
endfunction

function! s:atLeastOnceInStyle(style, ...) dict abort
  let l:sign = a:style ==# 'posix_basic' ? '\{1,\}' : '+'
  return self.atoms[0].MaybeGroupInStyle(a:style, a:0 == 0 ? {} : a:1) . l:sign
endfunction

""
" Matches zero or one occurrences of {atom}.  Regex syntax: `a?`
" Typically called as a method on an atom: `imp#re#Literal('a').MaybeOnce()`.
" @public
function! imp#re#MaybeOnce(atom) abort
  return imp#re#Atom({'type': 'imp#re#MaybeOnce',
        \ 'atoms': [a:atom],
        \ 'InStyle': function('s:maybeOnceInStyle'),
        \ 'MaybeGroupInStyle': function('s:groupInStyle')})
endfunction

function! s:maybeOnceInStyle(style, ...) dict abort
  let l:sign = a:style ==# 'posix_basic' ? '\{0,1\}' : '?'
  return self.atoms[0].MaybeGroupInStyle(a:style, a:0 == 0 ? {} : a:1) . l:sign
endfunction

""
" Matches {atom} at least {min} times and not more than {max} times.
" Regex syntax: `a?`
" Typically called as a method on an atom: `imp#re#Literal('a').Repeated(2,4)`.
" @public
function! imp#re#Repeated(atom, min, max) abort
  if maktaba#ensure#IsNumber(a:min) < 0
        \ || (maktaba#ensure#IsNumber(a:max) < a:min && a:max != -1)
    throw maktaba#error#BadValue(
          \ 'Can only repeat 0 <= min <= max, got min=%s max=%s', a:min, a:max)
  endif
  return imp#re#Atom({'type': 'imp#re#Repeated',
        \ 'atoms': [a:atom],
        \ 'min': a:min,
        \ 'max': a:max,
        \ 'InStyle': function('s:repeatedInStyle'),
        \ 'MaybeGroupInStyle': function('s:groupInStyle')})
endfunction

function! s:repeatedInStyle(style, ...) dict abort
  let l:text = self.atoms[0].MaybeGroupInStyle(a:style, a:0 == 0 ? {} : a:1)
  if self.min == self.max
    let l:range = string(self.min)
  elseif self.max == -1
    let l:range = printf('%s,', self.min)
  else
    let l:range = printf('%d,%d', self.min, self.max)
  endif
  if a:style ==# 'posix_basic'
    return printf('%s\{%s\}', l:text, l:range)
  endif
  return printf('%s{%s}', l:text, l:range)
endfunction

function! s:negate() dict abort
  if !has_key(self, 'negate')
    throw maktaba#error#BadValue('%s is not negatatable', self.type)
  endif
  return s:clone(self, {'negate': !self.negate})
endfunction
