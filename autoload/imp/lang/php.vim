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

" Import handling for use statements in PHP, see examples at
" https://www.php.net/manual/en/language.namespaces.importing.php
" Language notes:
" * Namespace separator is backslash (\), leading \ is optional.
" * 'use', 'use function', and 'use const' are typed prefixes.
" * Imports can be aliased with 'as'.
" * Multiple imports in one statement are separated by commas.
" * Names are resolved when used, not when imported.
" * No block-scoped use statements for imports, but classes can have use
"   statements to apply a trait.
" * Namespaces, class names, and functions are not case sensitive, but
"   constants and variables are.  Matching case is probably okay to encourage
"   consistent code.
" * Class constants cannot be imported but namespace-level ones can.
" * Grouping can combine import types and multiple namespaces:
"   use A\B\{C\D, const E\F\G, function H\I, J\K\L};
" * Grouping cannot be nested (use A\B\{C\{D, E}, F\{G, H};).
" * Whitespace and comments don't seem to be allowed within a namespace path
"   but are allowed around curly braces and commas.
" * 'use ($foo, $bar)' is also used in function closures, not relevant here.

" TODO PHP allows 0x80 through 0xff in identifiers ("labels"), which means
" some but not all multi-byte UTF-8 sequences are allowed too.  Decide if it's
" worth caring enough to support this bad idea.

let s:logger = maktaba#log#Logger('imp#lang#php')

function! imp#lang#php#Suggest(context, symbol) abort
  let l:kind = s:guessKind(a:symbol)
  " Data suggests functions and constants usually imported without namespace
  let l:prefix = l:kind ==# 'class' ? '\' :  l:kind . ' '
  let l:suggest = printf("use %s%s;\<S-Left>", l:prefix,  a:symbol)
  let l:statement = input(a:symbol . ': ', l:suggest)
  return empty(l:statement) ? [] : [imp#NewImport(a:symbol, l:statement)]
endfunction

function! imp#lang#php#Insert(context, imports) abort
  let l:result = 1
  for l:import in a:imports
    let l:position = s:position(l:import)
    if l:position >= 0
      call append(l:position, l:import.statement)
      call add(a:context.imported, l:import)
    elseif l:position == -1
      call add(a:context.already_imported, l:import)
    else
      let l:result = 0
    endif
  endfor
  return 1
endfunction

function! s:position(import) abort
  let l:imp = s:parseStatement(a:import.statement)
  if empty(l:imp)
    call s:logger.Debug(
          \ 'Could not parse statement for import: %s', a:import.statement)
    return -2
  endif
  let l:alphaposition = 0
  let l:last = 0
  let l:uselines = imp#util#FindLines('\v\c^\s*use\s+\\?\w+', 1)
  for [l:linenum, l:line] in l:uselines
    let l:parsed = s:parseStatement(l:line)
    if empty(l:parsed)
      continue
    endif
    if s:containsImport(l:parsed, l:imp)
      return -1  " already imported
    endif
    if l:alphaposition == 0
          \ && trim(tolower(a:import.statement)) <# trim(tolower(l:line))
      let l:alphaposition = l:linenum - 1
    endif
    let l:last = l:linenum
  endfor
  if l:alphaposition > 0
    return l:alphaposition
  endif
  if l:last > 0
    return l:last  " sorts after all use import statements
  endif
  let l:nslines = imp#util#FindLines('\v\c^\s*namespace\s+(\w|\\)+\s*;', 1)
  if !empty(l:nslines)
    return l:nslines[0][1]  " no other imports, insert after first namespace
  endif
  let l:phplines = imp#util#FindLines('\v\c^\s*\<\?php>', 1)
  if !empty(l:phplines)
    return l:phplines[0][1]  " no namespace, insert after first <?php
  endif
  " maybe an HTML file or it just contains literal output
  call append(0, '<?php')
  return 1
endfunction

let s:whitespace = imp#re#AsciiWhitespace().AtLeastOnce()
let s:maybeWhitespace = imp#re#AsciiWhitespace().AnyTimes()
let s:kindLiteral = imp#re#Or(
      \ [imp#re#Literal('const'), imp#re#Literal('function')]).Named('kind')
let s:maybeKind = imp#re#Sequence([s:kindLiteral, s:whitespace]).MaybeOnce()
let s:identifier = imp#re#AsciiWord().AtLeastOnce()
let s:namespace = imp#re#Sequence([
      \ imp#re#Literal('\').MaybeOnce(),
      \ imp#re#Group([s:identifier, imp#re#Literal('\')]).AtLeastOnce()])
let s:optionalNamespace = imp#re#Sequence([
      \ imp#re#Literal('\').MaybeOnce(),
      \ imp#re#Group([s:identifier, imp#re#Literal('\')]).AnyTimes()])
let s:qualifiedIdentifier = imp#re#Sequence([
      \ s:optionalNamespace, s:identifier])
