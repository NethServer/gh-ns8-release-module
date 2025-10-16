#!/usr/bin/env bash

# Semver validation and release name generation functions

# Function to check if a string is a valid semver format
# using the official regex
#
# Arguments:
#   $1 - Version string to validate
# Returns:
#   0 if valid semver, 1 otherwise
function is_semver() {
  local semver_regex="^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$"
  if [[ $1 =~ $semver_regex ]]; then
    return 0
  else
    return 1
  fi
}

# Function to get the next testing release name
#
# Arguments:
#   $1 - Repository name (owner/repo)
# Returns:
#   Prints the next testing release name to stdout
#   Returns 1 on error
function next_testing_release() {
  local repo=$1
  
  # Get the latest Github release tag
  local latest_release=$(gh release list --repo "$repo" --limit 1 --json tagName --jq '.[0].tagName')

  # Check if the latest release is a valid semver format
  if ! is_semver "$latest_release"; then
    echo "Invalid semver format for the latest release: $latest_release"
    return 1
  fi

  # Get the commit sha for the latest release
  local latest_release_sha=$(gh api repos/"$repo"/git/refs/tags/"$latest_release" --jq '.object.sha')

  # Check if the latest release tag is the HEAD of the main branches
  if [ "$latest_release_sha" == "$(gh api repos/"$repo"/git/ref/heads/main --jq '.object.sha')" ]; then
    echo "The latest release tag is the HEAD of the main branch."
    return 1
  fi

  # Check if the latest release is a prerelease
  local is_prerelease=$(gh release view "$latest_release" --repo "$repo" --json isPrerelease --jq '.isPrerelease')

  local release_name
  if [ "$is_prerelease" == "false" ]; then
    # The name of the release should be the same as the latest release with
    # patch version incremented by 1 and the semver prelease appended to it
    # in the format "-testing.1"
    release_name=$(echo "$latest_release" | sed -E 's/(.*\.)([0-9]+)/echo "\1$((\2+1))"/ge')
    release_name="${release_name}-testing.1"
  else
    # The name of the release should be the same as the latest release with
    # semver prelease "-testing.<number>" incremented by 1
    release_name=$(echo "$latest_release" | sed -E 's/(.*-testing\.)([0-9]+)/echo "\1$((\2+1))"/ge')
  fi

  echo -n "$release_name"
}

# Find the previous release based on the current release
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Current release tag name
# Returns:
#   Prints the previous release tag name to stdout
function find_previous_release() {
  local repo=$1
  local current_release=$2
  
  # Check if the current release is a pre-release
  local is_prerelease=$(gh release view "$current_release" --repo "$repo" --json isPrerelease --jq '.isPrerelease')

  # Get the list of releases sorted by creation date
  local release_list=$(gh release list --repo "$repo" --limit 1000 --json tagName,isPrerelease --order asc)

  local previous_release
  if [ "$is_prerelease" = "true" ]; then
    # Search for the previous release among all releases
    previous_release=$(echo "$release_list" | jq -r --arg current "$current_release" \
      'map(.tagName) | index($current) as $idx | if $idx and $idx > 0 then .[$idx - 1] else empty end')
  else
    # Search for the previous release among only stable releases
    previous_release=$(echo "$release_list" | jq -r --arg current "$current_release" \
      'map(select(.isPrerelease | not)) | map(.tagName) | index($current) as $idx | if $idx and $idx > 0 then .[$idx - 1] else empty end')
  fi

  if [ -n "$previous_release" ]; then
    echo -n "$previous_release"
  fi
}
