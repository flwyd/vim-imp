""
" @dict Pattern
" A Pattern is a dict containing several fields to support use cases like
" searching for imports in a directory using `grep`.  A Pattern must have the
" following fields:
"   * `patterns` - list of 0 or more regular expressions which can match import
"     statements for the current filetype; false positives and negatives are
"     allowed; false positives can be filtered out with the help of `Parse`
"   * `fileglobs` - list of 0 or more glob patterns which match files to search
"     for import statements; if empty the search handler may infer files from
"     the current 'filetype' or search all files
" and may optionally have the following fields
"   * `style` - string name of regex syntax
"   * `Parse` - `function(context, symbol, line)` to parse a line of text
"     matching an import of `symbol`, returning a normalized @dict(Import) or
"     an empty dict if line is not a valid import for that symbol
"   * `multiline` - 1 if handlers using `patterns` should treat them as regular
"     expressions that can cross newline boundaries, if supported
"   * `ignorecase` - 1 if handlers using `patterns` should ignore case
" The `multiline` and `ignorecase` properties are assumed false if not present,
" `style` is assumed to be `posix` by default.  In the absence of `Parse`,
" @function(imp#NewImport) can be used with the line as matched.
"
" Pattern-related functions take a `style` string parameter indicating which
" regex library or syntax will be used by the tool in question.  The following
" styles are recognized by @plugin(name) functions, but handlers might
" understand more.
"   * `posix` - Extended Regular Expressions from POSIX.2, see `man re_format`
"   * `posix_basic` - Basic Regular Expressions from POSIX.2 for backward
"     compatibility, not recommended (use `grep -E` instead)
"   * `perl` - Regular expressions as implemented in Perl
"   * `pcre` - Perl Compatible Regular Expressions library in C,
"     mostly but not 100% compatible with Perl
"   * `java` - Perl-style as implemented in `java.util.regex.Pattern`
"   * `js` - Perl-style ECMAScript RegExp syntax
"   * `dotnet` - Perl-style as implemented in .Net
"   * `ruby` - Mostly Perl-style as implemented in Ruby
"   * `python` - Regular expressions as implemented in Python's `re` package
"   * `rust` - Regular expressions in Rust, no lookaround or backrefs
"   * `re2` - Library with linear performance and no lookaround or backrefs;
"     default syntax for Go, available in C, Java, D, and WebAssembly
"
" If an unknown `style` is passed to a handler or function, extended POSIX
" syntax should be assumed as a baseline.  When building regex patterns, fancy
" features should be kept to a minimum since this scheme doesn't allow
" specifying library versions, and some programs which nominally use the same
" regex engine might have slightly different features.  Use
" @function(imp#pattern#Escape) and
" @function(imp#pattern#SupportsPerlLookaround) functions to build style-aware
" pattern strings.

""
" @public
" Requests a pattern for {symbol} using regular expression syntax {style} from
" Pattern handlers in preferred order.  Returns the first @dict(Pattern)
" produced, or an empty dict if no preferred Pattern handler returned one.
function! imp#pattern#FromPreferred(context, style, symbol) abort
  for l:handler in imp#handler#Preferred(a:context, 'Pattern')
    let l:pat= maktaba#function#Apply(
          \ l:handler.Pattern, a:context, a:style, a:symbol)
    if !empty(l:pat) && has_key(l:pat, 'patterns')
      return l:pat
    endif
  endfor
  return {}
endfunction

""
" @public
" Returns a list of @dict(Import) structures based on {lines} (a list of
" strings) matched by {pattern} (a @dict(Pattern)) searching for {symbol}.
" Matching imports are grouped and the results sorted by count.  If pattern has
" a `Parse` method, this function will delegate to Parse to create the Import,
" otherwise the Import will use the full matched line.  Parse methods will be
" called with arguments `(context, symbol, line)` and can return an empty dict
" if the line cannot be parsed.  Pattern handlers are encouraged to implement
" Parse to normalize lines found by grep and similar programs, particularly if a
" single import statement can include multiple symbols.
function! imp#pattern#ParseMatches(context, pattern, symbol, lines) abort
  let l:result = {}
  for l:line in a:lines
    if has_key(a:pattern, 'Parse')
      let l:import = a:pattern.Parse(a:context, a:symbol, l:line)
    else
      let l:import = imp#NewImport(a:symbol, l:line)
    endif
    if !empty(l:import)
      if has_key(l:result, l:import.statement)
        let l:result[l:import.statement].count += 1
      else
        let l:result[l:import.statement] = l:import
      endif
    endif
  endfor
  let l:sorted = sort(values(l:result), {x, y -> y.count - x.count})
  let l:max = get(a:context, 'max', 0)
  if l:max > 0 && l:max < len(l:sorted)
    return l:sorted[0:l:max-1]
  endif
  return l:sorted
