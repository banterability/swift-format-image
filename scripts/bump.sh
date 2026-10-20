#!/bin/sh
# Rewrites the Dockerfile for a Swift release: the swift build image's digest,
# the matching swift-format release, and that release's tarball checksum.
#
#   scripts/bump.sh 6.5            # newest swift-format 605.x.y release
#   scripts/bump.sh 6.5 605.0.0    # a specific release
#
# Needs curl, jq, and shasum. Edits the Dockerfile in place and leaves the
# commit to you, or to the Bump Swift workflow.
set -eu

swift_version=${1:?usage: $0 <swift version, e.g. 6.5> [swift-format version]}
if ! printf '%s' "$swift_version" | grep -Eq '^[0-9]+\.[0-9]+$'; then
  echo "expected a major.minor Swift version, got '$swift_version'" >&2
  exit 1
fi
cd "$(dirname "$0")/.."

# Docker's official image. The index digest covers every platform, which is
# the form `docker build` resolves for the current one.
tag="$swift_version-trixie"
token=$(curl -fsS 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/swift:pull' | jq -r .token)
if ! headers=$(curl -fsSI -H "Authorization: Bearer $token" \
  -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json' \
  "https://registry-1.docker.io/v2/library/swift/manifests/$tag"); then
  echo "no swift:$tag image on Docker Hub yet" >&2
  exit 1
fi
image_digest=$(printf '%s' "$headers" | tr -d '\r' | awk 'tolower($1) == "docker-content-digest:" { print $2 }')

# swift-format numbers its releases after the Swift release they ship with:
# 604.x.y for Swift 6.4.
series=$(( ${swift_version%%.*} * 100 + ${swift_version#*.} ))
if [ $# -ge 2 ]; then
  format_version=$2
else
  format_version=$(curl -fsS 'https://api.github.com/repos/swiftlang/swift-format/releases?per_page=100' \
    | jq -r '.[] | select(.prerelease | not) | .tag_name' \
    | grep -E "^$series\.[0-9]+\.[0-9]+$" | sort -V | tail -1)
  if [ -z "$format_version" ]; then
    echo "no swift-format $series.x.y release yet; see https://github.com/swiftlang/swift-format/releases" >&2
    exit 1
  fi
fi

tarball="https://github.com/swiftlang/swift-format/archive/$format_version.tar.gz"
if ! tarball_sha256=$(curl -fsSL "$tarball" | shasum -a 256 | cut -d ' ' -f 1); then
  echo "couldn't download $tarball" >&2
  exit 1
fi

sed -E \
  -e "s|^FROM swift:[^@]+@sha256:[0-9a-f]+|FROM swift:$tag@$image_digest|" \
  -e "s|^ARG VERSION=.*|ARG VERSION=$format_version|" \
  -e "s|^ADD --checksum=sha256:[0-9a-f]+|ADD --checksum=sha256:$tarball_sha256|" \
  Dockerfile > Dockerfile.bump
mv Dockerfile.bump Dockerfile

echo "swift:$tag@$image_digest"
echo "swift-format $format_version, tarball sha256 $tarball_sha256"
git --no-pager diff --stat -- Dockerfile
