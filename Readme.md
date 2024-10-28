# `gh ns8-release-module` - GitHub CLI Extension

This is a GitHub CLI (`gh`) extension that automates the creation and management of NethServer 8 modules releases.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Commands](#commands)
  - [Options](#options)
  - [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [Updating and Uninstalling](#updating-and-uninstalling)
- [Prerequisites](#prerequisites)

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
- `comment`: Adds a comment to the release issues. <!-- TODO -->

### Options

- `--repo <repo-name>`: The GitHub repository (e.g., owner/ns8-module).
- `--release-refs <commit-sha>`: The commit SHA to associate with the release.
- `--release-name <name>`: Specify the release name (must follow Semver format).
- `--testing`: Create a testing release.
- `--draft`: Create a draft release.
- `-h`, `--help`: Display the help message.

### Examples

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

Create a new draft release:

```bash
gh ns8-release-module create --repo NethServer/ns8-module --release-name 1.0.0 --draft
```

Check the status of the `main` branch:

```bash
gh ns8-release-module check --repo NethServer/ns8-module
```

## Troubleshooting

If you encounter any issues while using the `gh-ns8-release-module` extension, consider the following troubleshooting steps:

1. Ensure you have the latest version of the GitHub CLI (`gh`) installed.
2. Verify that you have the correct permissions to access the repository.
3. Check for any error messages and refer to the GitHub CLI documentation for more information.
4. If the issue persists, consider opening an issue on the [GitHub repository](https://github.com/NethServer/gh-ns8-release-module/issues).

## Updating and Uninstalling

### Updating

To update the `gh-ns8-release-module` extension to the latest version, run the following command:

```bash
gh extension upgrade NethServer/gh-ns8-release-module
```

### Uninstalling

To uninstall the `gh-ns8-release-module` extension, run the following command:

```bash
gh extension remove NethServer/gh-ns8-release-module
```

## Prerequisites

- Install [GitHub CLI](https://cli.github.com/): `gh`
