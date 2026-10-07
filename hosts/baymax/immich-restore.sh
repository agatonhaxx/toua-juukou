#!/usr/bin/env bash
#
# One-off recovery of the immich database: load the dump the Docker-era install
# left behind (immich 2.7.5, PostgreSQL 14, pgvecto.rs) into the cluster this
# flake manages (immich 3.2.1, PostgreSQL 17, vchord with pgvector). Throwaway:
# delete this file once the library has been checked on the new install.
#
# Run it on baymax as root, after `just switch` has created the new cluster:
#
#   sudo ./hosts/baymax/immich-restore.sh            # shelter, preprocess, load
#   sudo systemctl start immich-server
#   journalctl -fu immich-server                     # the migrations run here
#   sudo ./hosts/baymax/immich-restore.sh verify
#
# The dump cannot simply be piped back in:
#
#   * its clean-up preamble drops objects a database that was just created does
#     not have, and `IF EXISTS` does not cover all of it -- `DROP TRIGGER ... ON
#     <table>` names a table that has to exist -- so the whole preamble goes;
#   * the extensions, the `vectors` schema and every `OWNER TO` describe the old
#     cluster. postgresql-setup.service creates the extensions the new one wants,
#     and a dump loaded as the `immich` role is owned by `immich`;
#   * pgvecto.rs columns become pgvector columns -- the vectors are stored as
#     text, `[1, 2, 3]`, either way. The old vector indexes are dropped rather
#     than translated, because they name an extension this cluster does not have:
#     immich rebuilds `face_index` and `clip_index` itself on its first start,
#     for the extension it finds. The `migration_overrides` rows that still
#     describe them are left alone -- only immich's own migrations read that
#     table, and both of those migrations have already run;
#   * paths under the container's `/usr/src/app/upload` become paths under the
#     host's media location, since immich refuses to start when the database
#     records a different upload root than the one it is configured with.
#
# The dumps are copied out first: immich's own backup job writes into that same
# directory and prunes it. Nothing here touches those copies or the originals,
# so `load` can be run again from the same dump as often as it takes.

set -euo pipefail
umask 077

# What hosts/baymax/default.nix configures, and what immich stored as its
# MediaLocation before the move.
media_root=/data/baymax/qt/immich
old_media_root=/usr/src/app/upload
db=immich
db_user=immich
units=(immich-server.service immich-machine-learning.service)

backups_dir=$media_root/backups
shelter_dir=/data/baymax/qt/immich-dumps-pg14
work_dir=/data/baymax/qt/immich-restore

pg_bin=

note() { printf '  %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
usage: immich-restore.sh [stage]

  shelter     copy the dumps out of the directory immich's own backup job
              writes to and prunes
  preprocess  rewrite the newest copy for the new cluster
  load        drop and recreate the immich database, then load the rewritten
              dump as the immich role
  verify      compare row counts with the dump and check the migrations and
              the vector indexes; run it once immich has started
  all         shelter, preprocess and load (the default)

IMMICH_RESTORE_YES=1 answers the confirmation prompt in `load`.
EOF
}

require_root() {
  if ((EUID != 0)); then
    die "this needs root: sudo $0 ${1:-}"
  fi
}

confirm() {
  local reply
  if [[ ${IMMICH_RESTORE_YES:-} == 1 ]]; then
    return 0
  fi
  read -r -p "$1 [y/N] " reply
  [[ $reply == [yY] || $reply == [yY][eE][sS] ]]
}

# The client has to match the server's major version, and the one in PATH need
# not be that one, so it is taken from the running server binary.
resolve_pg() {
  local pid

  if [[ -n $pg_bin ]]; then
    return 0
  fi

  pid=$(systemctl show --property MainPID --value postgresql.service)
  if [[ ! $pid =~ ^[1-9][0-9]*$ ]]; then
    die "postgresql.service is not running; it is started by 'just switch'"
  fi

  pg_bin=$(dirname "$(readlink -f "/proc/$pid/exe")")
  note "using the client in $pg_bin"
}

as_postgres() { sudo -u postgres "$pg_bin/psql" -X -v ON_ERROR_STOP=1 "$@"; }
db_scalar() { sudo -u "$db_user" "$pg_bin/psql" -X -tA -v ON_ERROR_STOP=1 -d "$db" -c "$1"; }
db_table() { sudo -u "$db_user" "$pg_bin/psql" -X -v ON_ERROR_STOP=1 -d "$db" -c "$1"; }

newest_dump() {
  local dump
  dump=$(find "$shelter_dir" -maxdepth 1 -name '*.sql.gz' -printf '%T@ %p\n' |
    sort -n | tail -n 1 | cut -d' ' -f2-)
  if [[ -z $dump ]]; then
    die "no dump in $shelter_dir; run the shelter stage first"
  fi
  printf '%s\n' "$dump"
}

