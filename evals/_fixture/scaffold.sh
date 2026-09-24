#!/usr/bin/env bash
# Copies the shared eval project into the run's working directory (the cwd a scaffold
# runs in). `context.add_dirs` cannot do this: it mounts a side directory, leaves the cwd
# empty, and prompt-router.sh then sees an un-adopted project and stays silent.
#   adopted  — full ck-code project (docs/architecture + tasks/ v7 layout)
#   no-arch  — same, minus docs/architecture (plan's prerequisite is missing)
set -eu
src="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)/adopted"
cp -R "$src/." .
case "${1:-adopted}" in
  adopted) ;;
  no-arch) rm -rf docs/architecture ;;
  *) echo "scaffold.sh: unknown variant $1" >&2; exit 1 ;;
esac
