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

let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

""
" @section Configuration, config
" @plugin(stylized) finds and adds import statements through a multi-stage
" pipeline.  Each step of the process uses a handler interface.  The primary
" configuration for @plugin is lists of preferred handlers, either for specific
" filetypes or the special `default` handlers when no per-filetype list has been
" configured.  The handler types are
"   * Suggest (find a list of potential import statements)
"   * Pick (present a list of suggestions and allow one or more choices)
"   * Insert (add choisen imports to the buffer)
"   * Report (inform the user which statements were imported)
" For more information about these handlers, see @section(handlers).  For a list
" of handlers of each type, see @section(handlers-list) or run |:ImpHandlers|.
"
" This plugin uses |maktaba| flags for configuration. Install |Glaive|
" (https://github.com/google/glaive) and use the |:Glaive| command to configure
" them.

" *** Flags that choose extensions ***

""
" Per-filetype dict with names of Suggest handlers (list of strings) to use when
" looking up a symbol.  Suggesters are tried in order until one returns a
" non-empty list of candidate import statements.  If there is no entry for a
" filetype, the `default` list is used.
"
" Example configuration: >
"   Glaive @plugin(name) Suggest[default]=buffer,known,ripgrep,prompt
"     \ Suggest[intercal]=known,prompt
" <
call s:plugin.Flag('Suggest', {'default': ['buffer', 'known', 'prompt']})

""
" Per-filetype dict with name(s) of Pick handlers to select one of a suggested
" list of imports.  The Pick step is skipped when only one import is suggested.
" If there is no entry for the current filetype, the `default` list is used.
" Multiple pickers may be specified, but only the first which `IsAvailable()`
" will be used, so this is mostly useful if the first picker depends on a vim
" feature or external command.
"
" Example configuration: >
"   Glaive @plugin(name) Pick[default]=fzf,window Pick[intercal]=selectlist
" <
call s:plugin.Flag('Pick', {'default': ['inputlist']})

""
" Per-filetype dict with the names of Insert haandles to add the import
" statement to the current buffer.  The default `['lang', 'top']` first tries
" language-specific handlers (`lang`), falling back to putting the statement at
" the top of the file (`top`).
"
" Example configuration: >
"   Glaive @plugin(name) Insert[default]=lang,above Insert[intercal]=top
" <
call s:plugin.Flag('Insert', {'default': ['lang', 'top']})

""
" Per-filetype dict with the name of Report handlers which inform the user of
" imports that were inserted.  All reporters in the list will be called,
" allowing multiple streams (e.g. print to screen and write to log).  The
" Report list can also be empty and imports will not be announced.
"
" Example configuration: >
"   Glaive @plugin(name) Report[default]=popupnotify,echomsg Report[c]=
" <
call s:plugin.Flag('Report', {'default': ['echo']})

""
" Per-filetype dict with the name of Pattern handlers which build a
" language-specific regular expression for a symbol. This handler is used by
" some generic handlers like `grep` and `ripgrep`; the default value of `lang`
" is usually sufficient for this setting.
"
" Example configuration: >
"   Glaive @plugin(name) Pattern[default]=lang Pattern[c]=myincludepattern
" <
call s:plugin.Flag('Pattern', {'default': ['lang']})

""
" Per-filetype dict with the name of Location handlers to indicate which
" directory tree some Suggest handlers (like `grep`, `ripgrep`, `ag`, `ack`,
" `gitgrep`, and `hggrep`) will use to search for a matching import statement.
"
" Example configuration: >
"   Glaive @plugin(name) Location[default]=packageroot,parent
"     \ Location[c]=findbasemakefile
" <
call s:plugin.Flag('Location', {'default': ['vcsroot', 'pwd']})


" *** Flags for specific extensions ***

""
" Configuration for the `parent` Location handler.  If `levels` is greater than
" zero, that many directories above the file's parent will be searched.  For
" example, editing `foo/bar/baz/qux.py` setting `parent[levels]=1` will search
" the hierarchy under `foo/bar` for suggest handlers like `grep`.
call s:plugin.Flag('parent', {'levels': 0})

