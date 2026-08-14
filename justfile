set allow-duplicate-recipes
set allow-duplicate-variables
import? 'rocks.just'

source_repo := 'prometheus/prometheus'

[private]
@default:
  just --list
  echo ""
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Patch all existing major.minor folders to the newest upstream patch, refreshing Go and Node build snaps
[group("maintenance")]
update:
  #!/usr/bin/env bash
  set -e
  [[ -z "{{source_repo}}" ]] && { echo "× Set 'source_repo' in the local justfile"; exit 1; }
  # Reuse the blueprint update to bump version, source-tag and Go snap per folder
  just --justfile rocks.just update
  # Refresh the Node build snap from the upstream .nvmrc for each maintained line
  for folder in $(find . -maxdepth 1 -type d -regextype posix-extended -regex '\./[0-9]+\.[0-9]+' -printf '%f\n'); do
    tag="$(yq -r '.parts.{{rock_name}}["source-tag"]' "$folder/rockcraft.yaml")"
    TMP_DIR="$(mktemp -d)"
    gh repo clone "{{source_repo}}" "$TMP_DIR/src" -- --branch "$tag" --depth 1 2>/dev/null || true
    if [[ -f "$TMP_DIR/src/web/ui/.nvmrc" ]]; then
      node_version=$(sed -E 's/^v?([0-9]+).*/\1/' "$TMP_DIR/src/web/ui/.nvmrc")
      yq -i 'del(.parts.prometheus.build-snaps.[] | select(test("^node/")))' "$folder/rockcraft.yaml"
      ver="$node_version" yq -i '.parts.prometheus.build-snaps += "node/"+strenv(ver)+"/stable"' "$folder/rockcraft.yaml"
    fi
    rm -rf "$TMP_DIR"
  done






