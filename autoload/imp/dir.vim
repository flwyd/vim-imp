" If one of these functions returns true for a directory path, that dir is a
" version control system root.
" TODO make this extensible.
" TODO more from https://en.wikipedia.org/wiki/List_of_version-control_software
" TODO consider what to do with git submodules, etc.
" Optimization: These are sorted by approximate popularity to reduce the number
" of filesystem existence checks.
let s:vcsRoots = [
      \ 'imp#dir#IsGitRoot',
      \ 'imp#dir#IsHgRoot',
      \ 'imp#dir#IsSvnRoot',
      \ 'imp#dir#IsBzrRoot',
      \ 'imp#dir#IsDarcsRoot',
      \ 'imp#dir#IsCvsRoot',
      \]

" If one of these functions returns true for a directory path, that dir has a
" package or build system config file, ideally in a way that indicates it's at
" the root of a software project (whereas finding the closest Makefile would
" likely find leaf directories rather than the root).
" Optimization: These are sorted by approximate popularity to reduce the number
" of filesystem existence checks.
let s:packageRoots = [
      \ 'imp#dir#IsMavenRoot',
      \ 'imp#dir#IsNpmRoot',
      \ 'imp#dir#IsBazelRoot',
      \ 'imp#dir#IsPythonRoot',
      \ 'imp#dir#IsComposerRoot',
      \ 'imp#dir#IsAutoconfRoot',
      \ 'imp#dir#IsRubyRoot',
      \]

""
" @public
" Returns a list of directories to search in an import operation involving
" {context}.  This function returns the first non-empty result from a preferred
" Location handler, or empty list if all preferred handlers return empty.  See
" @section(handlers-location).
function! imp#dir#PreferredLocations(context) abort
  for l:handler in imp#handler#Preferred(a:context, 'Location')
    let l:dirs = maktaba#function#Apply(l:handler.Location, a:context)
    if !empty(l:dirs)
      return maktaba#ensure#IsList(l:dirs)
    endif
  endfor
  return []
endfunction

""
" @public
" Checks {path} and successive parent directories, returning the first directory
" path for which {predicate} (a maktaba callable) returns true, or empty string
" if predicate returns false for all ancestor directories.  {path} is not
" |expand()|ed or made absolute, so this function might return empty for a
" relative path even if it could have found a matching parent of that directory
" if given an absolute path.
function! imp#dir#AncestorMatching(predicate, path) abort
  " Implementation note: The general approach is to check for several different
  " things (e.g. VCS directories) at each directory step rather than using
  " finddir() because we want to find the closest ancestor matching any
  " predicate rather than any ancestor of the first predicate.
  let l:Predicate = maktaba#function#Create(a:predicate)
  let l:dir = maktaba#ensure#IsString(a:path)
  while !empty(l:dir)
    if l:Predicate.Apply(l:dir)
      return l:dir
    endif
    let l:prev = l:dir
    let l:dir = fnamemodify(l:dir, ':h')
    if l:dir ==# l:prev
      " :h modifier doesn't change '.', '/', etc. so we reached a root
      return ''
    endif
  endwhile
  return ''
endfunction

""
" @public
" Returns 1 if {path} is a directory and is the root of some version control
" system repository, 0 otherwise.
function! imp#dir#IsVcsRoot(dir) abort
  if !isdirectory(maktaba#ensure#IsString(a:dir))
    return 0
  endif
  for l:f in s:vcsRoots
    if maktaba#function#Apply(l:f, a:dir)
      return 1
    endif
  endfor
  return 0
endfunction

""
" @public
" Returns 1 if {path} is a directory and is the root of some packaging or build
" system, 0 otherwise.
function! imp#dir#IsPackageRoot(dir) abort
  if !isdirectory(maktaba#ensure#IsString(a:dir))
    return 0
  endif
  for l:f in s:packageRoots
    if maktaba#function#Apply(l:f, a:dir)
      return 1
    endif
  endfor
  return 0
endfunction

""" Version control system (VCS) root detectors sorted alphabetically """

""
" @public
" Returns 1 if {dir} is the root directory of a GNU Bazaar repository, 0
" otherwise.
function! imp#dir#IsBzrRoot(dir) abort
  return isdirectory(maktaba#path#Join([a:dir, '.bzr']))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a CVS repository, 0 otherwise.
function! imp#dir#IsCvsRoot(dir) abort
  return exists(maktaba#path#Join([a:dir, 'CVSROOT']))
        \ || (isdirectory(maktaba#path#Join([a:dir, 'CVS']))
        \ && !isdirectory(maktaba#path#Join([fnamemodify(a:dir . ':h'), 'CVS'])))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a Darcs repository, 0 otherwise.
function! imp#dir#IsDarcsRoot(dir) abort
  return isdirectory(maktaba#path#Join([a:dir, '_darcs']))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a Git repository, 0 otherwise.
function! imp#dir#IsGitRoot(dir) abort
  return isdirectory(maktaba#path#Join([a:dir, '.git']))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a Mercurial repository, 0
" otherwise.
function! imp#dir#IsHgRoot(dir) abort
  return isdirectory(maktaba#path#Join([a:dir, '.hg']))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a Subversion repository, 0
" otherwise.
function! imp#dir#IsSvnRoot(dir) abort
  return isdirectory(maktaba#path#Join([a:dir, '.svn']))
        \ && !isdirectory(maktaba#path#Join([fnamemodify(a:dir . ':h'), '.svn']))
endfunction


""" Build/package system root detectors, sorted alphabetically """

""
" @public
" Returns 1 if {dir} is the root directory of a package using GNU autoconf, 0
" otherwise.
function! imp#dir#IsAutoconfRoot(dir) abort
  return filereadable(maktaba#path#Join([a:dir, 'configure.ac']))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a package using Bazel build, 0
" otherwise.
function! imp#dir#IsBazelRoot(dir) abort
  return filereadable(maktaba#path#Join([a:dir, 'WORKSPACE']))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a package using Composer (PHP
" dependency manager), 0 otherwise.
function! imp#dir#IsComposerRoot(dir) abort
  " This will return false for vendor/foo which has a composer.json but not
  " a composer.lock.
  return filereadable(maktaba#path#Join([a:dir, 'composer.lock']))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a package using Apache Maven, 0
" otherwise.
function! imp#dir#IsMavenRoot(dir) abort
  return filereadable(maktaba#path#Join([a:dir, 'pom.xml']))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a package using npm (Node Package
" Manager), 0 otherwise.
function! imp#dir#IsNpmRoot(dir) abort
  " This will return false for node_modules/foo which has a package.json but not
  " a package-lock.json.
  return filereadable(maktaba#path#Join([a:dir, 'package-lock.json']))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a package using Python packaging,
" 0 otherwise.
function! imp#dir#IsPythonRoot(dir) abort
  return filereadable(maktaba#path#Join([a:dir, 'pyproject.toml']))
        \ || filereadable(maktaba#path#Join([a:dir, 'setup.cfg']))
        \ || filereadable(maktaba#path#Join([a:dir, 'setup.py']))
endfunction

""
" @public
" Returns 1 if {dir} is the root directory of a package using Ruby Gems, 0
" otherwise.
function! imp#dir#IsRubyRoot(dir) abort
  return filereadable(maktaba#path#Join([a:dir, 'Gemfile.lock']))
endfunction
