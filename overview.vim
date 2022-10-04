" This file just has comments, as a convenient place to put vimdoc contents that
" are not tied to a specific declaration.

""
" @section Introduction, intro
" @order intro commands mappings config handlers dicts functions about
" @stylized Imp
" @plugin(stylized) is an extensible plugin for handling import statements for a
" variety of programming languages.  It operates on a pipeline model where
" generic, custom, or language-specific handers implement individual steps in
" the process of adding an import for a symbol to a program.  The goal is for
" programmers to be able to add import statements as they write code with
" minimal disruption to flow.  For example, a Java programmer might write >
"   public List<Animal> findAnimals(Query q) {
"     checkNotNull(q);
"     ...
"   }
" < and want to add >
"   import static com.google.common.base.Preconditions.checkNotNull;
"   import com.example.Animal;
"   import com.example.Animal.Query;
"   import java.util.List;
" < without having to move to the top of the file, type all those statements,
" and move back to the method.  @command(ImpSuggest) accomplishes this as >
"   :ImpSuggest List Animal Query checkNotNull
" < It will use registered handlers to find possible matches for those symbols
" and let the user pick the ones they mean, e.g. `com.example.Animal.Query` or
" `com.example.Vegetable.Query`?  Alternatively, an insert-mode mapping could
" call @command(:ImpFirst), using a single control key to insert the most likely
" import statement for the symbol next to the cursor (you probably want
" `java.util.List` and not `java.awt.List`).
"
" @plugin(stylized) requires Vim version 8+ and depends on the Maktaba library,
" see https://github.com/google/vim-maktaba for installation instructions.
" If you have Vim 8.0 or higher and see an error about an unknown function,
" file an issue at https://github.com/flwyd/vim-imp/issues

""
" @section About, about
" An imp is a European mythological creature which can perform many useful
" tasks, but sometimes gets into mischief.  Hopefully you find the Imp plugin
" useful, but be warned that it might hand you the wrong tool or rearrange your
" imports in a surprising way.
"
" This plugin was inspired by a shell script and a kludge of key mappings which
" attempted to bring IDE-style Java import management to Vim.  I was working in
" a large codebase stored on a remote filesystem, and recursive grep was slow,
" so I would periodically build a list of the import statements my team used
" most frequently, then search that cached list.  The script would fall back to
" Google Code Search if my list of prepared imports did not have a match for the
" symbol under my cursor.  I created @plugin as a general purpose plugin to
" support more languages and a pluggable set of tools for suggesting, picking,
" inserting, and reporting import statements, with a goal of having as many
" pieces as possible work with code in any language.
"
" The following features would be useful additions to this plugin:
"   * Insert and Pattern support for more languages
"   * "Metalanguage" suport, e.g. combine Java, Kotlin, and Scala suggestions
"   * Flags to help Insert handlers respect coding styles, e.g. placement of
"     Java static and non-static Java imports, blank lines between imports of
"     different top-level package trees
"   * Convert an existing qualfied identifier into an import, for example turn
"     `int x = Math.max(a, b)` into `int x = max(a, b)` with a static import for
"     `java.lang.Math.max` added
"   * Maybe a -bang option on the commands which allows substring matches on
"     import symbols
"   * Function for |command-completion-custom| which proposes symbols in the
"     current buffer like CTRL-N/CTRL-P completion in insert mode
"   * :ImpOrganize command to sort and format existing imports in the buffer
"   * In visual mode, @command(ImpSuggest) and @command(ImpFirst) could identify
"     all unimported symbols in the range and import them
"   * Suggest imports from the language standard library or popular software
"     packages without depending on an existing corpus of user code
"   * Flags to exclude certain directories from searches that would otherwise be
"     covered by Location handler lists.  This is kinda what ripgrep, ag, and
"     ack already do, though, so maybe just use those instead of grep.
"   * Ability to build a cache of the most popular imports from a directory
"     hierarchy and a Suggest handler which consults that cache.  A Report
"     handler could increment counts in the cache.
"   * Mark unimported symbols with |signs| or syntax highlighting (might be best
"     left to a LSP plugin, though)
"   * More filtering options for @command(ImpHandlers)
"   * Tests.  Lots more tests.  Tests were excluded from initial development
"     because Vroom needs client-server support which is unavailable on macOS.
"     I opted to use https://github.com/thinca/vim-themis for xUnit-style
"     testing.  Testing so far is focused on real executables (rather than mock
"     responses) which has been successful at finding regular expression bugs
"     and corner cases, but comes at the cost of slow test times if all the
"     programs are installed and missed coverage if the executables aren't
"     available in the test environment.  Tests for utility functions and
"     hermetic handlers should be fairly straightforward, just needs time.
" >
"    _    ___              ____
"   | |  / (_)___ ___     /  _/___ ___  ____
"   | | / / / __ `__ \    / // __ `__ \/ __ \
"   | |/ / / / / / / /  _/ // / / / / / /_/ /
"   |___/_/_/ /_/ /_/  /___/_/ /_/ /_/ .___/
"                                   /_/
" <

