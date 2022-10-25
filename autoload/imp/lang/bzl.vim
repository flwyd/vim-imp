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

" Bazel import handling, supports load("/path/to:foo.bzl", "bar_library")
" and load("@repo//path/to:foo.bzl", renamed_lib = "bar_library") with optional
" line breaks after arguments.  For syntax information, see
" https://docs.bazel.build/versions/main/build-ref.html#load
" Pattern only matches labels with absolute paths, not package-relative labels.

" TODO Have parseTokens set a multiline property and use newline rather than
" space as argument separator in loadToString.  Import would need to split on
" newline.  Could also preserve inline comment positions.

let s:logger = maktaba#log#Logger('imp#lang#bzl')

function! imp#lang#bzl#Pattern(context, style, symbol) abort
  " Rather than escaping symbol, make sure it's a valid identifier
  if a:symbol !~# '\v^\k+$'
    return {}
  endif
  let l:prefix = '^\s*load\s*'
  if a:style ==# 'vim'
    let l:prefix = '\v\C' . l:prefix
  endif
  let l:target = '\s*"[/@][^"]+"\s*'
  if a:style ==# 'posix_basic'
    let l:main =
          \ printf('%s(%s,[^)]*"%s"', l:prefix, l:target, a:symbol)
    let l:kwarg =
          \ printf('%s(%s,\(\s*(\w+\s*=\s*\)?"\w\+"\s*,\)\s*%s\s*=\s*"\w+"',
          \ l:prefix, l:target, a:symbol)
  else
    let l:main =
          \ printf('%s\(%s,[^)]*"%s"', l:prefix, l:target, a:symbol)
    let l:kwarg =
          \ printf('%s\(%s,(\s*(\w+\s*=\s*)?"\w+"\s*,)*\s*%s\s*=\s*"\w+"',
          \ l:prefix, l:target, a:symbol)
  endif
  return {'patterns': [l:main, l:kwarg],
        \ 'fileglobs': ['*.bzl', '*.bazel', 'BUILD'],
        \ 'multiline': 1,
        \ 'style': a:style,
        \ 'Parse': function('s:parseImport')}
endfunction

function! s:parseImport(context, symbol, line) abort
  let l:parsed = s:parseStatement(a:line)
  if empty(l:parsed)
    let l:sym = imp#pattern#Escape('vim', a:symbol) . '\v'
    let l:match = matchlist(a:line,
          \ printf('\v\C\load\_s*\(\_s*("[^"]+"),.*("%s")', l:sym))
    if empty(l:match)
      return {}
    endif
    return imp#NewImport(a:symbol,
          \ printf('load(%s, %s) # TODO double check %s from %s',
          \ l:match[1], l:match[2], a:symbol, a:line))
  endif
  let l:solo = copy(l:parsed)
  let l:rulepat = printf('\v["'']+\V%s\v["'']', a:symbol)
  for l:rule in l:parsed.rules
    if l:rule.name =~# l:rulepat || a:symbol ==# l:rule.rename
      let l:solo.rules = [l:rule]
      return imp#NewImport(a:symbol, s:loadToString(l:solo))
    endif
  endfor
  " somehow didn't match?
  let l:solo.rules = [{'name': '"' . a:symbol . '"', 'rename': ''}]
  return imp#NewImport(a:symbol,
        \ printf('%s # TODO double check %s from %s',
        \ s:loadToString(l:solo), a:symbol, a:line))
endfunction

