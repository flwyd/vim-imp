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

let s:logger = maktaba#log#Logger('imp#lang#rust')

" All imports start with 'pub use ' or 'use ' and can have leading whitespace.
let s:useStart = imp#re#Sequence([
      \ imp#re#LineStart(),
      \ imp#re#AsciiWhitespace().AnyTimes(),
      \ imp#re#Group([
        \ imp#re#Literal('pub'),
        \ imp#re#AsciiWhitespace().AtLeastOnce()]
      \ ).MaybeOnce(),
      \ imp#re#Literal('use'),
      \ imp#re#AsciiWhitespace().AtLeastOnce()])
let s:identifier = imp#re#AsciiWord().AtLeastOnce()

" Rust import styles for identifier x (can span multiple lines):
" a might be std, crate, super, etc.
"  use a as x;
let s:useIdentAsX = imp#re#Pattern([s:useStart,
      \ s:identifier,
      \ imp#re#AsciiWhitespace().AtLeastOnce(),
      \ imp#re#Literal('as'),
      \ imp#re#AsciiWhitespace(),
      \ s:identifier.Named('symbol'),
      \ imp#re#Literal(';')])
"  use x;
"  use a::x;
"  use a::b::x;
let s:useQualified = imp#re#Pattern([s:useStart,
      \ imp#re#Group([s:identifier, imp#re#Literal('::')]).AnyTimes(),
      \ s:identifier.Named('symbol'),
      \ imp#re#Literal(';')])
"  use a::b as x;
let s:useQualifiedAsX = imp#re#Pattern([s:useStart,
      \ imp#re#Group([s:identifier, imp#re#Literal('::')]).AtLeastOnce(),
      \ s:identifier,
      \ imp#re#AsciiWhitespace().AtLeastOnce(),
      \ imp#re#Literal('as'),
      \ imp#re#AsciiWhitespace().AtLeastOnce(),
      \ s:identifier.Named('symbol'),
      \ imp#re#Literal(';')])
"  use a::{x, y};
"  use a::b::{c, x, y};
"  use a::{b::x, y}};
"  use a::{b, c::x}};
"  use a::{b::{c, x}};
"  use a::b::{c as x, d};
let s:useNested = imp#re#Pattern([s:useStart,
      \ imp#re#Group([
        \ imp#re#Group([s:identifier, imp#re#Literal('::')]).AnyTimes(),
        \ imp#re#Literal('{'),
        \ imp#re#AsciiWhitespace().AnyTimes()]).AtLeastOnce(),
      \ imp#re#Or([
        \ imp#re#Sequence([
          \ imp#re#Group([s:identifier, imp#re#Literal('::')]).AnyTimes(),
          \ s:identifier.Named('symbol')]),
        \ imp#re#Group([
          \ imp#re#CharacterList(';').Negate().AtLeastOnce(),
          \ imp#re#Or([imp#re#Literal(','), imp#re#Literal(' as')]),
          \ imp#re#AsciiWhitespace().AtLeastOnce(),
          \ imp#re#Sequence([
            \ imp#re#Group([s:identifier, imp#re#Literal('::')]).AnyTimes(),
            \ s:identifier.Named('symbol')])])]),
      \ imp#re#CharacterList(';').Negate().AnyTimes(),
      \ imp#re#Literal('};')])
"  use a::x::{self, y}; // rustfmt always puts self first in {}
"  use a::{b::{x::{self, y}}};
let s:useSelf = imp#re#Pattern([s:useStart,
      \ imp#re#CharacterList(';').Negate().AnyTimes(),
      \ imp#re#Or([
        \ imp#re#Literal('::'), imp#re#Literal('{'), imp#re#Literal(',')]),
      \ imp#re#AsciiWhitespace().AnyTimes(),
      \ s:identifier.Named('symbol'),
      \ imp#re#Literal('::{'),
      \ imp#re#AsciiWhitespace().AnyTimes(),
      \ imp#re#Literal('self,')])

function! imp#lang#rust#Pattern(context, style, symbol) abort
  let l:sym = imp#re#Literal(a:symbol).Named('symbol')
  let l:patterns = maktaba#function#Map([s:useQualified, s:useNested,
        \ s:useSelf, s:useQualifiedAsX, s:useIdentAsX],
        \ {p -> p.Replace('symbol', l:sym).InStyle(a:style)})
  return {'patterns': l:patterns, 'style': a:style, 'multiline': 1,
        \ 'fileglobs': ['*.rs'], 'Parse': function('s:parseImport')}
endfunction