""
" @section Handlers, handlers
" Most features of @plugin are driven by handlers.  A handler is registered as
" an extension and provides one or more interface functions which handle a step
" of the import process.  See @section(handlers-list) for the built-in handlers.
" To see a list of all registered handlers, run @command(:ImpHandlers).  See
" @section(handlers-register) for registering custom handlers.
"
" @plugin(stylized) calls handlers at four stages of the import process: >
"   Suggest -> Pick -> Insert -> Report
" < The first three are called in sequence for a single symbol; Report will be
" called at the end of a command which may add imports for several symbols.
" Normal handler functions take a @dict(Context) dict as the first parameter.
" Asynchronous handler functions take a Done callback as the first parameter and
" context as the second (see @section(handlers-async).  The remaining
" parameter(s) are specific to the handler interface.
"
" @subsection Suggest handler
"                                                       *imp-handlers-suggest*
" The Suggest handler starts the import process.  Its signature is >
"   function Suggest({context}, {symbol})
"       (or for async handlers:)
"   function Suggest({Done}, {context}, {symbol})
" < and it returns a list of @dict(Import) dicts, or empty list if no imports
" could be suggested for the symbol. {symbol} is a string and {context} is a
" @dict(Context).  There may be several registered Suggest handlers, and
" `prompt` is typically the last one, so returning empty from one handler will
" let others try.  Once a Suggest handler has returned a non-empty list, no more
" Suggest handlers will be tried.
"
" If the context has a `max` property and it's greater than zero, Suggest
" handlers should return at most that many options.  `max` is often `1`,
" and if Suggest returns a single import, the Pick step will be skipped.
"
" @subsection Pick handler
"                                                          *imp-handlers-pick*
" The Pick handler takes a list of suggested imports and presents them to the
" user to decide which, if any, should be imported into the current file.  Its
" signature is >
"   function Pick({context}, {suggestions})
"       (or for async handlers:)
"   function Pick({Done}, {context}, {suggestions})
" < and it returns a list of @dict(Import) dicts, or an empty list if the user
" chose not to import any symbols.  {suggestions} is a list of @dict(Import)
" and {context} is a @dict(Context).  The Pick handler will be bypassed if there
" are zero or one suggestions; in the latter case the single suggestion will be
" passed straight to Insert.
"
" Pick handlers are free to restrict the user to making a single choice or
" allowing multiple selections; in most cases the user is likely to pick one or
" zero options.  Pick handlers are also free to present the user with fewer
" choices than there are suggestions, e.g. if the suggestions won't all fit on
" the screen.
"
" @subsection Insert handler
"                                                        *imp-handlers-insert*
" The Insert handler takes the choices from Pick and inserts them into the
" current buffer.  Its signature is >
"   function Insert({context}, {choices})
"       (or for async handlers:)
"   function Insert({Done}, {context}, {choices})
" < and it returns 1 if it was able to handle the choices, 0 if not.  {choices}
" is a list of @dict(Import) and {context} is a @dict(Context).  Insert may
" optionally not insert some choices, typically if that import statement is
" already present.  In such cases, Insert should return 1 so that other
" inserters are not tried; returning 0 is reserved for cases where the handler
" would be unable to do something useful even if it had a valid import.  While
" {choices} is a list (since Pick may return more than one choice), they should
" all represent the same symbol.
"
" Insert handlers should append inserted imports to the `context.imported` list,
" and add append skipped imports to the `context.already_imported` list.
" Handlers should not replace these lists, because the same context may be used
" in several calls to Insert with different symbols, with the combined results
" passed to the Report handler.
"
" @subsection Report handler
"                                                        *imp-handlers-report*
" The Report handler takes lists of inserted and skipped imports and reports
" what was done.  Its signature is >
"   function Report({context}, {imported}, {already_imported})
"       (or for async handlers:)
"   function Report({Done}, {context}, {imported}, {already_imported})
" < and it returns 1 if any action was taken, 0 if not.  {imported} and
" {already_imported} are lists of @dict(Import) and {context} is a
" @dict(Context).  Unlike other handler types, all preferred reporters for the
" current filetype are called.  For example, one might show a message to the
" user while another writes information to a log file.
"
" @subsection Pattern handler
"                                                       *imp-handlers-pattern*
" The Pattern handler is not part of the standard @section(handlers) chain.
" Instead, language-agnostic handlers which need a pattern to match import
" statements may call a language-specific Pattern handler. The signature is >
"   function Pattern({context}, {style}, {symbol})
" < and it returns a @dict(Pattern), or an empty dict if the handler cannot
" produce a regex for {symbol}.  There is no async version of the Pattern
" handler.  {style} is a string indicating the regular expression syntax, as
" described in @dict(Pattern).  {symbol} is a string symbol which will be
" searched for and {context} is a @dict(Context).
"
" @subsection Location handler
"                                                      *imp-handlers-location*
" The Location handler is a helper for some Suggest handlers, such as `grep`,
" `ripgrep`, `ag`, `ack, `gitgrep`, and `hggrep` which search files in a
" directory hierarchy for import statements.  The signature is >
"   function Location({context}))
" < and it returns a list of paths (strings) to search.  There is no async
" version of the Location handler.  If a Location handler returns an empty list,
" the Suggest handler should check the next preferred Location handler, falling
" back to a default location like the current directory.  A Location handler may
" return multiple locations, e.g. the paths to both `src` and `tests`
" directories, and the Suggest handler should search in all of them.

