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

" Python import handlers, matching `import x`, `import x as y, a.b.c`,
" `from x import a`, `from x.y import a, b.c, d as e`, etc.
" See https://docs.python.org/3/reference/import.html but note that relative
" import support is intentionally limited.

let s:logger = maktaba#log#Logger('imp#lang#python')

function! imp#lang#python#Pattern(context, style, symbol) abort
  if a:style ==# 'posix_basic'
    return {}  " TODO implement if needed
  endif
  let l:word = imp#pattern#Escape(a:style, a:symbol)
  let l:prefix = ''
  if a:style ==# 'vim'
    " make pattern very magic, case sensitive, and match at word boundaries
    let l:prefix = '\v\C'
    let l:word = printf('<%s\v>', l:word)
  elseif imp#pattern#SupportsPerlLookaround(a:style)
    " match at word boundaries, don't match if followed by a dot
    let l:word = printf('\b%s\b(?!\.)', l:word)
  else
    " match at word boundaries, require EOL or comma after symbol to avoid
    " matching 'foo' in 'import foo.bar'
    let l:word = printf('\b%s\b(,|$)', l:word)
  endif
  let l:pkg = '(\w+\.)*'
  let l:patterns = [
        \ printf('%s^\s*import\s+(%s\w+,\s*)*%s', l:prefix, l:pkg, l:word),
        \ printf('%s^\s*import\s+.+\s+as\s+%s', l:prefix, l:word),
        \ printf('%s^\s*from\s+.+\s+import\s+(%s\w+(\s+as\s+\w+)?\s*,\s*)*%s',
        \ l:prefix, l:pkg, l:word),
        \ printf('%s^\s*from\s+.+\s+import\s+(%s\w+(\s+as\s+\w+)?\s*,\s*)*\w+\s+as\s+%s',
        \ l:prefix, l:pkg, l:word),
        \ ]
  return {'patterns': l:patterns, 'fileglobs': ['*.py'], 'style': a:style,
        \ 'Parse': function('s:parseImport')}
endfunction

function! s:parseImport(context, symbol, line) abort
  let l:p = s:parseStatement(a:line)
  if empty(l:p)
    return {}
  endif
  if l:p.type ==# 'import'
    for l:mod in l:p.modules
      if l:mod.alias ==# a:symbol
        return imp#NewImport(a:symbol, 'import ' . s:aliasedToString(l:mod))
      elseif l:mod.name ==# a:symbol
            \ || maktaba#string#EndsWith(l:mod.name, '.' . a:symbol)
        return imp#NewImport(a:symbol, 'import ' . l:mod.name)
      endif
    endfor
  elseif l:p.type ==# 'from'
    for l:name in l:p.names
      if l:name.alias ==# a:symbol
        return imp#NewImport(a:symbol, printf(
              \ 'from %s import %s', l:p.module, s:aliasedToString(l:name)))
      elseif l:name.name ==# a:symbol
            \ || maktaba#string#EndsWith(l:name.name, '.' . a:symbol)
        return imp#NewImport(a:symbol,
              \ printf('from %s import %s', l:p.module, l:name.name))
      endif
    endfor
  endif
  return {}
endfunction

