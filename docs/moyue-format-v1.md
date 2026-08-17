# Moyue Package Format 1

`.moyue` is a ZIP archive with UTF-8 filenames and a required `meta.json` at
the archive root. Paths always use `/`, are relative to the archive root, and
must not contain `..`, absolute paths, drive letters, or symbolic links.

## Required `meta.json`

```json
{
  "format": "moyue",
  "format_version": 1,
  "display_name": "Example notebook",
  "marker": "exported",
  "single": false,
  "primary_document": "notes/index.md",
  "documents": [
    {
      "path": "notes/index.md",
      "kind": "markdown",
      "sha256": "lowercase-hex-sha256"
    }
  ],
  "resources": [
    {
      "path": "notes/images/cover.webp",
      "mime_type": "image/webp",
      "sha256": "lowercase-hex-sha256",
      "size": 12345
    }
  ]
}
```

## Rules

- `format` must be `moyue`.
- `format_version` is an integer. Version 1 readers reject unsupported major
  versions.
- `display_name` is the package name shown to users.
- `marker` is an application-defined stable tag. Moyue exports use `exported`.
- `single=true` means exactly one primary Markdown/HTML document is expected.
- `single=false` means the importer recursively indexes every Markdown/HTML
  entry and selects `primary_document` as the opening document.
- `primary_document` must point to one entry in `documents`.
- `documents[].kind` is `markdown` or `html`.
- `resources` contains images, stylesheets, scripts, and attachments. Relative
  links inside documents are resolved from the document's own directory.
- `sha256` is calculated over the uncompressed file bytes.
- Unknown fields must be ignored for forward compatibility.

## Import transaction

Moyue validates paths and metadata, stages `folders`, `documents`, and
`resources` rows in one SQLite transaction, writes package files beneath the
application root, and commits only after all writes succeed. A write failure
rolls back the database rows and removes the partial package directory.

## Storage mapping

```text
{app-root}/moyue_index.db
{app-root}/markdown/{folder-id}/...
{app-root}/html/{folder-id}/...
{app-root}/rss/{folder-id}/feed.xml
```

Only relative paths are stored in SQLite. Absolute application-root paths are
resolved by the platform storage adapter at runtime.
