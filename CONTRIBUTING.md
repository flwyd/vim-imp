# How to contribute to vim-imp

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

## Follow the code of conduct

Open Source works best when everyone feels comfortable and empowered to
participate. Please read and follow the [code of conduct](CODE_OF_CONDUCT.md)
and don't be a jerk.

## Discuss new functionality

This project seeks to provide a framework for easy management of import
statements in several programming languages. Expanded language support and new
feature ideas are welcome, but changes need to balance the overall architecture.
Please open a GitHub issue to discuss major proposed changes before sending a
pull request.

## Test code

This project contains many carefully-crafted regular expressions, which can
often be difficult to read. A small change to a regex can easily break matching
for some statements. When adding support for a new language or expanding syntax
support, please add test cases for all styles of import statement supported by
that language, along with negative test cases which should not match (e.g. an
import statement inside a comment). Tests are written using
[themis](https://github.com/thinca/vim-themis) with test data in the
`test/fixtures` directory. Run tests from inside the `vim-imp` directory:

```sh
git clone https://github.com/thinca/vim-themis ~
~/vim-themis/bin/themis --reporter=spec ./test
```

(On Windows use `path\to\vim-themis\bin\themis.bat`.)

Note that some tests use real executable commands running over fixture files
rather than mock responses; I've caught bugs in regex constructions by using the
actual `grep` rather than faking a response. However, this means tests will be
skipped if you don't have the appropriate suggest command (`rg`, `ag`, `ack`,
etc.) installed. I also don't have tests for `gitgrep` and `hggrep` handlers yet
since that would involve setting up a VCS directory in the test.

## Source Code Headers

Every file containing source code must include copyright and license
information. Use the [`addlicense` tool](https://github.com/google/addlicense)
to ensure it’s present when adding files: `addlicense -c “Google LLC” -l apache
.`

Apache header:

```
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