function! imp#lang#python#Suggest(context, symbol) abort
  if stridx(a:symbol, '.') == 0
    let l:suggest = printf('from %s import ', a:symbol)
  elseif stridx(a:symbol, '.') > 0
    let l:suggest = printf('import %s', a:symbol)
  else
    let l:suggest = printf("from  import %s\<S-Left>\<S-Left>\<Left>", a:symbol)
  endif
  let l:statement = input(a:symbol . ': ', l:suggest)
  return empty(l:statement) ? [] : [imp#NewImport(a:symbol, l:statement)]
endfunction

function! imp#lang#python#Insert(context, imports) abort
  let l:result = 1
  for l:import in a:imports
    let l:handled = s:handle(l:import)
    if l:handled.action ==# 'abort'
      " TODO add an 'invalid' list to context
      let l:result = 0
    elseif l:handled.action ==# 'skip'
      call add(a:context.already_imported, l:import)
    elseif l:handled.action ==# 'append'
      " at least part of the statement is not imported yet, append here
      if l:handled.statement !=# l:import.statement
        let l:import = imp#NewImport(l:import.symbol, l:handled.statement)
      endif
      call append(l:handled.position, l:import.statement)
      call add(a:context.imported, l:import)
    elseif l:handled.action ==# 'modified'
      " complicated case, modified in place so just report it
      let l:import = imp#NewImport(l:import.symbol, l:handled.statement)
      call add(a:context.imported, l:import)
    endif
  endfor
  return l:result
endfunction

" Returns a dict with an action determining what to do and supporting fields
" based on the action.
function! s:handle(import) abort
  let l:parsed = s:parseStatement(a:import.statement)
  if empty(l:parsed) || index(['import', 'from'], l:parsed.type) < 0
    return {'action': 'abort'}
  endif
  let l:firstline = s:firstNonCommentLine()
  " Only compare with import statements without indent, not local imports
  " Also skip any import-looking statements in the module docstring
  " TODO Use imp#util#IsSyntaxLine(['comment', 'Constant']) to skip docstrings.
  let l:existingImport = maktaba#function#Filter(
        \ imp#util#FindLines('\v\C^import\s+[[:keyword:].]+'),
        \ {x -> x[0] >= l:firstline})
  let l:existingFrom = maktaba#function#Filter(
        \ imp#util#FindLines('\v\C^from\s+[[:keyword:].]+\s+import>'),
        \ {x -> x[0] >= l:firstline})
  let l:existing = l:parsed.type ==# 'from' ? l:existingFrom : l:existingImport
  let l:linebefore = 0
  let l:lineafter = 0
  let l:modified = 0
  for [l:line, l:statement] in l:existing
    let l:i = l:line
    while (l:statement =~# '\v\\$' || l:statement =~# '\v.*\(\_[^)]*$')
          \ && l:i <= line('$')
      " parse statement including continuation lines
      let l:i += 1
      let l:statement .= "\n" . getline(l:i)
    endwhile
    if l:i > l:line
    endif
    if a:import.statement <# l:statement && l:lineafter == 0
      let l:lineafter = l:line
    elseif a:import.statement >=# l:statement && l:statement !~# '__future__'
      let l:linebefore = l:line
    endif
    let l:lineparsed = s:parseStatement(l:statement)
    if empty(l:lineparsed)
      continue
    endif
    if l:parsed.type ==# 'import'
      for l:mod in l:lineparsed.modules
        let l:index = index(l:parsed.modules, l:mod)
        if l:index >= 0
          let l:modified = 1
          call remove(l:parsed.modules, l:index)
          if empty(l:parsed.modules)
            " all modules already imported
            return {'action': 'skip'}
          endif
        endif
      endfor
    elseif l:parsed.module ==# l:lineparsed.module
      for l:name in l:lineparsed.names
        let l:index = index(l:parsed.names, l:name)
        if l:index >= 0
          let l:modified = 1
          call remove(l:parsed.names, l:index)
          if empty(l:parsed.names)
            " all names already imported
            return {'action': 'skip'}
          endif
        endif
      endfor
      if len(l:lineparsed.names) > 1 || l:lineparsed.parenthesized
            \ || l:parsed.module ==# '__future__'
        call extend(l:lineparsed.names, l:parsed.names)
        let l:modified = s:parsedToString(l:lineparsed)
        call setline(l:line, l:modified)
        if l:i > l:line
          " TODO respect multiline import preferences
          execute printf('%d,%ddelete _', l:line + 1, l:i)
        endif
        return {'action': 'modified', 'statement': l:modified}
      endif
    endif
  endfor
  " Import not already imported and not merged with an existing statement, so
  " figure out where to put it based on previous findings if possible
  if l:lineafter
    let l:position = l:lineafter - 1
  elseif l:linebefore
    let l:position = l:linebefore
  else
    let l:position = max([0, l:firstline - 1])
  endif
  if l:position < l:firstline
    " If no imports of the same style are found, put 'import' before 'from' but
    " keep __future__ as the first import statement (language rule)
    if l:parsed.type ==# 'from' && !empty(l:existingImport)
      if l:parsed.module !=# '__future__'
        let l:position = l:existingImport[-1][0]
      endif
    elseif !empty(l:existingFrom)
      if l:existingFrom[0][1] =~# '__future__'
        let l:position = l:existingFrom[0][0]
      else
        let l:position = l:existingFrom[0][0] - 1
      endif
    elseif l:firstline == line('$')
      " If the file is just comments, append after last line, otherwise insert
      " before the first non-comment line
      let l:position = l:firstline
    endif
  endif
  let l:stmt = l:modified ? s:parsedToString(l:parsed) : a:import.statement
  return {'action': 'append', 'position': l:position, 'statement': l:stmt}
endfunction

" Returns the first line number that doesn't start with a comment and isn't part
" of a docstring, as a place to put imports when none have been added yet.
function! s:firstNonCommentLine() abort
    let l:docstring = ''
    for l:i in range(1, line('$'))
      let l:line = getline(l:i)
      if !empty(l:docstring)
        let l:end = stridx(l:line, l:docstring)
        if l:end >= 0
          let l:docstring = ''
          " TODO handle closing + opening docstring in same line
        endif
      elseif match(l:line, '\v^\s*\w*"""') == 0
        let l:docstring = '"""'
      elseif match(l:line, "\v^\s*\w*'''") == 0
        let l:docstring = "'''"
      elseif match(l:line, '\v^\s*\#') < 0
        return l:i
      endif
    endfor
    " whole file is comments or docstrings, append at bottom
    return line('$')
endfunction

" Parses a string into an import statement dict, or an empty dict if no parse
" was possible.
function! s:parseStatement(statement) abort
    let l:lexer = imp#lex#NewLexer({
          \ 'ReadWhitespace': function('s:lexerReadWhitespace'),
          \ 'Start': function('s:lexerState')},
          \ a:statement)
    if !l:lexer.Lex()
      call s:logger.Warn('Could not parse "%s"', a:statement)
      call s:logger.Debug('Lexing "%s" got tokens %s',
            \ a:statement, l:lexer.tokens)
      return {}
    endif
    return s:parseTokens(l:lexer.tokens, a:statement)
