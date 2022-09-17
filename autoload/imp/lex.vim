""
" @dict Token
" A token produced by a lexer with `type` and `token` properties, both string,
" and `start` and `end` properties, both numbers representing character indices
" (not bytes, see |strchars()|).  The token begins at input position `start` and
" ends just before position `end`, so the length should be generally `end` -
" `start`.  A token may have `start` = `end` if it represents a token which
" doesn't have a text component, e.g. EOF.

""
" @public
" Creates a @dict(Token) object of {type} with value {text} and indices {start}
" to {end}.
function! imp#lex#NewToken(type, text, start, end) abort
  return {'type': a:type, 'text': a:text, 'start': a:start, 'end': a:end}
endfunction

""
" @dict Lexer
" A basic lexer which can scan text to produce a series of tokens.  The default
" implementation's Read* methods use pattern atoms like \k and \s to detect
" keywords, whitespace, etc.  Vim's 'filetype' setting affects the behavior of
" these atoms, but language implementations might want to customize the token
" readers for language-specific needs.  Lexers are initialized with a set of
" named state functions which control the lexer's state machine and advancement
" through the text.  A Lexer is stateful and only valid for one string.  It has
" the following keys:
"   * `text` - The string to be lexed
"   * `position` - The current 0-based index in the string, measured in
"     characters with composing chars ignored, see |strchars()|.
"     If `position >=0` then lexing is done (see @function(Lexer.AtEnd)).
"   * `tokens` - List of @dict(Token) produced by @function(Lexer.EmitToken)
"   * `state` - Name of current lexer state (next method to call)
" In addition to calling @function(Lexer.EmitToken), state methods may store
" data as properties in the Lexer as long as they don't conflict with an
" existing name.

""
" @public
" Creates a @dict(Lexer) with state machine methods and other properties copied
" from {states} and it will lex the string {text} when @function(Lexer.Lex) is
" called.  {states} must have at least a `'Start'` state method, which is the
" first state called by the lexer.  Each state method returns the name of the
" next state, `'error'` if it encountered a portion of input that could not be
" handled, or `'done'` if lexing of the text is complete.
function! imp#lex#NewLexer(states, text) abort
  if !has_key(a:states, 'Start')
    throw maktaba#error#BadValue('No Start method in %s', a:states)
  endif
  let l:lexer = extend({
        \ 'position': 0,
        \ 'text': a:text,
        \ 'tokens': [],
        \ 'state': 'Start',
        \ 'Lex': function('imp#lex#Lex'),
        \ 'AtEnd': function('imp#lex#AtEnd'),
        \ 'AdvanceBy': function('imp#lex#AdvanceBy'),
        \ 'AdvanceTo': function('imp#lex#AdvanceTo'),
        \ 'EmitToken': function('imp#lex#EmitToken'),
        \ 'PeekChar': function('imp#lex#PeekChar'),
        \ 'PeekChars': function('imp#lex#PeekChars'),
        \ 'ReadChar': function('imp#lex#ReadChar'),
        \ 'ReadCharAs': function('imp#lex#ReadCharAs'),
        \ 'ReadDelimitedAs': function('imp#lex#ReadDelimitedAs'),
        \ 'ReadPatternAs': function('imp#lex#ReadPatternAs'),
        \ 'ReadIdentifier': function('imp#lex#ReadIdentifier'),
        \ 'ReadWhitespace': function('imp#lex#ReadWhitespace'),
        \ 'ReadNewline': function('imp#lex#ReadNewline'),
        \ 'ReadWhitespaceOrNewline': function('imp#lex#ReadWhitespaceOrNewline')
        \ }, a:states)
  return l:lexer
endfunction

""
" @public
" @dict Lexer
" Repeatedly calls the state machine method associated with `state` (initially
" `'Start'`), setting the new `state` to the return value of that method.  State
" methods are responsible for emitting tokens and advancing `position`.  Returns
" 1 if the lexing process completed successfully (state `'done'`) or 0 if a
" state returned `'error'`.
function! imp#lex#Lex() abort dict
  while self.state !=# 'done' && self.state !=# 'error'
    let self.state = maktaba#function#Method(self, self.state).Apply()
  endwhile
  return self.state ==# 'done'
endfunction

""
" @public
" @dict Lexer
" Returns 1 if the lexer has reached the end of the input text, 0 otherwise.
function! imp#lex#AtEnd() abort dict
  return self.position >= len(self.text)
endfunction

""
" @public
" @dict Lexer
" Moves the lexer position ahead by {length} characters.
function! imp#lex#AdvanceBy(length) abort dict
  call maktaba#ensure#IsNumber(a:length)
  let self.position += a:length
endfunction

""
" @public
" @dict Lexer
" Sets the current lexer position to {position}.  The lexer position is 0-based
" and expressed in characters.
function! imp#lex#AdvanceTo(position) abort dict
  call maktaba#ensure#IsNumber(a:position)
  let self.position = a:position
endfunction

""
" @public
" @dict Lexer
" Appends {token} (a @dict(Token)) to the `tokens` list of this lexer.
function! imp#lex#EmitToken(token) abort dict
  call maktaba#ensure#IsDict(a:token)
  if empty(a:token.type)
    throw maktaba#error#BadValue('Empty type in token %s', a:token)
  endif
  call add(self.tokens, a:token)
endfunction

""
" @public
" @dict Lexer
" Returns the next character in the input, without advancing position.  Returns
" empty string at the end of input.
function! imp#lex#PeekChar() abort dict
  if self.AtEnd()
    return ''
  endif
  return matchstr(self.text, '\v^\_.', self.position)
endfunction