endfunction

""
" @public
" Escapes {text} according to regular expression syntax {style}.  Uses literal
" quoting features if available, such as Vim's very |nomagic| mode and `\Q \E`
" pairs in some syntax styles derived from Perl.  If a style is unknown or does
" not support literal quoting, this function backslash-escapes all
" non-alphanumeric characters (i.e. anything other than 0-9, A-Z, a-z, and _).
" If a regex engine treats `\x` as a metacharacter where `x` is not an ASCII
" letter, number, or underscore, add support for that style to this function.
"
" Care should be taken with the result of this function, even though it has
" been escaped.  For example, the `vim` style prepends `\V` but does not append
" `\v` or `\m` at the end, since it doesn't know what the previous magic value
" was.  Similarly, the `vim` style doesn't set `\C,` so a previous `\c` in the
" pattern will cause the escaped text to match without case sensitivity.
"
" Values for style:
"   * `vim` - enables "very nomagic" mode, see |/\V|
"   * `pcre`, `java`, `re2` - wraps text in \Q...\E quote metacharacters
"   * `posix_basic` - backslash-escapes only the metacharacters in POSIX basic
"     regular expressions; does not escape characters like ?, (, and )
"   * any other value - inserts a backslash before all non-alphanumerics
function! imp#pattern#Escape(style, text) abort
  if a:style ==# 'vim'
    " use 'very nomagic' for Vim
    return '\V' . escape(a:text, '\')
  elseif maktaba#value#IsIn(a:style, ['pcre', 'java', 're2'])
    " use \Q and \E to delimit quoted literal segment for Perl-inspired engines,
    " though ironically Perl rejects \Q\E pairs in patterns built at runtime,
    " see https://github.com/beyondgrep/ack3/issues/323#issuecomment-714694736
    " https://perldoc.perl.org/functions/quotemeta and
    " https://perldoc.perl.org/perlop#Gory-details-of-parsing-quoted-constructs
    " so 'perl' style is handled by the default case
    return '\Q' . substitute(a:text, '\\[QE]', '\\&', 'g') . '\E'
  elseif a:style ==# 'posix_basic'
    " POSIX basic mode (e.g. grep default) treats ?+|(){} as literals, and
    " treats \? \| \(\) etc. as metacharacters, so just escape specific chars.
    return escape(a:text, '^$.*[]\')
  else
    " no escape syntax, just put backslash before all non-alphanumerics
    " NOTE: Vim's definition of \w is ASCII alphanumerics plus underscore, so if
    " a regex engine adds Unicode metacharacters, additional handling might be
    " needed.  Maybe Vim will support a \p{Pattern_Syntax} character property
    " metacharacter by then.
    return substitute(a:text, '\W', '\\&', 'g')
  endif
endfunction

""
" @public
" Returns true if regex syntax {style} supports Perl-style lookaround assertions
" like `(?!foo)` for "not followed by foo" or `(?<=bar)` for "preceded by bar".
" Lookaround is supported in most Perl-influenced syntax styles, but it can lead
" to pathological performance cases, so some engines don't support it, including
" `posix`, `re2`, and `rust`.
function! imp#pattern#SupportsPerlLookaround(style) abort
  return maktaba#value#IsIn(a:style,
        \ ['perl', 'pcre', 'java', 'python', 'ruby', 'js', 'dotnet'])
endfunction

""
" @public
" Converts a POSIX file {glob} to a POSIX regular expression.  NOTE: It is
" possible that this function mishandles some unusual glob cases. It does not
" handle some shell patterns like `{foo,bar}` disjunction.
function! imp#pattern#GlobToRegex(glob) abort
  let l:regex = ''
  let l:brackets = 0
  let l:bracketfirst = 0
  for l:c in split(a:glob, '.\zs')
    if l:brackets
      if l:bracketfirst
        let l:bracketfirst = 0
        if l:c ==# '!'
          let l:regex .= '^'
        elseif l:c ==# ']'
          let l:regex .= '\]'
        elseif l:c ==# '\'
          let l:regex .= '\\'
        else
          let l:regex .= l:c
        endif
      else
        if l:c ==# ']'
          let l:brackets = 0
          let l:regex .= ']'
        elseif l:c ==# '\'
          let l:regex .= '\\'
        else
          let l:regex .= l:c
        endif
      endif
    else
      if l:c =~? '\w'
        let l:regex .= l:c
      elseif l:c ==# '?'
        let l:regex .= '.'
      elseif l:c ==# '*'
        let l:regex .= '.*'
      elseif l:c ==# '['
        let l:brackets = 1
        let l:bracketfirst = 1
        let l:regex .= '['
      else
        let l:regex .= '\' . l:c
      endif
    endif
  endfor
  return l:regex
endfunction