endfunction

" Lexer state which reads python identifiers, comments, whitespace, newlines,
" and a limited set of punctuation which can appear in an import statement.
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
  elseif index(['.', ',', '*', ';', '(', ')'], l:first) >= 0
    call self.EmitToken(self.ReadCharAs('punctuation'))
  else
    call s:logger.Debug('Got unexpected char "%s" in "%s"', l:first, self.text)
    return 'error'
  endif
  return 'Start'
endfunction

" Parses a list of tokens into an import statement dict, or an empty dict if no
" parse was possible.
function! s:parseTokens(tokens, text) abort
  if empty(a:tokens)
    return {}
  elseif a:tokens[0].text ==# 'import'
    return s:parseImportTokens(a:tokens, a:text)
  elseif a:tokens[0].text ==# 'from'
    return s:parseFromTokens(a:tokens, a:text)
  else
    return {}
  endif
endfunction

" Parses a token list like 'import a.b.c, foo as bar # comment' into a dict with
" fields {type='import', modules=['a.b.c', 'foo as bar'], rest=' # comment'}
" where the module entries are {name, alias} dicts.
function! s:parseImportTokens(tokens, text) abort
  if empty(a:tokens) || a:tokens[0].text !=# 'import'
    return {}
  endif
  let l:result = {'type': 'import', 'modules': [], 'rest': ''}
  let l:structure = {'name': '', 'alias': ''}
  let l:i = 1
  let l:cur = copy(l:structure)
  while l:i < len(a:tokens)
    let l:tok = a:tokens[l:i]
    if l:tok.text ==# ','
      if empty(l:cur.name)
        return {}
      endif
      call add(l:result.modules, l:cur)
      let l:cur = copy(l:structure)
    elseif l:tok.type ==# 'identifier' || index(['.', '*'], l:tok.text) == 0
      let l:cur.name .= l:tok.text
      if l:i + 2 < len(a:tokens) && a:tokens[l:i + 1].text ==# 'as'
            \ && a:tokens[l:i + 2].type ==# 'identifier'
        let l:i += 2
        let l:cur.alias = a:tokens[l:i].text
        call add(l:result.modules, l:cur)
        let l:cur = copy(l:structure)
      endif
    else
      let l:result.rest = strcharpart(
            \ a:text, a:tokens[l:i - 1].end, strchars(a:text, 1), 1)
      break
    endif
    let l:i += 1
  endwhile
  if !empty(l:cur.name)
    call add(l:result.modules, l:cur)
  endif
  return l:result
