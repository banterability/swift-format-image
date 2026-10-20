# swift-format-image

A small image providing the `swift-format` binary for linting Swift in GitHub Actions, and an action that runs it. The full toolchain image is over a gigabyte and takes ~a minute to extract on a runner; this one is about 50 MiB and a job that uses it usually finishes in about a quarter of that time.

The Dockerfile builds `swift-format` from its release tarball with the official Swift image and copies the binary onto Google's distroless base. It uses the `:debug` variant of the base, which adds busybox, because GitHub Actions needs `tail`, `sh`, and `tar` in an image to run it as a job container.

## Using it

The action lints the paths you give it with `--recursive --strict`, running the image with no network and a read-only checkout. Pin it to a release tag; there's one per swift-format release, named after it, such as `604.0.0`. swift-format numbers its releases after the Swift release they ship with, so `604.x.y` is Swift 6.4. Releases are immutable, so a tag can't move once it's published.

```yaml
jobs:
  swift-format:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: banterability/swift-format-image@604.0.0
        with:
          paths: Sources Tests
```

Dependabot's `github-actions` ecosystem bumps that line when a new tag appears, so a consumer with Dependabot gets a pull request for each swift-format release. If the new release flags something, push the reformat to that branch.

The image itself is at `ghcr.io/banterability/swift-format`, tagged with the swift-format release, such as `604.0.0`, and can be used directly as a job `container:`. Pin by digest; the Build workflow's job summary prints the line to use. `actions/checkout` works without git in the image by downloading the commit as a tarball, so the checkout has no `.git` directory.

Each image carries a build provenance attestation:

```sh
gh attestation verify oci://ghcr.io/banterability/swift-format@sha256:… --owner banterability
```

## Moving to a new swift-format release

Run the Bump swift-format workflow with the release, such as `605.0.0`, or with the series, such as `605`, to take its newest release. The same script runs locally:

```sh
scripts/bump.sh 605
```

It resolves the `swift:6.5-trixie` image digest, picks the swift-format release, checksums its tarball, and rewrites the Dockerfile. It stops with a message if Docker Hub or swift-format hasn't released for that version yet. The workflow opens a pull request with the result; locally, commit it yourself.

Merging runs the Build workflow, which pushes the new image tag, writes the new digest into `action.yml`, and publishes release `605.0.0` from that commit. Consumers pick it up through Dependabot, or by moving their `uses:` line to the new tag.

Dependabot refreshes the digests of both `FROM` lines when their tags move, which picks up base image updates for the current swift-format release, and keeps the workflow actions current. Those rebuilds update `action.yml` on main but don't publish a release, so consumers pinned to a tag keep the image they have until the next swift-format release.
