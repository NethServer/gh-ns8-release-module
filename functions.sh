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

  # Check if the latest release tag is the HEAD of the main branches
  if [ "$latest_release_sha" == "$(gh api repos/$1/git/ref/heads/main --jq '.object.sha')" ]; then
    echo "The latest release tag is the HEAD of the main branch."
    return 1
  fi

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

function scan_for_prs() {
  local repo=$1
  local start_ref=$2
  local end_ref=$3
  local merged_prs=""
  local pr_numbers

# Initialize an empty array to hold unique PR numbers
  declare -a pr_numbers

  # Fetch the commits in the specified range
  commits=$(gh api repos/$repo/compare/$start_ref...$end_ref --jq '.commits[].sha')

  # Check if commits are found in the specified range
  if [ -z "$commits" ]; then
    echo "No commits found in the specified range."
    return 1
  fi

  for commit_sha in $commits; do
    prs=$(gh api repos/$repo/commits/$commit_sha/pulls --jq '.[].number')
    # If PRs are found, add them to the associative array
    if [ ! -z "$prs" ]; then
      for pr_number in $prs; do
        pr_numbers[$pr_number]=1
      done
    fi
  done

  # Display the list of unique PRs
  if [ ${#pr_numbers[@]} -eq 0 ]; then
    echo "No pull requests found for the commits in the specified range."
    return 2
  else
    for pr in "${!pr_numbers[@]}"; do
      echo "$pr"
    done
  fi
}

function get_linked_issues() {
  local repo=$1
  local pr_number=$2
  local linked_issues

  # Search for the patterns and extract the issue numbers:
  # NethServer/issues/1234
  # NethServer/dev#1234
  # https://github.com/NethServer/dev/issues/1234
  linked_issues=$(gh pr view $pr_number --repo $repo --json body --jq '.body' | \
  grep -oP '(?<=NethServer/issues/|NethServer/dev#|https:\/\/github.com\/NethServer\/dev\/issues\/)\d+')

  if [ -z "$linked_issues" ]; then
    return 1
  fi

  echo "$linked_issues"
}

function is_issue_closed() {
  local repo=$1
  local issue_number=$2
  local state

  state=$(gh issue view $issue_number --repo $repo --json state --jq '.state')

  if [ "$state" == "closed" ]; then
    return 0
  else
    return 1
  fi
}

function get_issue_labels() {
  local repo=$1
  local issue_number=$2
  local labels

  labels=$(gh issue view $issue_number --repo $repo --json labels --jq '.labels[].name')

  echo $labels
}
