set allow-duplicate-recipes
set allow-duplicate-variables
import? 'rocks.just'

[private]
@default:
  just --list
  echo ""
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Generate a rock for the latest version of the upstream project
[arg("source_repo", help="Repository of the upstream project in 'org/repo' form")]
[group("maintenance")]
update source_repo:
  #!/usr/bin/env bash
  set -e
  latest_release="$(gh release list --repo {{source_repo}} --exclude-pre-releases --limit=1 --json tagName --jq '.[0].tagName')"
  echo "Latest release for {{source_repo}} is $latest_release"
  # Explicitly filter out prefixes for known rocks, so we can notice if a new rock has a different schema
  version="${latest_release}"
  version="${version#mimir-}"  # mimir
  version="${version#cmd/builder/v}"  # opentelemetry-collector
  version="${version#v}"  # Generic v- prefix
  # If the version already exists as a rock, exit here
  if [[ -d "$version" ]]; then echo "Folder $version already exists, nothing to do" && exit 0; fi
  # Create the folder for the new version and update the rockcraft.yaml
  cp -r "{{latest_version}}" "$version"
  latest_release="$latest_release" version="$version" yq -i \
    '.version = strenv(version) | .parts.{{rock_name}}["source-tag"] = strenv(latest_release)' \
    "./$version/rockcraft.yaml"
  # Automatically update build tools (go) from the upstream repository
  TMP_DIR="$(mktemp -d)"
  gh repo clone "{{source_repo}}" "$TMP_DIR/{{source_repo}}" -- --branch "$latest_release" --depth 1
  go_snap_version="$(grep -Po '^go \K(\S+)' "$TMP_DIR/{{source_repo}}/go.mod" | sed -E 's/([0-9]+\.[0-9]+).*/\1/')"
  go_snap_version="$go_snap_version" yq -i \
    '(.parts.{{rock_name}}.build-snaps[] | select(test("^go/"))) = "go/"+strenv(go_snap_version)+"/candidate"' \
    "./$version/rockcraft.yaml"
  ## Node dependency
  node_version=$(sed -E 's/^v?([0-9]+).*/\1/' "$TMP_DIR/{{source_repo}}/web/ui/.nvmrc")
  yq -i 'del(.parts.prometheus.build-snaps.[] | select(. == "node/*"))' "$version/rockcraft.yaml"
  ver="$node_version" yq -i '.parts.prometheus.build-snaps += "node/"+strenv(ver)+"/stable"' "$version/rockcraft.yaml"
  rm -rf "$TMP_DIR"
  echo "✓ Created rock for version $version"