function! imp#lang#bzl#Suggest(context, symbol) abort
  let l:move = "\<S-Left>" . repeat("\<Left>", 3)
  let l:suggest = printf('load("", "%s")%s', a:symbol, l:move)
  let l:statement = input(a:symbol . ': ', l:suggest)
  return empty(l:statement) ? [] : [imp#NewImport(a:symbol, l:statement)]
endfunction

function! imp#lang#bzl#Insert(context, imports) abort
  let l:result = 1
  for l:import in a:imports
    let l:parsed = s:parseStatement(l:import.statement)
    if empty(l:parsed)
      " TODO add an 'invalid' list to context
      let l:result = 0
      continue
    endif
    let l:position = s:position(l:parsed)
    if l:position.action ==# 'noop'
      let a:context.already_imported += [l:import]
    elseif l:position.action ==# 'above'
      call append(l:position.line - 1, l:import.statement)
      let a:context.imported += [l:import]
      " Add a blank line between e.g. load() and package()
      if get(l:position, 'addblank', 0)
        call append(l:position.line, '')
      endif
    elseif l:position.action ==# 'below'
      call append(l:position.line + l:position.extra, l:import.statement)
      let a:context.imported += [l:import]
      if get(l:position, 'addblank', 0)
        call append(l:position.line, '')
      endif
    elseif l:position.action ==# 'merge'
      let l:merged = l:position.parsed
      let l:merged.rules = uniq(sort(l:merged.rules + l:parsed.rules))
      let l:merged.comments += l:parsed.comments
      call setline(l:position.line, s:loadToString(l:merged))
      " TODO use deleletebufline/:delete to remove extra lines
      for l:line in range(l:position.line + 1,
            \ l:position.line + l:position.extra)
        call setline(l:line, '')
      endfor
      let a:context.imported += [l:import]
    else
      throw maktaba#error#BadValue(
            \ 'update position cases', '', l:position.action)
    endif
  endfor
  return l:result
endfunction

" Finds the line where a parsed {load} statement should be inserted and how to
" do the insertion. Returns a dict with `action`, `line`, and `extra` keys.
" `line` is the line number where action should be taken, `extra` is the number
" of additinoal lines that the load statement currently at that line takes, or
" 0 if the load statement is just one line or if there is no load at the line.
" `action` is `above` to insert before, `below` to insert after, `merge` to
" combine {load} with the returned `parsed` property, and `noop` should take no
" action because the load statement is already present in the file.  An optional
" `addblank` property indicates a blank line should be added.
function! s:position(load) abort
  let l:source = s:unquote(a:load.label)
  let l:loadpos = {}
  let l:CommentOrDocstring = maktaba#function#WithArgs(
        \ 'imp#util#IsSyntaxLine', ['comment', 'Constant'])
  let l:loadlines = imp#util#FindLines(
        \ '\v\C^load\(', l:CommentOrDocstring, function('s:matchEndOfImports'))
  if empty(l:loadlines)
    for l:linenum in range(1, line('$'))
      let l:line= getline(l:linenum)
      if s:matchEndOfImports(l:line)
        return {'action': 'above', 'line': l:linenum, 'extra': 0,
              \ 'addblank': !empty(l:line)}
      endif
    endfor
    return {'action': 'below', 'line': line('$'), 'extra': 0,
          \ 'addblank': !empty(getline(line('$')))}
  endif
  for [l:linenum, l:linetext] in l:loadlines
    let l:parsed = s:parseStatement(l:linetext)
    let l:extra = 0
    let l:giveup = 0
    while (empty(l:parsed) || !l:parsed.complete) && !l:giveup
      let l:extra += 1
      let l:nextline = getline(l:linenum + l:extra)
      " if the continuation line isn't a string, close paren, or comment then
      " it was probably an invalid load statement, so don't try to merge with it
      if l:nextline !~# '\v^\s*["''#)]'
        let l:giveup = 1
      else
        let l:linetext .= "\n" . l:nextline
        let l:parsed = s:parseStatement(l:linetext)
      endif
    endwhile
    if !empty(l:parsed)
      let l:unquoted = s:unquote(l:parsed.label)
      if l:source ==# l:unquoted
        if len(imp#util#Intersection(a:load.rules, l:parsed.rules))
              \ == len(a:load.rules)
          " symbol already imported from source
          return {'action': 'noop', 'line': l:linenum, 'extra': l:extra}
        else
          return {'action': 'merge', 'line': l:linenum, 'extra': l:extra,
                \ 'parsed': l:parsed}
        endif
      else
        let l:loadpos[l:unquoted] = {'line': l:linenum, 'extra': l:extra}
      endif
    endif
  endfor
  " No existing import from this source, insert it in alphabetic order
  let l:max = {'line': 0, 'extra': 0}
  for l:s in sort(keys(l:loadpos))
    let l:pos = l:loadpos[l:s]
    if l:source <=# l:s
      return {'action': 'above', 'line': l:pos.line, 'extra': l:pos.extra}
    elseif l:pos.line >= l:max.line
      let l:max = l:pos
    endif
  endfor
  " Alphabetically the last import
  return {'action': 'below', 'line': l:max.line, 'extra': l:max.extra}
endfunction

function! s:unquote(str) abort
  if maktaba#string#StartsWith(a:str, '"""')
    return substitute(a:str, '\v^"""(.*)"""$', '\1', '')
  elseif maktaba#string#StartsWith(a:str, "'''")
    return substitute(a:str, "\v^'''(.*)'''$", '\1', '')
  elseif maktaba#string#StartsWith(a:str, '"')
    return substitute(a:str, '\v^"(.*)"$', '\1', '')
  elseif maktaba#string#StartsWith(a:str, "'")
    return substitute(a:str, "\v^'(.*)'$", '\1', '')
  endif
  return str
endfunction

" Bazel load statements should appear before the package() declaration or any
" rule declarations or function definitions.  This currently does not match
" variable declarations.
function! s:matchEndOfImports(line) abort
  return maktaba#string#StartsWith(a:line, 'def ')
        \ || maktaba#string#StartsWith(a:line, 'package(')
        \ || (!maktaba#string#StartsWith(a:line, 'load(')
        \    && a:line =~# '\v^\k+\(')
endfunction

" Parses a string into a load statement dict, or an empty dict if no parse
" was possible.
function! s:parseStatement(statement) abort
  " open is a stack of opening parens, brackets, and braces
  let l:lexer = imp#lex#NewLexer({
        \ 'ReadWhitespace': function('s:lexerReadWhitespace'),
        \ 'Start': function('s:lexerState'),
        \ 'open': []},
        \ a:statement)
  if !l:lexer.Lex() || empty(l:lexer.tokens)
    call s:logger.Warn('Could not parse "%s"', a:statement)
    call s:logger.Debug('Lexing "%s" got tokens %s',
          \ a:statement, l:lexer.tokens)
    return {}
  endif
  return s:parseTokens(l:lexer.tokens)