""
" @section Asynchronous handlers, handlers-async
" @parentsection handlers
" While it is usually simplest to implement a handler as a simple function which
" returns a value, handlers may also produce results asynchronously.  For
" example, a Suggest handler which launches a slow command to search for options
" or a Pick handler which allows the user to interact with a popup window.
"
" Rather than returning a value, asynchronous handlers accept a callback
" function as the first argument.  This callback takes the context as the first
" parameter and the handler result as the second parameter.  For example, an
" asynchronous Pick handler might be >
"   function! myasync#Pick(Done, context, suggestions) abort
"     let l:closure = {'Done': a:Done, 'context': a:context}
"     function l:closure.Callback(choices)
"       call self.Done(self.context, a:choices)
"     endfunction
"     call s:doSomethingAsync(a:suggestions
"       \ maktaba#function#Create(l:closure.Callback, [], l:closure))
"   endfunction
" < and registered as >
"   {'name': 'myasync', 'description': '..', 'async': 1, 'Pick': 'myasync#Pick'}
" <
" It is vital that async handlers call the Done callback even if they produce no
" results, otherwise subsequent handlers won't get a chance to run and
" multi-symbol commands won't process further imports.

""
" @section Registering handlers, handlers-register
" @parentsection handlers
" Handlers are registered in a |maktaba.ExtensionRegistry| as a dict with keys
"   * `name` (name of the handler, referenced in @section(config) flags)
"   * `description` (short explanation, shown with @command(ImpHandlers))
"   * `filetypes` (optional string or list of |filetype|s it can handle)
"   * `async` (optional, 1 for asynchronous, 0 if it returns a value)
" and one or more interface implementations:
"   * `IsAvailable`
"   * `Suggest`
"   * `Pick`
"   * `Insert`
"   * `Report`
"   * `Pattern`
" Interface values can be any |maktaba| Callable; it's usually most convenient
" to specify a function name as a string.  The `IsAvailable` property may either
" be a Callable or a simple 0/1 boolean value.  If `IsAvailable` is a string or
" function, @plugin will call it as `IsAvailable(context)`.
"
" Handlers may be registered with the same name as an existing handler.  This is
" commonly done to provide a filetype-specific version of a handler.  Language
" integrations are encouraged to provide a Suggest handler named `prompt` which
" uses |input()| to present a partially complete import statement with
" appopriate cursor positioning.  Language integrations should also provide an
" Insert handler named `lang` to pick the appropriate place in the buffer to
" insert the import statement.  For example, the `lang` handler for Java
" places imports after the package declaration and alphabetizes them, with
" static imports first.  Finally, language integrations should implement a
" Pattern handler to help grep-style Suggest handlers find and parse imports.
"
" An example handler which suggests imports using an external command named
" `mysearch` might be implemented as >
"   " myplugin/autoload/myhandler.vim
"   function! myhandler#IsAvailable(context) abort
"     return executable('mysearch')
"   endfunction
"   function! myhandler#Suggest(context, symbol) abort
"     let l:lines = s:runMysearch(a:context.filetype)
"     return map(l:lines, {_, line -> imp#NewImport(a:symbol, line)})
"   endfunction
"
"   " myplugin/plugin/register.vim
"   let l:registry = maktaba#extension#GetRegistry('imp')
"   call l:registry.AddExtension({
"     \ 'name': mysearch',
"     \ 'description': 'Suggest imports with mysearch',
"     \ 'async': 0,
"     \ 'filetypes': ['foo', 'bar'],
"     \ 'IsAvailable': 'myhandler#IsAvailable',
"     \ 'Suggest': 'myhandler#Suggest'})
" <
" If the `filetypes` property is empty or absent, the handler will be available
" for any 'filetype'.  If it is a string or list, the handler will only be tried
" for matchig languages (skipping even `IsAvailable` checks).
