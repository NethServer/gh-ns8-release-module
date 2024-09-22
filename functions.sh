#!/usr/bin/env bash

# Function to check if a string is a valid semver format using the official regex
function is_semver() {
  local semver_regex="^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$"
  if [[ $1 =~ $semver_regex ]]; then
    return 0
  else
    return 1
  fi
}


# Function to get the next testing release name
function next_testing_release() {
  # Get the lasest Gihub release tag
  latest_release=$(gh release list --repo $1 --limit 1 --json tagName --jq '.[0].tagName')

  # Check if the latest release is a valid semver format
  if ! is_semver $latest_release; then
    echo "Invalid semver format for the latest release: $latest_release"
    return 1
  fi

  # Get the commit sha for the latest release
  latest_release_sha=$(gh api repos/$1/git/refs/tags/$latest_release --jq '.object.sha')
  # #Check if the latest release is a prerelease
  is_prerelease=$(gh api repos/$1/releases/tags/$latest_release --jq '.prerelease')

  if [ "$is_prerelease" == "false" ]; then
    # The name of the release should be the same as the latest release with
    # patch version incremented by 1 and the semver prelease appended to it in the format "-testing.1"
    release_name=$(echo $latest_release | sed -E 's/(.*\.)([0-9]+)/echo "\1$((\2+1))"/ge')
    release_name="${release_name}-testing.1"
  else
    # The name of the release should be the same as the latest release with
    # semver prelease "-testing.<number>" incremented by 1
    release_name=$(echo $latest_release | sed -E 's/(.*-testing\.)([0-9]+)/echo "\1$((\2+1))"/ge')
  fi

  echo -n "$release_name"
}
