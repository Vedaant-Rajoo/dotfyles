# Commit messages

Commits use scoped subjects, as in Linux, Git, Go, and nixpkgs:

    <scope>: <description>

    Optional body: why the change was made.

    Co-Authored-By: Name <email>

- The scope names the area the change touches: a directory or file that exists
  in the repository, at any depth, without extension, and always lowercase,
  even when the file name is not (`fish`, `nvim`, `bootstrap` for
  `bin/bootstrap`, `brewfile` for `Brewfile`, `readme` for `README.md`). Nest
  with `/` (`fish/conf.d`), name two areas with `, ` (`fish, nvim`), and use
  `treewide` for repository-wide changes.
- No type words: not `feat(fish):`, not `chore:`. Older history uses
  Conventional Commits (`type(scope): ...`); do not copy it.
- The description is imperative ("add", not "added" or "adds"), starts with a
  lowercase word, and has no trailing period. Later words keep their case.
- The whole subject is at most 72 characters.
- The body is optional plain prose or short bullets, after a blank line.
  Trailers such as Co-Authored-By or Signed-off-by go last, after another
  blank line.
- Merge, revert, and fixup!/squash!/amend! subjects that git writes pass as-is.

- good: `fish: add tmux sessionizer keybind`
- good: `fish/conf.d: cache zoxide init output`
- good: `bootstrap: install native arm64 steam instead of the intel cask`
- good: `brewfile: add the zed cask and sort Brewfile`
- good: `fish, nvim: switch both to the gruvbox theme`
- good: `treewide: drop zig tooling`
- bad: `feat(fish): add tmux sessionizer keybind` (type word)
- bad: `chore: prune gitignore entries` (`chore` is not a path; use `gitignore:`)
- bad: `Brewfile, fish: add direnv` (scopes are lowercase: `brewfile, fish:`)
- bad: `fish: Added a keybind.` (capitalized, past tense, trailing period)