shelter() {
  require_root "$1"

  if [[ ! -d $backups_dir ]]; then
    die "$backups_dir does not exist; check immich's media location"
  fi

  install -d -m 0700 "$shelter_dir"

  local dump name
  for dump in "$backups_dir"/*.sql.gz; do
    [[ -e $dump ]] || continue
    name=$(basename "$dump")
    if [[ -e $shelter_dir/$name ]]; then
      note "already sheltered: $name"
      continue
    fi
    cp --preserve=mode,timestamps "$dump" "$shelter_dir/$name"
    note "sheltered $name"
  done
}

preprocess() {
  require_root "$1"
  install -d -m 0700 "$work_dir"

  local dump sql
  dump=$(newest_dump)
  sql=$work_dir/immich-pg14.sql
  note "preprocessing $(basename "$dump")"

  cat >"$work_dir/preprocess.awk" <<'AWK'
# Rewrites a pg_dump of the Docker-era immich database into something the new
# cluster can load. The counts in the summary the END block prints are what the
# caller checks the result against.
BEGIN {
  in_copy = 0
  in_index = 0
  copy_table = ""
  path_tables["asset"] = 1
  path_tables["asset_file"] = 1
  path_tables["person"] = 1
  path_tables["system_metadata"] = 1
}

# pgvecto.rs index definitions run over several lines, up to the indented `');`
# that closes their options string. immich builds the index itself, for the
# vector extension it finds.
/^CREATE (UNIQUE )?INDEX .* USING vectors / {
  indexes++
  in_index = 1
  next
}
in_index {
  index_lines++
  if ($0 ~ /^[[:space:]]*'\);$/) in_index = 0
  next
}

# The clean-up preamble, and the old cluster's extensions and ownership.
/^DROP / { drops++; next }
/^ALTER TABLE IF EXISTS / { alters++; next }
/^ALTER (TABLE|FUNCTION|TYPE|SCHEMA|SEQUENCE) .* OWNER TO / { owners++; next }
/^CREATE SCHEMA vectors;$/ { schemas++; next }
/^CREATE EXTENSION / { extensions++; next }
/^COMMENT ON EXTENSION / { comments++; next }

# psql's dump guards, which a client older than the dump does not know.
/^\\restrict / { guards++; next }
/^\\unrestrict / { guards++; next }

# COPY data. The paths in these four tables are the only mention of the old
# upload root outside the header comments.
/^COPY / {
  split($2, qualified, ".")
  copy_table = qualified[2]
  gsub(/"/, "", copy_table)
  in_copy = 1
  print
  next
}
in_copy && /^\\\.$/ { in_copy = 0; print; next }
in_copy {
  if (copy_table in path_tables) {
    paths[copy_table] += gsub(old_root, new_root)
  }
  print
  next
}

# Everything else: pgvecto.rs columns become pgvector columns. pg_dump's own
# `-- Name:` comments are left alone, but a statement or a data line that still
# names the old extension is something to look at.
{
  gsub(/vectors\.vector\(/, "public.vector(")
  if ($0 !~ /^--/ && /vectors/) unhandled++
  print
}

END {
  printf "-- preprocess: dropped %d statements: %d DROP, %d ALTER TABLE IF EXISTS, %d OWNER TO, %d schema, %d extensions, %d comments, %d guards\n", drops + alters + owners + schemas + extensions + comments + guards, drops, alters, owners, schemas, extensions, comments, guards
  printf "-- preprocess: skipped %d pgvecto.rs index definitions (%d lines), rewrote %d asset_file, %d asset, %d person, %d system_metadata paths\n", indexes, index_lines, paths["asset_file"], paths["asset"], paths["person"], paths["system_metadata"]
  if (unhandled > 0) printf "-- preprocess: UNHANDLED %d line(s) still mention vectors\n", unhandled
}
AWK

  gunzip -c "$dump" |
    awk -v old_root="$old_media_root" -v new_root="$media_root" \
      -f "$work_dir/preprocess.awk" >"$sql"

  if ! grep -q '^-- preprocess:' "$sql"; then
    die "the preprocessor printed no summary; see $work_dir/preprocess.awk"
  fi
  grep '^-- preprocess:' "$sql"
  if grep -q '^-- preprocess: UNHANDLED' "$sql"; then
    die "the dump has lines this script does not understand, see $sql"
  fi

  note "wrote $sql ($(du -h "$sql" | cut -f1))"
}

load() {
  require_root "$1"
  resolve_pg

  local sql=$work_dir/immich-pg14.sql
  if [[ ! -s $sql ]]; then
    die "$sql is missing; run the preprocess stage first"
  fi

  confirm "Drop the '$db' database and load $(basename "$sql") into it?" ||
    die "aborted"

  local unit
  for unit in "${units[@]}"; do
    if systemctl is-active --quiet "$unit"; then
      systemctl stop "$unit"
      note "stopped $unit"
    fi
  done

  as_postgres -d postgres -c "DROP DATABASE IF EXISTS \"$db\" WITH (FORCE);"
  note "dropped $db"

  # postgresql-setup.service puts the database, the role that owns it and the
  # extensions immich wants back; there is nothing to redo by hand.
  systemctl restart postgresql-setup.service
  note "recreated $db through postgresql-setup.service"

  local found
  found=$(as_postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$db';")
  [[ $found == 1 ]] || die "postgresql-setup created no '$db' database"
  found=$(as_postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$db_user';")
  [[ $found == 1 ]] || die "the '$db_user' role does not exist"

  # Loading as the role that owns the database leaves every object owned by it,
  # which is why the dump's OWNER TO statements are not needed. psql reads it on
  # stdin because the file is root's alone, being a copy of the whole library.
  note "loading $(basename "$sql") as $db_user"
  sudo -u "$db_user" "$pg_bin/psql" -X -q -1 -v ON_ERROR_STOP=1 -d "$db" <"$sql"

  local media leftover
  media=$(db_scalar "SELECT value FROM system_metadata WHERE key = 'MediaLocation';")
  [[ $media == "$media_root" ]] ||
    die "MediaLocation is '$media', expected '$media_root'"

  leftover=$(db_scalar "SELECT
      (SELECT count(*) FROM asset_file WHERE path LIKE '$old_media_root%')
    + (SELECT count(*) FROM asset WHERE \"originalPath\" LIKE '$old_media_root%')
    + (SELECT count(*) FROM person WHERE \"thumbnailPath\" LIKE '$old_media_root%')
    + (SELECT count(*) FROM system_metadata WHERE value LIKE '$old_media_root%');")
  [[ $leftover == 0 ]] || die "$leftover row(s) still point at $old_media_root"

  note "loaded $(db_scalar 'SELECT count(*) FROM asset_file;') asset_file rows"
  note "next: sudo systemctl start immich-server, watch the migrations with"
  note "      journalctl -fu immich-server, then 'sudo $0 verify'"
}

verify() {
  require_root "$1"
  resolve_pg

  # Counts as of the dump. immich prunes sessions and grows the migration
  # tables as it starts, so neither is listed here.
  local -a expected=(
    "geodata_places:224210"
    "asset_ocr:31852"
    "asset_file:17808"
    "album_asset:13870"
    "asset:8975"
    "asset_exif:8974"
    "smart_search:8815"
    "face_search:5318"
    "asset_face:5318"
    "ocr_search:2961"
    "person:282"
    "memory_asset:265"
    "album:18"
    "system_metadata:8"
    "version_history:1"
    "\"user\":1"
  )

  local entry table want got failures=0
  note "row counts, as of the loaded dump:"
  for entry in "${expected[@]}"; do
    table=${entry%%:*}
    want=${entry#*:}
    got=$(db_scalar "SELECT count(*) FROM $table;")
    if [[ $got == "$want" ]]; then
      printf '  ok    %-18s %s\n' "$table" "$got"
    else
      printf '  DIFF  %-18s %s, the dump had %s\n' "$table" "$got" "$want"
      failures=$((failures + 1))
    fi
  done

  note "migrations and version:"
  db_table "SELECT count(*) AS kysely_migrations FROM kysely_migrations;"
  db_table 'SELECT version, "createdAt" FROM version_history ORDER BY "createdAt";'

  local indexes
  indexes=$(db_scalar "SELECT count(*) FROM pg_indexes
      WHERE indexname IN ('face_index', 'clip_index');")
  note "vector indexes: $indexes of 2"
  if [[ $indexes != 2 ]]; then
    db_table "SELECT indexname FROM pg_indexes
              WHERE indexname IN ('face_index', 'clip_index') ORDER BY indexname;"
    warn "immich builds the missing ones itself on start, for the extension it"
    warn "finds; 'journalctl -u immich-server' says 'Reindexing <index>' if it"
    warn "tried, so a count below 2 after a start is worth reading the log for"
  fi

  if ((failures > 0)); then
    warn "$failures of ${#expected[@]} counts differ; a count that changed after"
    warn "immich migrated is worth explaining rather than dismissing"
  fi

  if command -v curl >/dev/null; then
    if curl -fsS --max-time 5 http://127.0.0.1:2283/api/server/ping >/dev/null; then
      note "immich answers on http://127.0.0.1:2283"
    else
      warn "immich is not answering yet; check 'systemctl status immich-server'"
    fi
  fi
}

stage=${1:-all}
case $stage in
  shelter) shelter "$stage" ;;
  preprocess) preprocess "$stage" ;;
  load) load "$stage" ;;
  verify) verify "$stage" ;;
  all)
    shelter "$stage"
    preprocess "$stage"
    load "$stage"
    ;;
  help | -h | --help) usage ;;
  *)
    usage
    die "unknown stage: $stage"
    ;;
esac
