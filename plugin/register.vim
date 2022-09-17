let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

function! s:ValidateExtension(ext) abort
  for l:key in ['name', 'description']
    if !has_key(a:ext, l:key)
      throw maktaba#error#BadValue("Missing '%s' field in %s", l:key, a:ext)
    endif
  endfor
  if has_key(a:ext, 'filetypes')
        \ && !maktaba#value#TypeMatchesOneOf(a:ext.filetypes, ['', []])
    throw maktaba#error#BadValue(
          \ 'filetypes field of %s must be string or list, not %s',
          \ a:ext.name, maktaba#value#TypeName(a:ext.filetypes))
  endif
  if has_key(a:ext, 'IsAvailable')
        \ && !maktaba#value#IsCallable(a:ext.IsAvailable)
        \ && !maktaba#value#IsNumber(a:ext.IsAvailable)
    throw maktaba#error#BadValue(
          \ 'IsAvailable field of %s must be callable or bool, not %s',
          \ a:ext.name, maktaba#value#TypeName(a:ext.IsAvailable))
  endif
  let l:handlers = 0
  let l:handlernames = ['Suggest', 'Pick', 'Insert', 'Record']
  for l:key in l:handlernames
    if has_key(a:ext, l:key)
          \ && !maktaba#value#IsCallable(a:ext[l:key])
        throw maktaba#error#BadValue(
              \ '%s field of %s must be callable, not %s',
              \ l:key, a:ext.name, maktaba#value#TypeName(a:ext[l:key]))
      else
        let l:handlers += 1
    endif
  endfor
  if l:handlers == 0
    throw maktaba#error#BadValue('No handlers among %s are fields in %s',
          \ l:handlernames, a:ext)
  endif
endfunction

let s:registry = s:plugin.GetExtensionRegistry()
call s:registry.SetValidator(function('s:ValidateExtension'))

""
" @section Available handlers, handlers-list
" @parentsection handlers
" The following handlers are distributed with @plugin and can be set as
" preferred handlers.  The current preference lists can be shown with the
" |:Glaive| command: `:Glaive @plugin(name)`
"
" @subsection Suggest handlers
"   * `prompt` - Prompt for import statement with symbol prefilled
"     (language extensions typically override the prefilled statement)
"   * `buffer` - Search buffers of matching file type, multiline support TODO
"   * `grep` - Search directory hierarchy with `grep` command, may be slow, no
"     multiline support
"   * `ripgrep` - Search directory hierarchy with `rg` command
"     (https://github.com/BurntSushi/ripgrep)
"   * `ag` - Search directory hierarchy with `ag` command, AKA The Silver
"     Searcher (https://github.com/ggreer/the_silver_searcher)
"   * `ack` - Search directory hierarchy with `ack` command
"     (https://github.com/beyondgrep/ack3), no multiline support
"   * `gitgrep` - Search git repository or tree with `git grep` command, no
"     multiline support
"   * `hggrep` - Search Mercurial repository or tree with `hg grep` command
"   * `known` - Suggest imports from a pre-declared set, call
"     @function(imp#handler#known#Add) to declare statements for a language
"
" @subsection Pick handlers
"   * `inputlist` - Pick import by number with |inputlist()|
"   * `lucky` - Always pick the first suggested import
"   * `window` - Pick import with a split selector window
"   * `fzf` - Pick imports with |FZF| fuzzy finder
"     (https://github.com/junegunn/fzf)
"
" @subsection Insert handlers
"   * `lang` - Default implementation does nothing, overridden by
"     filetype-specific handlers to find an appropriate position
"   * `top` - Insert import statement at top of the buffer (after any shebang
"     line)
"   * `above` - Insert import statement above the cursor line
"
" @subsection Report handlers
"   * `echo` - Report imports with |:echo|
"   * `echomsg` - Report imports with |:echomsg|
"   * `popupnotify` - Report with a short-lived |popup_notification()| at
"     the top of the window
"
" @subsection Location handlers
"   * `pwd` - Search under the current working directory for suggestions
"   * `parent` - Search under the parent of the active file for suggestions
"   * `vcsroot` - Search all files in the active file's version control system
"     direcotry hierarchy, e.g. a whole git repository
"  * `packageroot` - Find a package or build system configuration file in an
"    ancestor directory and search the hierarchy rooted there for suggestions
"
" @subsection Language handlers
" The following filetypes have language-specific handlers registered, often
" available with a handler name matching the filetype and/or overriding a
" default handler name. Most language implementations support the `Pattern`
" handler which returns a regex pattern matching many (but not all) possible
" import statements for a given symbol. `Pattern` handlers are used by other
" generic handlers to match a language's imports.
"
" `bzl` handler provides both of the below for Bazel BUILD and starkark files
"   * `prompt` - Suggest by showing `load("", "symbol_name")` in an
"     |input()| prompt with cursor inside the label quotes.
"   * `lang` - Merge added imports with others from the same source.
"
" `es6` handler provides both of the below for JavaScript and TypeScript
"   * `prompt` - Suggest by showing `import {SymbolName} from '';` in an
"     |input()| prompt with cursor inside the quotes.
"   * `lang` - Merge added imports with others from the same source.
"
" `java` handler provides both of the below
"   * `prompt` - Suggest by showing `import .SymbolName;` in an |input()|
"     prompt with the cursor before the dot.  Includes the `static` modifier if
"     the symbol looks like a constant or method name.
"   * `lang` - Insert import statements in alphabetic order, with `static`
"     imports grouped before type imports.
"
" `kotlin` handler provides both of the below
"   * `prompt` - Suggest by showing `import .SymbolName` in an |input()| prompt
"     with the cursor before the dot.
"   * `lang` - Insert import statements in alphabetic order.
"
" `python` handler provides both of the below
"   * `prompt` - Suggest by showing `from  import SymbolName` in an |input()|
"     prompt with the cursor between `from` and `import`, or a special case if
"     SymbolName contains a dot.
"   * `lang` - Merge relative imports from the same package, alphabetize others.
"
" The following languages support the `Pattern` handler:
"   * `bzl`
"   * `es6`
"   * `java`
"   * `kotlin`
"   * `python`