""
" @public
" @dict Lexer
" Returns the next {length} characters in the input, without advancing position.
" Returns empty string at the end of input, or if position plus length is longer
" than input.
function! imp#lex#PeekChars(length) abort dict
  call maktaba#ensure#IsTrue(
        \ a:length > 0, 'length must be positive, not %s', a:length)
  if self.AtEnd()
    return ''
  endif
  return matchstr(self.text, printf('\v^\_.{%d}', a:length), self.position)
endfunction

""
" @public
" @dict Lexer
" Returns the next character in the input, advancing position to the following
" character.  Returns empty string at the end of input.
function! imp#lex#ReadChar() abort dict
  if self.AtEnd()
    return ''
  endif
  let l:match = matchstrpos(self.text, '\v^\_.', self.position)
  if l:match[1] != self.position
    return ''
  endif
  call self.AdvanceTo(l:match[2])
  return l:match[0]
endfunction

""
" @public
" @dict Lexer
" Returns a token with type={type} and the next character in the input as text,
" advancing position to the following character.  Returns empty dict at the end
" of input.
function! imp#lex#ReadCharAs(type) abort dict
  if self.AtEnd()
    return ''
  endif
  let l:match = matchstrpos(self.text, '\v^\_.', self.position)
  if l:match[1] != self.position
    return ''
  endif
  call self.AdvanceTo(l:match[2])
  return imp#lex#NewToken(a:type, l:match[0], l:match[1], l:match[2])
endfunction

""
" @public
" @dict Lexer
" Attempts to read a series of characters delimited by matching {delim} strings,
" such as a single- or double-quoted string.  Any character in {escape} (e.g.
" `'\'`) will be treated as an escape character; if it's before a delimiter then
" the latter will not end the string.  If escape is empty, the closing delimiter
" cannot be escaped, e.g. single-quoted shell strings.  Returns a @dict(Token)
" with the matched content, delimiters included, and type {type}, or an empty
" dict if the input does not start with delim.
function! imp#lex#ReadDelimitedAs(delim, escape, type) abort dict
  call maktaba#ensure#IsFalse(
        \ empty(maktaba#ensure#IsString(a:delim)), 'empty delimiter')
  if self.AtEnd()
    return {}
  endif
  let l:delimlen = strchars(a:delim, 1)
  if self.PeekChars(l:delimlen) !=# a:delim
    return {}
  endif
  let l:esc = split(a:escape, '.\zs')
  let l:start = self.position
  call self.AdvanceBy(l:delimlen)
  while !self.AtEnd()
    if self.PeekChars(l:delimlen) ==# a:delim
      call self.AdvanceBy(l:delimlen)
      break
    endif
    let l:char = self.ReadChar()
    if index(l:esc, l:char) >= 0
      call self.ReadChar()
    endif
  endwhile
  return imp#lex#NewToken(a:type,
        \ strcharpart(self.text, l:start, self.position - l:start),
        \ l:start, self.position)
endfunction

""
" @public
" @dict Lexer
" If {pattern} matches at the current text position, returns a new @dict(Token)
" with the matching text, {type}, and the character start and end positions of
" the match, advancing the lexer position to the end of the match.  If {pattern}
" does not match at the current position an empty dict is returned.
function! imp#lex#ReadPatternAs(pattern, type) abort dict
  if self.AtEnd()
    return {}
  endif
  let l:match = matchstrpos(self.text, a:pattern, self.position)
  if l:match[1] != self.position
    return {}
  endif
  call self.AdvanceTo(l:match[2])
  return imp#lex#NewToken(a:type, l:match[0], l:match[1], l:match[2])
endfunction

""
" @public
" @dict Lexer
" Attempts to read an identifier at the current position, returning a
" @dict(Token) with `type = 'identifier'` if successful and an empty dict
" otherwise.  By default, this calls
" `self.ReadPatternAs('\v^\k+', 'identifier')`  Language-specific lexers may
" set a different ReadIdentifier function property.
function imp#lex#ReadIdentifier() abort dict
  return self.ReadPatternAs('\v^\k+', 'identifier')
endfunction

""
" @public
" @dict Lexer
" Attempts to read an one or more newline characters at the
" current position, returning a @dict(Token) with `type = 'newline'` if
" successful and an empty dict otherwise.  By default, this calls
" `self.ReadPatternAs('\v^[\r\n]+', 'newline')`  Language-specific lexers
" may set a different ReadNewline function property.
function imp#lex#ReadNewline() abort dict
  return self.ReadPatternAs('\v^[\r\n]+', 'newline')
endfunction

""
" @public
" @dict Lexer
" Attempts to read an one or more non-newline whitespace characters at the
" current position, returning a @dict(Token) with `type = 'whitespace'` if
" successful and an empty dict otherwise.  By default, this calls
" `self.ReadPatternAs('\v^\s+', 'whitespace')`  Language-specific lexers may
" set a different ReadWhitespace function property.
function imp#lex#ReadWhitespace() abort dict
  return self.ReadPatternAs('\v^\s+', 'whitespace')
endfunction

""
" @public
" @dict Lexer
" Attempts to read an one or more whitespace or newline characters at the
" current position, returning a @dict(Token) with `type = 'whitespace'` if
" successful and an empty dict otherwise.  By default, this calls
" `self.ReadPatternAs('\v^\_s+', 'whitespace')`  (Note that this is the same
" token type as @function(Lexer.ReadWhitespace) but not the same as
" @function(Lexer.ReadNewline).  Language-specific lexers may set a different
" ReadWhitespaceOrNewline function property.
function imp#lex#ReadWhitespaceOrNewline() abort dict
  return self.ReadPatternAs('\v^\_s+', 'whitespace')
endfunction
