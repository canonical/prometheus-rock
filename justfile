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
  for folder in $(find . -maxdepth 1 -type d -regextype posix-extended -regex '\./[0-9]+\.[0-9]+' -printf '%f\n' | sort -V); do
    read -r version tag < <(just resolve-tag "$folder")
    if [[ -z "$version" ]]; then echo "→ no upstream patch found for $folder, skipping"; continue; fi
    current="$(yq -r '.version' "$folder/rockcraft.yaml")"
    if [[ "$current" == "$version" ]]; then echo "→ $folder already at $version"; continue; fi
    echo "Updating $folder: $current → $version (source-tag $tag)"
    just write-version "$folder" "$version" "$tag"
    just sync-extra "$folder" "$tag"
  done

# Onboard a new major.minor line (mirrors the blueprint, plus the Node build snap)
[group("maintenance")]
add-version version:
  #!/usr/bin/env bash
  set -e
  [[ -z "{{source_repo}}" ]] && { echo "× Set 'source_repo' in the local justfile"; exit 1; }
  requested="{{version}}"; requested="${requested#v}"
  major_minor="$(echo "$requested" | grep -oP '^\d+\.\d+')"
  [[ -z "$major_minor" ]] && { echo "× could not parse a major.minor from '{{version}}'"; exit 1; }
  [[ -d "$major_minor" ]] && { echo "→ $major_minor/ already exists, nothing to do"; exit 0; }
  read -r version tag < <(just resolve-tag "$major_minor")
  [[ -z "$version" ]] && { echo "× no upstream release found for {{source_repo}} on the $major_minor line"; exit 1; }
  template="{{latest_version}}"
  [[ -z "$template" ]] && { echo "× no existing X.Y folder to copy from"; exit 1; }
  echo "Seeding $major_minor/ from $template/ ..."
  cp -r "$template" "$major_minor"
  just write-version "$major_minor" "$version" "$tag"
  just sync-extra "$major_minor" "$tag"
  echo "✓ Created $major_minor/ at $version (source-tag $tag)"

# Refresh the Node build snap from the upstream .nvmrc for a single folder
[private]
sync-extra folder tag:
  #!/usr/bin/env bash
  set -e
  TMP_DIR="$(mktemp -d)"
  gh repo clone "{{source_repo}}" "$TMP_DIR/src" -- --branch "{{tag}}" --depth 1 2>/dev/null || true
  if [[ -f "$TMP_DIR/src/web/ui/.nvmrc" ]]; then
    node_version=$(sed -E 's/^v?([0-9]+).*/\1/' "$TMP_DIR/src/web/ui/.nvmrc")
    yq -i 'del(.parts.prometheus.build-snaps.[] | select(test("^node/")))' "{{folder}}/rockcraft.yaml"
    ver="$node_version" yq -i '.parts.prometheus.build-snaps += "node/"+strenv(ver)+"/stable"' "{{folder}}/rockcraft.yaml"
  fi
  rm -rf "$TMP_DIR"