let s:qualifiedSymbol = imp#re#Sequence([
      \ s:optionalNamespace, s:identifier.Named('symbol')])
let s:maybeAliasedIdentifier = imp#re#Sequence([s:qualifiedIdentifier,
      \ imp#re#Group([
      \ s:whitespace, imp#re#Literal('as'),
      \ s:whitespace, s:identifier]).MaybeOnce()])
let s:aliasedToSymbol = imp#re#Sequence([s:qualifiedIdentifier,
      \ s:whitespace, imp#re#Literal('as'),
      \ s:whitespace, s:identifier.Named('symbol')])
" Allow the leading part of `use \Foo\Bar, Baz\Qux, Path\To\Symbol;`
let s:importListTrailingComma = imp#re#Group([
      \ s:maybeKind, s:maybeAliasedIdentifier, s:maybeWhitespace,
      \ imp#re#Literal(','), s:maybeWhitespace]).AnyTimes()
" Allow the trailing part of `use Path\To\Symbol, \Foo\Bar, Baz\Qux;`
let s:importListLeadingComma = imp#re#Group([
      \ imp#re#Literal(','), s:maybeWhitespace,
      \ s:maybeKind, s:maybeAliasedIdentifier, s:maybeWhitespace]).AnyTimes()
" Anchor to start of line to avoid `use trait` and closures
let s:usePrefix = imp#re#Sequence([
      \ imp#re#LineStart(), imp#re#Literal('use'), s:whitespace, s:maybeKind])
" Style of use statements:
" Style #1: `use Path\To\Symbol;`
let s:useSymbol = imp#re#Pattern([s:usePrefix, s:importListTrailingComma,
      \ s:qualifiedSymbol.Named('qualifiedsymbol'),
      \ s:maybeWhitespace, s:importListLeadingComma, imp#re#Literal(';')])
" Style #2: `use Path\To\Something as Symbol;`
let s:useAliasedSymbol =
      \ s:useSymbol.Replace('qualifiedsymbol', s:aliasedToSymbol)
" Style #3: `use Path\To\{Foo, Something, Subpath\Bar};`
let s:useGroupedSymbol = s:useSymbol.Replace('qualifiedsymbol',
      \ imp#re#Sequence([
      \ s:namespace, imp#re#Literal('{'), s:maybeWhitespace,
      \ s:importListTrailingComma, s:maybeKind,
      \ s:qualifiedSymbol.Named('symbolingroup'),
      \ s:maybeWhitespace, s:importListLeadingComma,
      \ imp#re#Literal(',').MaybeOnce(), s:maybeWhitespace,
      \ imp#re#Literal('}')]))
" Style #4: `use Path\To\{Foo, Something as Symbol, Subpath\Bar};`
let s:useGroupedAliasedSymbol =
      \ s:useGroupedSymbol.Replace('symbolingroup', s:aliasedToSymbol)

function! imp#lang#php#Pattern(context, style, symbol) abort
  let l:word = imp#re#Literal(a:symbol)
  let l:patterns = maktaba#function#Map(
        \ [s:useSymbol, s:useAliasedSymbol, s:useGroupedSymbol,
        \ s:useGroupedAliasedSymbol],
        \ {p -> p.Replace('symbol', l:word).InStyle(a:style)})
  return {'patterns': l:patterns, 'style': a:style, 'multiline': 1,
        \ 'fileglobs': ['*.php', '*.phar', '*.phtml', '*.pht', '*.phps'],
        \ 'Parse': function('s:parseImport')}
endfunction

function! s:parseImport(context, symbol, line) abort
  let l:parsed = s:parseStatement(a:line)
  if empty(l:parsed)
    return {}
  endif
  let l:kind = empty(l:parsed.kind) ? '' : l:parsed.kind . ' '
  let l:import = ''
  for l:name in l:parsed.names
    if l:name.alias ==# a:symbol
          \ || empty(l:name.alias) && l:name.fqname[-1] ==# a:symbol
      let l:import = l:parsed.groupPrefix . s:nameToString(l:name, 1)
      if !empty(l:name.kind)
        let l:kind = l:name.kind . ' '
      endif
      break
    endif
  endfor
  if empty(l:import)
    call s:logger.Debug('Could not find symbol %s from %s in statement: %s',
          \ a:symbol, l:parsed, a:line)
    return {}
  endif
  let l:statement = printf('use %s%s;', l:kind, l:import)
  return imp#NewImport(a:symbol, l:statement)
endfunction

