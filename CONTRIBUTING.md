# Contributing to Black omARCHy

Anyone with a GitHub account can propose a change. You do not need
collaborator access or an invitation.

## Submit a pull request

1. Fork `MahdiHedhli/BlackOmarchy` on GitHub.
2. Clone your fork and create a branch for one focused change.
3. Read [the project constitution](.specify/memory/constitution.md) and
   [the bootstrap specification](specs/001-black-omarchy-bootstrap/spec.md).
4. Make the change and add regression coverage for behavior changes.
5. Run `bash tests/unit/run.sh` and `git diff --check`.
6. Push your branch to your fork and open a pull request with base
   repository `MahdiHedhli/BlackOmarchy`, base branch `main`.

Describe the problem, the resulting behavior, and the checks you actually
ran. State which Omarchy version you used for installation testing, or
explicitly say when you did not run on an Omarchy host.

Keep public documentation, installation URLs, and update remotes pointed
at the upstream project. Contributor credit is retained in Git history.

## Validation

The unit suite runs without root and does not install packages or change
the host. It requires Bash, Python 3, GnuPG, and `bsdtar` (libarchive).
On Debian/Ubuntu, `bsdtar` is supplied by `libarchive-tools`; on Arch it
is supplied by `libarchive`.

Changes to bootstrap, package handling, update hooks, or uninstall also
need testing on a disposable supported Omarchy VM. Follow the
[VM test guide](tests/vm/README.md), check `blackomarchy verify`, and
report any checks you could not perform. Never run bootstrap on a
non-Omarchy development machine just to test a contribution.

## Project boundaries

Preserve Omarchy's desktop, package priority, and supported update path.
Keep the default tool set small. Skip package conflicts and fail closed
when a checksum, signature, or baseline cannot be verified.

Do not commit local operator files, VM access details, tokens, private
keys, or files from `private/`. Use synthetic examples in tests and docs.
