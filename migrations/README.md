# Migrations

This configuration currently runs on one machine, so no migrations ship.
Snapshot state under `.local/snapshots/`, clean up retired managed state directly,
and report the cleanup. Preserve user data. Add migrations again only after the
user reports that a second machine has been bootstrapped.

A migration brings an existing machine in line with the current configuration:
it uninstalls a package manager the repository retired, moves a file to its new
place, or clears state an old setup left behind. `bin/migrate` runs each file
here once per machine, in name order. `bin/bootstrap` and `bin/u` both call it,
but with no migration files there is nothing to apply:

```bash
bin/migrate --pending   # list what has not run yet; exits 0 only if something is pending
bin/migrate             # run it
```

Completion markers live in `~/.local/state/dotfyles/migrations/`. Deleting a
marker makes that migration run again.

## Writing one

Once migrations resume, add one whenever a change leaves state on existing
machines that the new configuration no longer owns. Name it after the current
Unix time (`date +%s`.sh), so it sorts after every earlier one.

- Plain Bash, mode 644, no shebang. The runner executes it with
  `bash -euo pipefail` from `$HOME`, with `$REPO_ROOT` set to this checkout.
- Start with an `echo` that says what it does; that line is what the user sees.
- Make it idempotent and safe on a new machine. Bootstrap runs every migration
  there too, so a migration that finds nothing to change exits 0 and is recorded
  as done.
- Exit non-zero when it cannot finish, for example when a replacement is not
  installed yet. It then stays pending, and later migrations wait for it.
- Remove only what the repository installed or generated. Leave user data, such
  as old runtime installs that virtualenvs may point into, and print where it is.
- Cover it in `tests/bin/migrate_test.fish`: what it changes on a machine that
  needs it, and that it changes nothing on one that does not.
