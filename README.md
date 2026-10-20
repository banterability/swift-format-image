# swift-format-image

A small image providing the `swift-format` binary for linting Swift in GitHub Actions. The full toolchain image is over a gigabyte and takes ~a minute to extract on a runner; this one is about 50 MiB and a job that uses it usually finishes in about a quarter of that time.

The Dockerfile builds `swift-format` from its release tarball with the official Swift image and copies the binary onto Google's distroless base. It uses the `:debug` variant of the base, which adds busybox, because GitHub Actions needs `tail`, `sh`, and `tar` in an image to run it as a job container.

## Using it

Images are at `ghcr.io/banterability/swift-format`, tagged with the Swift release and the swift-format release they match, such as `6.4`.

```yaml
jobs:
  swift-format:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/banterability/swift-format:6.4@sha256:…
    steps:
      - uses: actions/checkout@v7
      - run: swift-format lint --recursive --strict Sources Tests
```

Write `container:` in map form with an `image:` key. `actions/checkout` works without git in the image by downloading the commit as a tarball, so the checkout has no `.git` directory.

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

Merging runs the Build workflow, which pushes the new tags and prints the digest to pin. Then update the `image:` line in each consumer, in the same pull request that reformats the code for whatever the new release flags.

Dependabot refreshes the digests of both `FROM` lines when their tags move, which picks up base image updates for the current Swift release, and keeps the workflow actions current.
