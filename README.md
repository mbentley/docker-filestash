# mbentley/filestash

docker image based on alpine:latest to run [Filestash](https://github.com/mickael-kerjean/filestash), built from source as a statically linked binary (the same way upstream builds its release binaries), running as a non-root user.

## Tags

* `latest` - multi-arch for `amd64` and `arm64`

## Usage

Example usage - see further below for additional information about the `PUID` and `PGID` environment variables.

```
docker run -it --rm \
  --name filestash \
  -p 8334:8334 \
  -v fs-data:/opt/filestash/data \
  mbentley/filestash
```

Once running, browse to `http://<host>:8334` to complete the initial setup.

## Required Volumes

### Data

Filestash stores all of its state (config, databases, plugins, certs, search index, logs, and cache) in `/opt/filestash/data`. Mount a volume there to persist it across container recreation.

A named volume (like `fs-data` above) is the easiest option. If you bind mount a host directory instead, the entrypoint will change the ownership of anything in it that doesn't match `PUID`/`PGID` (see [Running as a Non-Root User](#running-as-a-non-root-user)).

## Running as a Non-Root User

By default, the container starts as root only long enough for the entrypoint to create the `filestash` user and group and make sure `/opt/filestash/data` is owned by them, then drops privileges and runs Filestash as `filestash` (`1000:1000`).

To run as a different user id and group id, set `PUID` and `PGID`:

```
-e PUID="1001" \
-e PGID="1001"
```

Notes:

* `PUID` and `PGID` must be numeric and non-zero; the container will refuse to run Filestash as root.
* The `filestash` user and group are created at startup with the given ids. If the user already exists with different ids, it is recreated.
* If `PUID` is already used by another user in the image (e.g. `405`/`guest`), that user is removed so `filestash` can use the id.
* If `PGID` is already used by another group in the image (e.g. `100`/`users`), that group is used as the primary group instead of creating `filestash`.
* Only files that don't already have the correct ownership are changed, so restarts are fast and an unchanged volume is left alone.

### `--user` is not supported

The entrypoint needs to start as root to create the user and set ownership, so the container will exit with an error if it is started with `--user`. Use `PUID` and `PGID` instead.

## Optional Features

This image only includes the Filestash binary. These features are disabled because they rely on external tools that aren't installed:

* Video thumbnails and transcoding (`ffmpeg`/`ffprobe`)
* Full-text search indexing of PDFs (`pdftotext` from `poppler-utils`)

## Building

```
docker build --progress plain -t mbentley/filestash .
```

### Cache busting

Filestash doesn't publish versioned releases, so the image builds from `master` by default. Without a build arg, the clone layer is cached and won't pick up new commits. Pass the latest commit id on `master` as the `FILESTASH_REF` build arg so the clone and build only re-run when `master` changes:

```
FILESTASH_REF="$(git ls-remote https://github.com/mickael-kerjean/filestash refs/heads/master | cut -f1)"
docker build --progress plain --build-arg FILESTASH_REF="${FILESTASH_REF}" -t mbentley/filestash .
```

`FILESTASH_REF` can also be set to any branch or commit id to build that version.