" *** Generic Handlers ***
" Suggesters
call s:registry.AddExtension({
      \ 'name': 'prompt',
      \ 'description': 'Prompt for import statement with symbol prefilled',
      \ 'Suggest': 'imp#handler#prompt#Suggest'})
call s:registry.AddExtension({
      \ 'name': 'buffer',
      \ 'description': 'Search open buffers for import statement',
      \ 'Suggest': 'imp#handler#buffer#Suggest'})
call s:registry.AddExtension({
      \ 'name': 'grep',
      \ 'description': 'Search directory hierarchy with grep command',
      \ 'IsAvailable': 'imp#handler#grep#IsAvailable',
      \ 'Suggest': 'imp#handler#grep#Suggest'})
call s:registry.AddExtension({
      \ 'name': 'ripgrep',
      \ 'description': 'Search directory hierarchy with rg command',
      \ 'IsAvailable': 'imp#handler#ripgrep#IsAvailable',
      \ 'Suggest': 'imp#handler#ripgrep#Suggest'})
call s:registry.AddExtension({
      \ 'name': 'ag',
      \ 'description': 'Search directory hierarchy with ag command',
      \ 'IsAvailable': 'imp#handler#ag#IsAvailable',
      \ 'Suggest': 'imp#handler#ag#Suggest'})
call s:registry.AddExtension({
      \ 'name': 'ack',
      \ 'description': 'Search directory hierarchy with ack command',
      \ 'IsAvailable': 'imp#handler#ack#IsAvailable',
      \ 'Suggest': 'imp#handler#ack#Suggest'})
call s:registry.AddExtension({
      \ 'name': 'gitgrep',
      \ 'description': 'Search git repository with git grep command',
      \ 'IsAvailable': 'imp#handler#gitgrep#IsAvailable',
      \ 'Suggest': 'imp#handler#gitgrep#Suggest'})
call s:registry.AddExtension({
      \ 'name': 'hggrep',
      \ 'description': 'Search Mercurial repository with hg grep command',
      \ 'IsAvailable': 'imp#handler#hggrep#IsAvailable',
      \ 'Suggest': 'imp#handler#hggrep#Suggest'})
