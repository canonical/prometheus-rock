set quiet # Recipes are silent by default
set export # Just variables are exported to environment variables

rock_name := `echo ${PWD##*/} | sed 's/-rock//'`
latest_version := `find . -maxdepth 1 -type d | sort -V | tail -n1 | sed 's@./@@'`

[private]
default:
  just --list

# Push an OCI image to a local registry
[private]
push-to-registry version:
  echo "Pushing $rock_name $version to local registry"
  rockcraft.skopeo --insecure-policy copy --dest-tls-verify=false \
    "oci-archive:${version}/${rock_name}_${version}_amd64.rock" \
    "docker://localhost:32000/${rock_name}-dev:${version}"

# Pack a rock of a specific version
pack version:
  cd "$version" && rockcraft pack

# `rockcraft clean` for a specific version
clean version:
  cd "$version" && rockcraft clean

# Run a rock and open a shell into it with `kgoss`
run version=latest_version: (push-to-registry version)
  kgoss edit -i localhost:32000/${rock_name}-dev:${version}

# Test the rock with `kgoss`
test version=latest_version: (push-to-registry version)
  GOSS_OPTS="--retry-timeout 60s" kgoss run -i localhost:32000/${rock_name}-dev:${version}