endfunction

" Parses a list of lexed tokens and returns a structure like
" {'label': '/path/to:label.bzl', 'rules': ['foo_lib', 'bar_lib'],
"   comments: ['#some inline comment']} or an empty dict if it couldn't be
" parsed as a valid load statement.
function! s:parseTokens(tokens) abort
  " Whitespace doesn't matter in load statements
  " TODO Filter isn't supposed to modify input, see
  " https://github.com/google/vim-maktaba/issues/250
  let l:tokens = maktaba#function#Filter(
        \ copy(a:tokens),
        \ {t -> !maktaba#value#IsIn(t.type, ['whitespace', 'newline'])})
  " Preserve inline comments, but move them out of the statement
  let l:comments = maktaba#function#Map(
        \ maktaba#function#Filter(copy(l:tokens), {t -> t.type ==# 'comment'}),
        \ {t -> t.text})
  if !empty(l:comments)
    let l:tokens = maktaba#function#Filter(
        \ copy(l:tokens), {t -> t.type !=# 'comment'})
  endif
  if empty(l:tokens)
    " Nothing interesting in tokens
    return {}
  endif
  let l:i = 0
  if l:tokens[l:i].type !=# 'identifier' || l:tokens[l:i].text !=# 'load'
    " Only care about load statements
    return {}
  endif
  let l:i += 1
  if l:tokens[l:i].type !=# 'open' && l:tokens[l:i].text !=# '('
    " load must be followed by open paren
    return {}
  endif
  let l:i += 1
  if l:i == len(l:tokens) || l:tokens[l:i].type !=# 'string'
    " Doesn't look like load("/path/to:file.bzl"...
    return {}
  endif
  let l:result =
        \ {'label': l:tokens[l:i].text, 'rules': [], 'comments': l:comments,
        \ 'complete': 0}
  let l:i += 1
  while l:i < len(l:tokens)
    if l:tokens[l:i].type ==# 'close' && l:tokens[l:i].text ==# ')'
      let l:result.complete = 1
      return l:result
    endif
    if l:tokens[l:i].type !=# 'punctuation' || l:tokens[l:i].text !=# ','
      " Should be a comma token after each arg in load()
      return {}
    endif
    let l:i += 1
    " Incomplete load statement, we can close it later
    if l:i == len(l:tokens)
      return l:result
    endif
    " Trailing comma before closing paren, valid
    if l:tokens[l:i].type ==# 'close' && l:tokens[l:i].text ==# ')'
      let l:result.complete = 1
      return l:result
    endif
    if l:tokens[l:i].type ==# 'identifier'
      let l:rename = l:tokens[l:i].text
      let l:i += 1
      if l:i == len(l:tokens)
            \ || !(l:tokens[l:i].type ==# 'punctuation'
            \ && l:tokens[l:i].text ==# '=')
        return {}
      endif
      let l:i += 1
    else
      let l:rename = ''
    endif
    if l:tokens[l:i].type ==# 'string'
      let l:result.rules += [{'name': l:tokens[l:i].text, 'rename': l:rename}]
      let l:i += 1
    else
      " Unexpected token in load statement
      return {}
    endif
  endwhile
  " No closing paren, but got a partial load statement
  return l:result
endfunction

function! s:loadToString(load) abort
  if empty(a:load.comments)
    let l:comments = ''
  else
    let l:comments = '  ' . join(a:load.comments, '  ')
  endif
  let l:rules = join(
        \ maktaba#function#Map(a:load.rules, function('s:ruleToString')), ', ')
  return printf('load(%s, %s)%s', a:load.label, l:rules, l:comments)
endfunction

function! s:ruleToString(rule) abort
  if empty(a:rule.rename)
    return a:rule.name
  endif
  return printf('%s = %s', a:rule.rename, a:rule.name)
endfunction

" Matching punctuation for open token stack management.
let s:punctuationMatch = {'(': ')', '[': ']', '{': '}'}

" Lexer state which reads python identifiers, comments, whitespace, newlines,
" strings, and a limited set of punctuation.
" After each non-whitespace token, transitions to itself, or 'done' or 'error'.
function! s:lexerState() abort dict
  call self.ReadWhitespace()
  if self.AtEnd()
    return 'done'
  endif
  let l:first = self.PeekChar()
  if l:first =~# '\k'
    call self.EmitToken(self.ReadIdentifier())
  elseif l:first ==# "\r" || l:first ==# "\n"
    call self.EmitToken(self.ReadNewline())
  elseif l:first ==# '#'
    call self.EmitToken(self.ReadPatternAs('\v^\#[^\n]*', 'comment'))
  elseif l:first ==# '"' || l:first ==# "'"
    if maktaba#value#IsIn(self.PeekChars(3), ['"""', "'''"])
      call self.EmitToken(
            \ self.ReadDelimitedAs(repeat(l:first, 3), '\', 'string'))
    else
      call self.EmitToken(self.ReadDelimitedAs(l:first, '\', 'string'))
    endif
  elseif maktaba#value#IsIn(l:first,
        \ ['.', ',', '+', '-', '*', '/', '%', '=', ':', ';', '|', '<', '>'])
    call self.EmitToken(self.ReadCharAs('punctuation'))
  elseif maktaba#value#IsIn(l:first, ['(', '[', '{',])
    let l:token = self.ReadCharAs('open')
    let l:token.depth = len(self.open)
    call add(self.open, l:token)
    call self.EmitToken(l:token)
  elseif maktaba#value#IsIn(l:first, [')', ']', '}'])
    if empty(self.open)
      call s:logger.Debug('Got extra closing punctuation "%s" at %s in "%s"',
            \ l:first, self.position, self.text)
      return 'error'
    endif
    if s:punctuationMatch[self.open[-1].text] !=# l:first
      call s:logger.Debug(
            \ 'Closing punctuation "%s" does not match opening "%s" at %s in "%s"',
            \ l:first, self.open[-1].text, self.position, self.text)
      return 'error'
    endif
    let l:token = self.ReadCharAs('close')
    call remove(self.open, -1)
    let l:token.depth = len(self.open)
    call self.EmitToken(l:token)
  else
    call s:logger.Debug('Got unexpected char "%s" in "%s"', l:first, self.text)
    return 'error'
  endif
  return 'Start'
endfunction

" Replacement for imp#lex#ReadWhitespace which handles line continuation
" (backslash newline) as part of a whitespace token.
function! s:lexerReadWhitespace() abort dict
  return self.ReadPatternAs('\v^((\s*\\(\r\n|\r|\n)\s*)|\s+)+', 'whitespace')
endfunction