call s:registry.AddExtension({
      \ 'name': 'known',
      \ 'description': 'Add imports in advance with imp#handler#known#Add()',
      \ 'Suggest': 'imp#handler#known#Suggest'})

" Pickers
call s:registry.AddExtension({
      \ 'name': 'inputlist',
      \ 'description': 'Pick import by number with inputlist()',
      \ 'Pick': 'imp#handler#inputlist#Pick'})
call s:registry.AddExtension({
      \ 'name': 'lucky',
      \ 'description': 'Always pick the first suggested import',
      \ 'Pick': 'imp#handler#lucky#Pick'})
call s:registry.AddExtension({
      \ 'name': 'window',
      \ 'description': 'Pick import with a split selector window',
      \ 'async': 1,
      \ 'IsAvailable': 'imp#handler#window#IsAvailable',
      \ 'Pick': 'imp#handler#window#Pick'})
call s:registry.AddExtension({
      \ 'name': 'fzf',
      \ 'description': 'Pick imports with FZF fuzzy finder',
      \ 'async': 1,
      \ 'IsAvailable': 'imp#handler#fzf#IsAvailable',
      \ 'Pick': 'imp#handler#fzf#Pick'})

" Inserters
call s:registry.AddExtension({
      \ 'name': 'lang',
      \ 'description': 'Overridden for filetype-specific import handling',
      \ 'IsAvailable': 'imp#util#AlwaysFalse',
      \ 'Insert': 'imp#util#AlwaysFalse'})
call s:registry.AddExtension({
      \ 'name': 'top',
      \ 'description': 'Insert import statement at top of the buffer',
      \ 'Insert': 'imp#handler#top#Insert'})
call s:registry.AddExtension({
      \ 'name': 'above',
      \ 'description': 'Insert import statement above the cursor line',
      \ 'Insert': 'imp#handler#above#Insert'})

" Reporters
call s:registry.AddExtension({
      \ 'name': 'echo',
      \ 'description': 'Report imports with :echo',
      \ 'Report': 'imp#handler#echo#Report'})
call s:registry.AddExtension({
      \ 'name': 'echomsg',
      \ 'description': 'Report imports with :echomsg',
      \ 'Report': 'imp#handler#echomsg#Report'})
call s:registry.AddExtension({
      \ 'name': 'popupnotify',
      \ 'description': 'Report with a short-lived popup at window top',
      \ 'IsAvailable': 'imp#handler#popupnotify#IsAvailable',
      \ 'Report': 'imp#handler#popupnotify#Report'})

" Locations
call s:registry.AddExtension({
      \ 'name': 'pwd',
      \ 'description': 'Search the current working directory',
      \ 'Location': 'imp#handler#pwd#Location'})
call s:registry.AddExtension({
      \ 'name': 'parent',
      \ 'description': 'Search parent directory of the active file',
      \ 'Location': 'imp#handler#parent#Location'})
call s:registry.AddExtension({
      \ 'name': 'vcsroot',
      \ 'description': 'Search whole version control system tree',
      \ 'Location': 'imp#handler#vcsroot#Location'})
call s:registry.AddExtension({
      \ 'name': 'packageroot',
      \ 'description': 'Search tree rooted at a package or build system config',
      \ 'Location': 'imp#handler#packageroot#Location'})

" *** Language-specific Handlers ***
" These can act as several interfaces. Remember to set the 'filetypes' property.
" Can also register language-specific overrides of default handlers by giving
" the same 'name' and setting 'filetypes'.

" Bazel Build load statements
call s:registry.AddExtension({
      \ 'name': 'bzl',
      \ 'description': 'Bazel Build load statement handling',
      \ 'filetypes': 'bzl',
      \ 'Insert': 'imp#lang#bzl#Insert',
      \ 'Suggest': 'imp#lang#bzl#Suggest',
      \ 'Pattern': 'imp#lang#bzl#Pattern'})
call s:registry.AddExtension({
      \ 'name': 'lang',
      \ 'description': 'Merge imports from same starlark file',
      \ 'filetypes': 'bzl',
      \ 'Insert': 'imp#lang#bzl#Insert',
      \ 'Pattern': 'imp#lang#bzl#Pattern'})