let s:importEnvelopePat = imp#re#Pattern([imp#re#LineStart(),
      \ imp#re#Literal('use'), s:whitespace, imp#re#Capture([s:maybeKind]),
      \ imp#re#Capture([imp#re#AnyCharacter().AtLeastOnce()]),
      \ imp#re#Literal(';')]).InStyle('vim')
let s:groupImportPat = imp#re#Pattern([
      \ imp#re#Capture([s:namespace]),
      \ imp#re#Literal('{'), s:maybeWhitespace,
      \ imp#re#Capture([
      \ s:importListTrailingComma, s:maybeKind, s:maybeAliasedIdentifier]),
      \ s:maybeWhitespace, imp#re#Literal(',').MaybeOnce(),
      \ s:maybeWhitespace, imp#re#Literal('}')]).InStyle('vim')
let s:singleImportPat = imp#re#Pattern([
      \ imp#re#Capture([s:qualifiedSymbol]),
      \ imp#re#Group([s:whitespace, imp#re#Literal('as'), s:whitespace,
        \ imp#re#Capture([s:identifier])]).MaybeOnce(),
      \ s:maybeWhitespace]).InStyle('vim')
function! s:parseStatement(statement) abort
  let l:match = matchlist(a:statement, s:importEnvelopePat)
  if empty(l:match)
    return {}
  endif
  let l:kind = trim(l:match[1])
  let l:body = l:match[2]
  let l:match = matchlist(l:body, s:groupImportPat)
  if !empty(l:match)
    let l:namespace = l:match[1]
    let l:children = split(l:match[2], ',')
    let l:names = maktaba#function#Map(l:children, function('s:parseName'))
    return {'kind': l:kind, 'groupPrefix': l:namespace, 'names': l:names}
  endif
  let l:result = {'kind': l:kind, 'names': [], 'groupPrefix': ''}
  for l:import in split(l:body, ',')
    let l:match = matchlist(trim(l:import), s:singleImportPat)
    if !empty(l:match)
      let l:qualified = l:match[1]
      let l:alias = l:match[2]
      call add(l:result.names, s:newName('', l:qualified, l:alias))
    endif
  endfor
  if empty(l:result.names)
    return {}
  endif
  return l:result
endfunction

function! s:containsImport(import1, import2) abort
  let l:norm = s:expandImport(a:import2)
  if len(l:norm) != 1
    return 0  " group-to-group matching, maybe this could be supported
  endif
  return index(s:expandImport(a:import1), l:norm[0]) >= 0
endfunction

function! s:expandImport(import) abort
  let l:result = []
  let l:prefix = empty(a:import.kind) ? '' : a:import.kind . ' '
  let l:prefix .= a:import.groupPrefix
  for l:name in a:import.names
    let l:full = l:prefix
    if empty(l:name.kind)
      let l:full .= s:nameToString(l:name)
    else
      " pull kind to the beginning of the statement from a group
      let l:full = printf('%s %s%s', l:name.kind, l:prefix,
            \ s:nameToString(l:name, 1))
    endif
    call add(l:result, l:full)
  endfor
  return l:result
endfunction

let s:parseNamePat = imp#re#Pattern([
      \ imp#re#Capture([s:maybeKind]),
      \ imp#re#Capture([s:qualifiedIdentifier]),
      \ imp#re#Group([s:whitespace, imp#re#Literal('as'), s:whitespace,
        \ imp#re#Capture([s:identifier])]).MaybeOnce()]
      \ ).InStyle('vim')
function! s:parseName(text) abort
  let l:parts = matchlist(a:text, s:parseNamePat)
  if empty(l:parts)
    return {}
  endif
  return s:newName(l:parts[1], l:parts[2], l:parts[3])
endfunction

function! s:newName(kind, fqname, alias) abort
  return {'kind': trim(a:kind), 'fqname': split(trim(a:fqname), '\\'),
        \ 'alias': trim(a:alias)}
endfunction

function! s:nameToString(name, ...) abort
  let l:skipKind = a:0 > 0 && a:1
  let l:s = ''
  if !l:skipKind && !empty(a:name.kind)
    let l:s .= a:name.kind . ' '
  endif
  let l:s .= join(a:name.fqname, '\')
  if !empty(a:name.alias)
    let l:s .= ' as ' . a:name.alias
  endif
  return l:s
endfunction

" General PHP convention uses ALL_CAPS for constants, snake_case or camelCase
" for functions and PascalCase for classes and namespaces.
function! s:guessKind(symbol) abort
  if a:symbol =~# '\v^[A-Z_]+$'
    return 'const'
  elseif a:symbol =~# '\v^[a-z]'
    return 'function'
  else
    return 'class'
  endif
endfunction