""
" Configuration for the buffer Suggest handler, searching vim buffers of the
" same file type for an import statement. If the `load` setting is true,
" unloaded buffers will be loaded before searching.
call s:plugin.Flag('buffer', {'load': 0})

""
" Configuration for the grep Suggest handler, searching a directory hierarchy
" with `grep`. The `command` setting provides the executable path and `args` is
" a list of arguments prepended to the command line.  Note that any arg which
" changes the output format may produce invalid Suggest results.  Note that,
" unlike ripgrep, ag, and ack, by default grep does not exclude any directories
" like `vendor` or `node_modules`, and results may therefore be slow without
" adding such directories to the flag.  The grep handler does exclude hidden
" directories that start with a `.`, which includes many support directories for
" version control systems, e.g. the `.git` directory.
"
" Example configuration: >
"   Glaive @plugin(name) grep[command]=/path/to/grep
"     \ grep[args]=['--exclude-dir=node_modules', '--mmap']
" <
call s:plugin.Flag('grep', {'command': 'grep', 'args': []})

""
" Configuration for the ripgrep Suggest handler, searching a directory hierarchy
" with `rg`. The `command` setting provides the executable path and `args` is a
" list of arguments prepended to the command line.  Note that any arg which
" changes the output format may produce invalid Suggest results.
"
" Example configuration: >
"   Glaive @plugin(name) ripgrep[command]=/path/to/rg
"     \ ripgrep[args]=['--no-config', '--hidden']
" <
call s:plugin.Flag('ripgrep', {'command': 'rg', 'args': []})

""
" Configuration for the ag (The Silver Searcher) Suggest handler, searching a
" directory hierarchy with `ag`. The `command` setting provides the executable
" path and `args` is a list of arguments prepended to the command line.  Note
" that any arg which changes the output format may produce invalid Suggest
" results.
"
" Example configuration: >
"   Glaive @plugin(name) ag[command]=/path/to/ag
"     \ ag[args]=['--depth=5', '--one-device']
" <
call s:plugin.Flag('ag', {'command': 'ag', 'args': []})

""
" Configuration for the ack Suggest handler, searching a directory hierarchy
" with `ack`. The `command` setting provides the executable path and `args` is a
" list of arguments prepended to the commandline.  Note that any arg which
" changes the output format may produce invalid Suggest results.
"
" Example configuration: >
"   Glaive @plugin(name) ack[command]=/path/to/ack-grep
"     \ ack[args]=['--follow', '--ignore-ack-defaults']
" <
call s:plugin.Flag('ack', {'command': 'ack', 'args': []})

""
" Configuration for the gitgrep Suggest handler, searching a git repository with
" `git grep`. The `command` setting provides the git executable path, the `grep`
" setting is the name of the subcommand (e.g. a `mygrep` alias), and `args` is
" a list of command line arguments to include.  Note that any arg which changes
" the output format may produce invalid Suggest results.
"
" Example configuration: >
"   Glaive @plugin(name) gitgrep[command]=/path/to/git gitgrep[grep]=mygrep
"     \ gitgrep[args]=['--untracked', '--max-depth=7']
" <
call s:plugin.Flag('gitgrep', {'command': 'git', 'grep': 'grep', 'args': []})

""
" Configuration for the hggrep Suggest handler, searching a Mercurial repository
" with `hg grep`. The `command` setting provides the hg executable path, the
" `grep` setting is the name of the subcommand (e.g. a `mygrep` alias), and
" `args` is a list of command line arguments to include.  Note that any arg
" which changes the output format may produce invalid Suggest results.
"
" Example configuration: >
"   Glaive @plugin(name) hggrep[command]=/path/to/hg hggrep[grep]=mygrep
"     \ hggrep[args]=['--text', '--exclude=somedir']
" <
call s:plugin.Flag('hggrep', {'command': 'hg', 'grep': 'grep', 'args': []})

""
" Configuration for the popupnotify Report handler.  `time` is the time in
" milliseconds  to display the notification.  `position` can be `topleft`,
" `bottomright`, `centerleft`, `topcenter`, etc.
"
" Example configuration: >
"   Glaive @plugin(name) popupnotify[time]=5000
"     \ popupnotify[position]=bottomleft
" <
call s:plugin.Flag('popupnotify', {'time': 3000, 'position': 'topright'})