call s:registry.AddExtension({
      \ 'name': 'prompt',
      \ 'description': 'Prompt with a partial load statement',
      \ 'filetypes': 'bzl',
      \ 'Suggest': 'imp#lang#bzl#Suggest'})

" ECMAScript 6 static imports for JavaScript and TypeScript
let s:es6filetypes = ['javascript', 'javascriptreact',
        \ 'typescript', 'typescriptreact']
call s:registry.AddExtension({
      \ 'name': 'es6',
      \ 'description': 'ECMAscript 6 language import handling',
      \ 'filetypes': s:es6filetypes,
      \ 'Insert': 'imp#lang#es6#Insert',
      \ 'Suggest': 'imp#lang#es6#Suggest',
      \ 'Pattern': 'imp#lang#es6#Pattern'})
call s:registry.AddExtension({
      \ 'name': 'lang',
      \ 'description': 'Merge imports from same module',
      \ 'filetypes': s:es6filetypes,
      \ 'Insert': 'imp#lang#es6#Insert',
      \ 'Pattern': 'imp#lang#es6#Pattern'})
call s:registry.AddExtension({
      \ 'name': 'prompt',
      \ 'description': 'Prompt with a partial static import',
      \ 'filetypes': s:es6filetypes,
      \ 'Suggest': 'imp#lang#es6#Suggest'})

" Java
call s:registry.AddExtension({
      \ 'name': 'java',
      \ 'description': 'Java language import handling',
      \ 'filetypes': 'java',
      \ 'Insert': 'imp#lang#java#Insert',
      \ 'Suggest': 'imp#lang#java#Suggest',
      \ 'Pattern': 'imp#lang#java#Pattern'})
call s:registry.AddExtension({
      \ 'name': 'lang',
      \ 'description': 'Alphabetize fully qualified names, static first',
      \ 'filetypes': 'java',
      \ 'Insert': 'imp#lang#java#Insert',
      \ 'Pattern': 'imp#lang#java#Pattern'})
call s:registry.AddExtension({
      \ 'name': 'prompt',
      \ 'description': 'Prompt with a partial Java import statement',
      \ 'filetypes': 'java',
      \ 'Suggest': 'imp#lang#java#Suggest'})

" Kotlin
call s:registry.AddExtension({
      \ 'name': 'kotlin',
      \ 'description': 'Kotlin language import handling',
      \ 'filetypes': 'kotlin',
      \ 'Insert': 'imp#lang#kotlin#Insert',
      \ 'Suggest': 'imp#lang#kotlin#Suggest',
      \ 'Pattern': 'imp#lang#kotlin#Pattern'})
call s:registry.AddExtension({
      \ 'name': 'lang',
      \ 'description': 'Alphabetize fully qualified names',
      \ 'filetypes': 'kotlin',
      \ 'Insert': 'imp#lang#kotlin#Insert',
      \ 'Pattern': 'imp#lang#kotlin#Pattern'})
call s:registry.AddExtension({
      \ 'name': 'prompt',
      \ 'description': 'Prompt with a partial Kotlin import statement',
      \ 'filetypes': 'kotlin',
      \ 'Suggest': 'imp#lang#kotlin#Suggest'})

" Python
call s:registry.AddExtension({
      \ 'name': 'python',
      \ 'description': 'Python language import handling',
      \ 'filetypes': 'python',
      \ 'Insert': 'imp#lang#python#Insert',
      \ 'Suggest': 'imp#lang#python#Suggest',
      \ 'Pattern': 'imp#lang#python#Pattern'})
call s:registry.AddExtension({
      \ 'name': 'lang',
      \ 'description': 'Import python statement',
      \ 'filetypes': 'python',
      \ 'Insert': 'imp#lang#python#Insert',
      \ 'Pattern': 'imp#lang#python#Pattern'})
call s:registry.AddExtension({
      \ 'name': 'prompt',
      \ 'description': 'Prompt with a partial Python import statement',
      \ 'filetypes': 'python',
      \ 'Suggest': 'imp#lang#python#Suggest'})
