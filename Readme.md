# `gh ns8-release-module` - GitHub CLI Extension

This is a GitHub CLI (`gh`) extension that automates the creation and management of NethServer 8 modules releases.

## Features

- Validate Semantic Versioning (Semver) format for release names.
- Automatically generate the next testing release name.
- Create releases name and release notes.
- Check if a module is ready for release.

## Installation

To install this extension

```bash
gh extension install NethServer/gh-ns8-release-module
```

## Usage

```bash
gh ns8-release-module [create|check|comment] [options]
```

### Commands

- `create`: Creates a new release.
- `check`: Check the status of the `main` branch
- `comment`: Adds a comment to the release issues.

### Options

- `--repo <repo-name>`: The GitHub repository (e.g., owner/ns8-module).
- `--release-refs <commit-sha>`: The commit SHA to associate with the release.
- `--release-name <name>`: Specify the release name (must follow Semver format).
- `--testing`: Create a testing release.
- `--draft`: Create a draft release.
- `-h`, `--help`: Display the help message.

### Example

Create a new release for the repository `NethServer/ns8-module`:

```bash
gh ns8-release-module create --repo NethServer/ns8-module --release-name 1.0.0
```

Create a new testing named release:

```bash
gh ns8-release-module create --repo NethServer/ns8-module --testing --release-name 1.0.0-testing.1
```

Create a new testing release with automatic release name generation:

```bash
gh ns8-release-module create --repo NethServer/ns8-module --testing
```

## Prerequisites

- Install [GitHub CLI](https://cli.github.com/): `gh`
