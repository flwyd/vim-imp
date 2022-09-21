# Vim Imp

vim-imp is a plugin for managing import statements in the Vim text editor. Its
core purpose is to insert a fully-qualified import statement for a symbol in
your program. For example, `:ImpSuggest List` in a Java file might prompt the
developer with options

```
import java.util.List;
import java.awt.List;
import com.lowagie.text.List;
import com.example.api.MyService.Method.List;
```

while `:ImpFirst` would insert the `java.util.List` version without prompting.
This can be used while adding a new identifier to your program, or when running
through quickfix errors because the compiler yelled at you for not importing
something.

Both `:ImpSuggest` and `:ImpFirst` accept multiple symbols in one command, e.g.
`:ImpSuggest Model View Controller`, which will make a suggestion for each in
turn. Partially-qualified imports are also supported, e.g. `:ImpFirst Math.min`
to get `import static java.lang.Math.min;`.

This README is meant to help you get started; for extensive documentation see
`:help imp`.

One of Imp's goals is to have a language-agnostic interface; the commands and
mappings should work the same if you're importing a symbol in Java, TypeScript,
Python, BUILD files, etc. Imp additionally avoids MxN tool–language explosions
by providing generic Suggest and Pick handlers while delegating regex generation
and statement insertion to language-specific but tool-agnostic handlers.

A non-goal is doing anything with wildcard imports like `import java.util.*;`.
Such imports make it hard to know what symbols are available, and they're
generally not needed if your editor has good support for importing specific
symbols. (Note that ES6 wildcard imports like `import * as foo from 'foolib';`
*are* supported, on the assumption that a consistent name is used for a
particular library and this doesn't actually pollute your namespace, it just
lets you call `foo.whatever()` rather than importing `whatever` by name.)

## Installation