function! imp#lang#rust#Suggest(context, symbol) abort
  let l:suggest = printf("use ::%s;\<S-Left>", a:symbol)
  let l:statement = input(a:symbol . ': ', l:suggest)
  return empty(l:statement) ? [] : [imp#NewImport(a:symbol, l:statement)]
endfunction

function! imp#lang#rust#Insert(context, choices) abort
  let l:success = 1
  for l:choice in a:choices
    let l:action = s:insertSymbol(a:context, l:choice)
    if l:action.inserted && l:action.success
      call add(a:context.imported, l:action.import)
    elseif l:action.success
      call add(a:context.already_imported, l:action.import)
    endif
    let l:success = l:action.success && l:success
  endfor
  return l:success
endfunction

function! s:insertSymbol(context, choice) abort
  let l:parsed = s:parseStatement(a:choice.statement)
  if l:parsed.IsEmpty()
    call s:logger.Debug('Could not parse choice %s', a:choice.statement)
    return {'inserted': 0, 'success': 0}
  endif
  let l:sat = l:parsed.StemAndTail()
  " beforespots and afterspots are lists of [quality, linenum] where quality
  " is the count of shared StemAndTail elements in the prefix.  linenum is
  " negative in the beforespots list so we choose the first line where parsed
  " is less than the next is preferred.  linenum is positive for afterspots so
  " we choose the last line parsed is greater than.  The best spot has the
  " highest quality, then the last in the list.  beforespots is preferred to
  " afterspots.
  let l:beforespots = []
  let l:afterspots = []
  " Rust allows scoped use statements, but rather than figure out what scope
  " might be relevant, only work with top-level (no indent) statements.
  let l:existingStarts = imp#util#FindLines('\v\C^(pub )?use\s+', 1)
  for [l:line, l:text] in l:existingStarts
    let l:nextline = l:line + 1
    while match(l:text, ';') < 0 && l:nextline <= line('$')
      let l:text .= getline(l:nextline)
      let l:nextline += 1
    endwhile
    let l:statement = s:parseStatement(l:text)
    if l:statement.pub != l:parsed.pub
      " don't merge 'use foo::baz' with 'pub use foo::{bar}'
      continue
    endif
    for l:found in l:statement.FindNamed(l:sat[-1])
      let l:fsat = l:found.StemAndTail()
      if l:sat == l:fsat
        call s:logger.Debug('Already imported "%s" in "%s"', a:choice, l:text)
        return {'inserted': 0, 'success': 1, 'import': a:choice}
      endif
    endfor
    let l:ssat = l:statement.StemAndTail()
    if !empty(l:statement.children)
          \ && (l:sat ==# l:ssat || l:sat[0:-2] ==# l:ssat)
      let l:child = s:newUseStatement(l:ssat)
      if l:sat ==# l:ssat
        let l:child.tail = ['self']
      elseif l:sat[0:-2] ==# l:ssat
        let l:child.tail = [l:sat[-1]]
      endif
      let l:child.alias = l:parsed.alias
      call add(l:statement.children, l:child)
      call sort(l:statement.children, function('s:compareUseStatements'))
      call setline(l:line, l:statement.ToString())
      if l:line + 1 < l:nextline
        execute printf('%d,%ddelete _', l:line + 1, l:nextline - 1)
      endif
      return {'inserted': 1, 'success': 1, 'import': a:choice}
    endif
    let l:shared = imp#util#SharedPrefix(l:sat, l:ssat)
    " If imports are sorted, append after the last use that's lexically less
    if imp#util#CompareLists(function('s:compareUseIdent'), l:sat, l:ssat) < 0
      call add(l:beforespots, [len(l:shared), -(l:line-1)])
    else
      call add(l:afterspots, [len(l:shared), l:nextline-1])
    endif
  endfor
  if empty(l:beforespots) && empty(l:afterspots)
    let l:beforespots = [0, 0]
  endif
  for l:list in [l:beforespots, l:afterspots]
    call sort(l:list, {a, b -> a[0] == b[0] ? a[1] - b[1] : a[0] - b[0]})
  endfor
  if !empty(l:beforespots) &&
        \ (empty(l:afterspots) || l:beforespots[-1][0] >= l:afterspots[-1][0])
    let l:goodspot = abs(l:beforespots[-1][1])
  else
    let l:goodspot = l:afterspots[-1][1]
  endif
  if l:goodspot == 0
    while imp#util#IsCommentLine(l:goodspot + 1)
      let l:goodspot += 1
    endwhile
  endif
  call append(l:goodspot, l:parsed.ToString())
  return {'inserted': 1, 'success': 1, 'import': a:choice}
endfunction

function! s:parseImport(context, symbol, line) abort
  let l:parsed = s:parseStatement(a:line)
  if l:parsed.IsEmpty()
    return {}
  endif
  let l:named = l:parsed.FindNamed(a:symbol)
  if empty(l:named)
    return {}
  endif
  call sort(l:named, {a, b -> len(a) - len(b)})
  let best = l:named[-1]
  return imp#NewImport(a:symbol, l:best.ToString())
endfunction

function! s:parseStatement(statement) abort
  call s:logger.Debug('Parsing %s', a:statement)
  let l:base = s:newUseStatement([])
  let l:states = {'Start': function('s:lexerState')}
  let l:lexer = imp#lex#NewLexer(l:states, a:statement)
  if !l:lexer.Lex() || empty(l:lexer.tokens)
    call s:logger.Warn('Could not parse "%s"', a:statement)
    call s:logger.Debug('Lexing "%s" got %s', a:statement, l:lexer.tokens)
    return l:base
  endif
  let l:first = l:lexer.tokens[0]
  if l:first.type !=# 'identifier' ||
        \ (l:first.text !=# 'use' && l:first.text !=# 'pub')
    call s:logger.Debug('Statement does not start with use: "%s"', a:statement)
    return l:base
  endif
  if l:first.text ==# 'pub'
    if len(l:lexer.tokens) == 1
      call s:logger.Debug('pub not followed by use: "%s"', a:statement)
      return l:base
    endif
    let l:base.pub = 1
    let l:rest = l:lexer.tokens[2:]
  else
    let l:rest = l:lexer.tokens[1:]
  endif
  let [l:parsed, l:rest] = s:parseGroupTokens(l:base, l:rest)
  if len(l:parsed) == 1
    call s:logger.Debug('Parsed statement "%s"', l:parsed[0])
    return l:parsed[0]
  endif
  if len(l:parsed) == 0
    call s:logger.Debug('No use statements in "%s"', a:statement)
    return s:newUseStatement([])
  endif
  call s:logger.Debug('Too many use statements in "%s: %s"',
        \ a:statement, l:parsed)
  return s:newUseStatement([])
endfunction

function! s:lexerState() abort dict
  call self.ReadWhitespaceOrNewline()
  if self.AtEnd()
    return 'done'
  endif
  let l:first = self.PeekChar()
  if l:first =~# '\k'
    call self.EmitToken(self.ReadIdentifier())
  elseif l:first ==# ':'
    let l:t = self.ReadPatternAs('::', 'colons')
    if empty(l:t)
      return 'error'
    endif
    call self.EmitToken(l:t)
  elseif l:first ==# ','
    call self.EmitToken(self.ReadCharAs('comma'))
  elseif l:first ==# '{'
    call self.EmitToken(self.ReadCharAs('open'))
  elseif l:first ==# '}'
    call self.EmitToken(self.ReadCharAs('close'))
  elseif l:first ==# ';'
    call self.EmitToken(self.ReadCharAs('semicolon'))
  elseif l:first ==# '*'
    call self.EmitToken(self.ReadCharAs('wildcard'))
    return 'done'
  elseif l:first ==# '/'
    " can't handle comments in the middle of a statement
    return 'error'
    " if self.PeekChars(2) == '//'
    "   call self.ReadPatternAs('//.*', 'comment')
    " elseif self.PeekChars(2) == '/*'
    "   call self.ReadDelimitedAs('*/', '', 'comment')
    " else
    "   return 'error'
    " endif
  else
    return 'error'
  endif
  return 'Start'
endfunction

" note: `use {};` and `use foo::bar::{};` are syntactically valid but do
" nothing; `use foo::{bar,}` is valid, so don't add empty paths to result
function! s:parseGroupTokens(base, tokens) abort
  let l:results = []
  let l:rest = a:tokens
  let l:cur = s:newUseStatement(a:base.StemAndTail())
  let l:cur.pub = a:base.pub
  while !empty(l:rest)
    let l:token = l:rest[0]
    let l:rest = l:rest[1:]
    " if l:token.type ==# 'comment'
    "   call s:logger.Debug('Stopping parsing on comment')
    "   " can't preserve comments inside a statement, so give up
    "   return []
    " endif
    if l:token.type ==# 'identifier' || l:token.type ==# 'wildcard'
      if l:token.text ==# 'as'
        if empty(l:rest)
          call s:logger.Debug('as token without alias in %s', a:tokens)
          return [[], []]
        endif
        let l:next = l:rest[0]
        let l:rest = l:rest[1:]
        if l:next.type !=# 'identifier'
          call s:logger.Debug('invalid alias in %s', a:tokens)
          return [[], []]
        endif
        let l:cur.alias = l:next.text
      else
        call add(l:cur.tail, l:token.text)
      endif
    elseif l:token.type ==# 'comma'
      if !l:cur.IsEmpty()
        call add(l:results, l:cur)
        let l:cur = s:newUseStatement(a:base.StemAndTail())
        let l:cur.pub = a:base.pub
      endif
    elseif l:token.type ==# 'open'
      let [l:kids, l:rest] = s:parseGroupTokens(l:cur, l:rest)
      call extend(l:cur.children, l:kids)
    elseif l:token.type ==# 'close' || l:token.type == 'semicolon'
      break
    elseif l:token.type ==# 'colons'
      continue
    else
      call s:logger.Debug('unexpected token %s in %s', l:token, a:tokens)
      return [[], []]
    endif
  endwhile
  if !l:cur.IsEmpty()
    call add(l:results, l:cur)
  endif
  return [l:results, l:rest]
endfunction

function s:newUseStatement(stem) abort
  return {'stem': a:stem, 'tail': [], 'alias': '', 'children': [], 'pub': 0,
        \ 'IsEmpty': function('s:usIsEmpty'),
        \ 'ToString': function('s:usToString'),
        \ 'ToStringRelative': function('s:usToStringRelative'),
        \ 'StemAndTail': function('s:usStemAndTail'),
        \ 'FindNamed': function('s:usFindNamed')}
endfunction

function! s:usIsEmpty() abort dict
  return empty(self.tail) && empty(self.children)
endfunction

function! s:usToString() abort dict
  let l:parts = copy(self.stem)
  let l:rel = self.ToStringRelative()
  if !empty(l:rel)
    call add(l:parts, l:rel)
  endif
  let l:alias = empty(self.alias) ? '' : ' as ' . self.alias
  let l:pub = self.pub ? 'pub ' : ''
  return printf('%suse %s%s;', l:pub, join(l:parts, '::'), l:alias)
endfunction

function! s:usToStringRelative() abort dict
  let l:parts = copy(self.tail)
  if !empty(self.children)
    let l:kids = maktaba#function#Map(self.children,
          \ {c -> c.ToStringRelative()})
    call add(l:parts, printf('{%s}', join(l:kids, ', ')))
  endif
  return join(l:parts, '::')
endfunction

function! s:usStemAndTail() abort dict
  return self.stem + self.tail
endfunction

function! s:usFindNamed(ident) abort dict
  let l:qualified = split(a:ident, '::')
  if empty(l:qualified)
    return []
  endif
  let l:ident = l:qualified[-1]
  let l:qualified = l:qualified[:-2]
  let l:results = []
  let l:prefix = slice(self.StemAndTail(), 0, -1)
  let l:prematch = imp#util#SharedSuffix(l:qualified, l:prefix) ==# l:qualified
  let l:stemend = empty(self.stem) ? '' : self.stem[-1]
  let l:tailend = empty(self.tail) ? '' : self.tail[-1]
  if empty(self.children)
    if self.alias ==# l:ident && l:prematch
      let l:us = copy(self)
      call add(l:results, l:us)
    elseif self.alias ==# '' && l:tailend ==# l:ident && l:prematch
      let l:us = copy(self)
      call add(l:results, l:us)
    endif
  else
    for l:c in self.children
      let l:cpmatch = imp#util#SharedSuffix(
            \l:qualified, slice(l:c.StemAndTail(), 0, -1)) ==# l:qualified
      if !empty(l:c.tail) && l:c.alias ==# '' && l:c.tail[-1] ==# 'self'
            \ && (l:stemend ==# l:ident || l:tailend ==# l:ident) && l:cpmatch
        let l:us = copy(self)
        let l:us.children = []
        call add(l:results, l:us)
      endif
      call extend(l:results, l:c.FindNamed(a:ident))
    endfor
  endif
  return l:results
endfunction

function! s:compareUseStatements(first, second) abort
  let l:asat = a:first.StemAndTail()
  let l:bsat = a:second.StemAndTail()
  return imp#util#CompareLists(function('s:compareUseIdent'), l:asat, l:bsat)
endfunction

function! s:compareUseIdent(a, b) abort
  if a:a ==# a:b
    return 0
  endif
  " self and super sort early
  if a:a ==# 'self'
    return -1
  endif
  if a:b ==# 'self'
    return 1
  endif
  if a:a ==# 'super'
    return -1
  endif
  if a:b ==# 'super'
    return 1
  endif
  " wildcards go at the end of a nested group
  if a:a ==# '*'
    return 1
  endif
  if a:b ==# '*'
    return -1
  endif
  if a:a <# a:b
    return -1
  endif
  return 1
endfunction