endfunction

" Parses a token list like 'from foo.bar import (baz, qux as x) # comment' into
" a dict with fields {type='from', module='foo.bar', names=['baz', 'qux as x'],
" rest=' # comment', parenthesized=1} where the names entries are {name, alias}
" dicts.
function! s:parseFromTokens(tokens, text) abort
    let l:result = {'type': 'from', 'module': '', 'names': [],
          \ 'parenthesized': 0, 'rest': ''}
    let l:structure = {'name': '', 'alias': ''}
    let l:cur = copy(l:structure)
    let l:i = 1
    let l:inmodule = 1
    while l:i < len(a:tokens)
      let l:tok = a:tokens[l:i]
      if l:inmodule
        if l:tok.text ==# 'import'
          let l:inmodule = 0
        elseif l:tok.type ==# 'identifier' || l:tok.text ==# '.'
          let l:result.module .= l:tok.text
        else
          return {}
        endif
      else
        if l:tok.text ==# '('
          if l:result.parenthesized
            return {}
          endif
          let l:result.parenthesized = 1
        elseif l:tok.text ==# ')'
          if !l:result.parenthesized
            return {}
          endif
          let l:result.rest .=
                \ strcharpart(a:text, l:tok.end, strchars(a:text, 1), 1)
          break
        elseif l:tok.type == 'newline'
          if !l:result.parenthesized
            break
          endif
        elseif l:tok.text ==# ','
          call add(l:result.names, l:cur)
          let l:cur = copy(l:structure)
        elseif l:tok.type ==# 'identifier'
          if l:tok.text ==# 'as'
            if l:i + 1 < len(a:tokens) && a:tokens[l:i + 1].type == 'identifier'
              let l:i += 1
              let l:cur.alias = a:tokens[l:i].text
            endif
          else
            if !empty(l:cur.name)
              return {}
            endif
            let l:cur.name = l:tok.text
          endif
        elseif l:tok.type ==# 'comment' && l:result.parenthesized
          let l:result.rest .= '  ' . l:tok.text
        else
          let l:result.rest .= strcharpart(
                \ a:text, a:tokens[l:i - 1].end, strchars(a:text, 1), 1)
          break
        endif
      endif
      let l:i += 1
    endwhile
    if !empty(l:cur.name)
      call add(l:result.names, l:cur)
    endif
    return l:result
endfunction

" Converts a parsed import dict to a string statement.
function! s:parsedToString(parsed) abort
  if a:parsed.type ==# 'import'
    return printf('import %s%s',
          \ join(maktaba#function#Map(
          \ a:parsed.modules, function('s:aliasedToString')),
          \ ', '),
          \ a:parsed.rest)
  else
    let l:names = join(sort(maktaba#function#Map(
          \ a:parsed.names, function('s:aliasedToString'))), ', ')
    if a:parsed.parenthesized
      " TODO handle newlines in original
      return printf('from %s import (%s)%s',
            \ a:parsed.module, l:names, a:parsed.rest)
    else
      return printf('from %s import %s%s',
            \ a:parsed.module, l:names, a:parsed.rest)
    endif
  endif
endfunction

" Converts a {name, alias} dict to 'name as alias' or just 'name'.
function! s:aliasedToString(namealias) abort
  return empty(a:namealias.alias) ? a:namealias.name
        \ : a:namealias.name . ' as ' .  a:namealias.alias
endfunction

" Replacement for imp#lex#ReadWhitespace which handles line continuation
" (backslash newline) as part of a whitespace token.
function! s:lexerReadWhitespace() abort dict
  return self.ReadPatternAs('\v^((\s*\\(\r\n|\r|\n)\s*)|\s+)+', 'whitespace')
endfunction