This plugin depends on the [Maktaba](https://github.com/google/vim-maktaba)
library and is best configured using
[Glaive](https://github.com/google/vim-glaive). To install them, use your
favorite plugin manager, e.g.

```vim
" vim-plug:
Plug 'google/vim-maktaba' | Plug 'google/vim-glaive'
Plug 'flwyd/vim-imp'

" Vundle:
Plugin 'google/vim-maktaba'
Plugin 'google/vim-glaive'
Plugin 'flwyd/vim-imp'
" This line goes after vundle#end()
call glaive#Install()

" vim-addon-manager:
call vam#ActivateAddons(['glaive', 'github:flwyd/vim-imp'])
```

or `git clone https://github.com/flwyd/vim-imp` and `set
runtimepath+=/path/to/vim-imp` in your `.vimrc`

or as a vim8 package:

```sh
mkdir -p ~/vim/pack/vim-imp/start
git clone https://github.com/google/vim-maktaba ~/vim/pack/vim-maktaba/start
git clone https://github.com/google/vim-glaive ~/vim/pack/vim-glaive/start
git clone https://github.com/flwyd/vim-imp ~/vim/pack/vim-imp/start
```

## Getting started

### Configuration

Imp consists of several types of *handlers*; there are several implementations
of each handler. Importing a symbol happens in several stages—one per handler
type—and each stage calls handler implementations in order until one returns a
value. The order of handlers is configured using Maktaba settings, with
[Glaive](https://github.com/google/vim-glaive) as the easy way to do this.
Handler order can be specified for a specific language; the `default` handlers
are used if none are configured for the language. You can see a list of all
handlers by running `:ImpHandlers` once the plugin is installed. An example
configuration in your `.vimrc` after plugins are loaded:

```vim
Glaive imp plugin[mappings]
  \ Suggest[default]=buffer,ripgrep,prompt
  \ Location[default]=packageroot
  \ Pick[default]=window Pick[python]=lucky
  \ Insert[bzl]=top
  \ Report[default]=popupnotify
```

Explanation:

*   `Glaive imp` activates the Imp plugin.
*   `plugin[mappings]` installs the default mappings, `:help imp-mappings` (use
    `plugin[mappings]=_` to use a different character like underscore rather
    than `<Leader>i` as a prefix).
*   `Suggest[default]=buffer,ripgrep,prompt` will first look for import
    statements in other open buffers, then use
    [ripgrep](https://github.com/BurntSushi/ripgrep) to find possible imports in
    nearby files. If `rg` doesn't return any results then it will prompt for a
    statement, using a language-specific template. The `Suggest` default is
    `buffer,known,prompt`.
*   `Location[default]=packageroot` instructs handlers like `ripgrep`, `ag`,
    `ack`, and `grep` to look in files in a hierarchy which shares a build
    system config file (e.g. find the nearest Bazel `BUILD` file). The
    `Location` default is `vcsroot,pwd` (search the whole version control
    repository directory, or the current working directory if not in a VCS
    repo).
*   `Pick[default]=window Pick[python]=lucky` will present a split window to
    pick from multiple import options in most languages, but will use the
    `lucky` handler for Python, inserting the first match found without
    prompting. The `Pick` default is `inputlist` which shows numbered options at
    the bottom of the screen.
*   `Insert[bzl]=top` will add `load` statements to the first line of
    `.bzl`/`BUILD` files rather than inserting them in sorted order. This
    example does not override the default `Insert` handler list, which is
    `lang,top`, which uses a language-specific insertion strategy before falling
    back to first-line behavior.
*   `Report[default]=popupnotify` shows the added import statement in a popup
    window at the top of the screen which will disappear after a few seconds.
    The default `Report` handler is `echo` which prints the import statement at
    the bottom of the screen (and requires hitting return if multiple statements
    are imported).

Some handlers have additional settings, e.g. to specify a path to a command or
add additional arguments. See `:help imp-config` for details.

### Import some symbols

Use Imp in command mode:

*   `:ImpSuggest List` to use the Prompt handler if more than one match for
    `List` is found
*   `:ImpFirst Optional` to insert the first/best match for `Optional`.

In normal mode, the default mapping `\ii` will run `:ImpSuggest` on the symbol
under the cursor while `\if` will run `:ImpFirst`. (If you have `mapleader` in
your .vimrc then replace `\` with your chosen leader.) There aren't any default
insert-mode mappings, but I recommend something like this, which lets you hit
ctrl-X twice in insert mode to add the symbol next to your cursor and then keep
typing.

```vim
inoremap <C-X><C-X> <Plug>(imp-suggest-current)
inoremap <F3> <Plug>(imp-first-current)
```

## Language Support

Some of the handlers can work without any language support. If you edit a text
file and run `:ImpSuggest foo` then the `prompt` Suggest handler will ask you
for an import statement for `foo` and the `top` Insert handler will put that
line on the first line of the file. But the plugin is most effective when
there's an available `lang` plugin for the filetype you're editing. As of early
September 2022, the supported languages are

*   `bzl` (load() statements in Bazel BUILD files and Starlark .bzl files)
*   `es6` (static imports in JavaScript, TypeScript, and .jsx/.tsx; no dynamic
    `import("…")` or `goog.require()` support)
*   `java` (static and non-static imports in Java)
*   `kotlin` (Kotlin imports, including aliases)
*   `python` (`import foo` and `from foo import bar` support including aliases)

I would like to have "compatible languages" be able to import from each other if
the main language didn't have any matches. For example, we should be able to
import `MyJavaUtil` from Kotlin even if you're the first person to import it in
a `.kt` file. I haven't decided exactly how to do this yet, though; I'm
considering a `jvm` handler.

## Feedback and future plans

I've been this plugin using for several months and it feels pretty ergonomic,
but I would love feedback. Are the defaults sensible? Are there ways the
commands could be improved? Are there imports the regex patterns fail to find?
Is the documentation clear enough? Please open a GitHub issue if you have
feedback about the way things work.

The languages supported so far are a subset ones I've needed to use in my day
job. If you'd like support for your favorite programming language please open a
GitHub issue with examples of how import statements work in that language. If
you'd like to implement support, see the
[contributor documentation](CONTRIBUTING.md). Some attractive languages include
C#, Lua, PHP, and Rust. I haven't yet addressed languages where symbols aren't
named explicitly: it's hard to know what symbols `#include` could bring into a C
or C++ program, though C++ `using` statements could be handled; this problem
also applies to Ruby, Swift, Dart, and Protocol Buffers.

There is a running list of potential enhancements at the bottom of `:help imp`.

## License

Vim Imp is copyright 2022 Google LLC. It is made available under the Apache 2.0
license, see [`LICENSE`](LICENSE) for details.

## Disclaimer

This project is not an official Google project. It is not supported by Google
and Google specifically disclaims all warranties as to its quality,
merchantability, or fitness for a particular purpose.
