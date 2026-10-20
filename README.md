# swift-format-image

A small image providing the `swift-format` binary for linting Swift in GitHub Actions, and an action that runs it. The full toolchain image is over a gigabyte and takes ~a minute to extract on a runner; this one is about 50 MiB and a job that uses it usually finishes in about a quarter of that time.

The Dockerfile builds `swift-format` from its release tarball with the official Swift image and copies the binary onto Google's distroless base. It uses the `:debug` variant of the base, which adds busybox, because GitHub Actions needs `tail`, `sh`, and `tar` in an image to run it as a job container.

## Using it

The action lints the paths you give it with `--recursive --strict`, running the image with no network and a read-only checkout. Pin it to a release tag's commit; there's one per Swift minor, such as `v6.4`, and each points at an image built from that release's swift-format.

```yaml
jobs:
  swift-format:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: banterability/swift-format-image@<sha> # v6.4
        with:
          paths: Sources Tests
```

Dependabot's `github-actions` ecosystem bumps that line when a new tag appears, so a consumer with Dependabot gets a pull request for each Swift release. If the new release flags something, push the reformat to that branch.

The image itself is at `ghcr.io/banterability/swift-format`, tagged with the Swift release and the swift-format release it matches, such as `6.4` and `604.0.0`, and can be used directly as a job `container:`. Pin by digest; the Build workflow's job summary prints the line to use. `actions/checkout` works without git in the image by downloading the commit as a tarball, so the checkout has no `.git` directory.

Each image carries a build provenance attestation:

```sh
gh attestation verify oci://ghcr.io/banterability/swift-format@sha256:… --owner banterability
```

## Moving to a new Swift release

Run the Bump Swift workflow with the Swift version, such as `6.5`, or run the same script locally:

```sh
scripts/bump.sh 6.5
```

It resolves the `swift:6.5-trixie` image digest, picks the newest `605.x.y` swift-format release, checksums its tarball, and rewrites the Dockerfile. It stops with a message if Docker Hub or swift-format hasn't released for that version yet. The workflow opens a pull request with the result; locally, commit it yourself.

Merging runs the Build workflow, which pushes the new image tags, writes the new digest into `action.yml`, and tags that commit `v6.5`. Consumers pick it up through Dependabot, or by moving their `uses:` line to the tag's commit.

Dependabot refreshes the digests of both `FROM` lines when their tags move, which picks up base image updates for the current Swift release, and keeps the workflow actions current. Those rebuilds update `action.yml` on main but don't move a release tag, so consumers pinned to a tag keep the image they have until the next Swift release.
