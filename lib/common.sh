#!/usr/bin/env bash

# Common utility functions

# Validate repository format and access
#
# Arguments:
#   $1 - Repository name (owner/repo)
# Returns:
#   0 if valid, 1 if invalid
function validate_repository() {
  local repo=$1

  # Check if the repo is a valid github repo, using the gh api
  gh api repos/"$repo" 2>&1 > /dev/null
  if [ $? -ne 0 ]; then
    echo "Invalid repo: $repo"
    return 1
  fi

  # Check the repository has a valid NS8 module name in the format `owner/ns8-<module-name>`
  if ! echo "$repo" | grep -qE '^[^/]+/ns8-'; then
    echo "Invalid NS8 module name: $repo"
    return 1
  fi

  return 0
}

# Get repository from current directory or validate provided one
#
# Arguments:
#   $1 - Optional repository name (owner/repo)
# Returns:
#   Prints repository name to stdout
#   Returns 1 on error
function get_or_validate_repo() {
  local repo=$1

  # If the argument `--repo` is not provided, get the repo from the current directory
  if [ -z "$repo" ]; then
    repo=$(gh repo view --json owner,name --jq '.owner.login + "/" + .name')
    if [ -z "$repo" ]; then
      echo "Could not determine the repo. Please provide the repo name using the --repo flag"
      return 1
    fi
  fi

  if ! validate_repository "$repo"; then
    return 1
  fi

  echo -n "$repo"
}

# Get latest commit SHA or validate provided one
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Optional commit SHA
# Returns:
#   Prints commit SHA to stdout and target flag if needed
#   Returns 1 on error
function get_or_validate_commit() {
  local repo=$1
  local commit_sha=$2
  local target=""

  # If the argument `--release-refs` is not provided, get the latest commit of the default branch
  if [ -z "$commit_sha" ]; then
    commit_sha=$(gh api repos/"$repo"/commits --jq '.[0].sha')
    if [ -z "$commit_sha" ]; then
      echo "Could not determine the latest commit sha. Please provide the commit sha using the --release-refs flag"
      return 1
    fi
  else
    # Check if the commit sha is on the default branch
    local default_branch=$(gh repo view --repo "$repo" --json defaultBranchRef -q ".defaultBranchRef.name")
    local commit_branch=$(gh api repos/"$repo"/commits/"$commit_sha"/branches-where-head --jq '.[].name | select(. == $default_branch)' --arg default_branch "$default_branch")
    if [ -z "$commit_branch" ]; then
      echo "The commit sha is not on the default branch: $default_branch"
      return 1
    fi
    target="--target $commit_sha"
  fi

  echo -n "$commit_sha $target"
}
