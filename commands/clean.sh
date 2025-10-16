#!/usr/bin/env bash

# Clean command implementation

# Note: Libraries are sourced by main script, no need to source here

# Function to clean pre-releases between stable releases
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Stable release tag
# Returns:
#   0 on success
function clean_releases() {
  local repo=$1
  local stable_release=$2
  local pre_releases=()

  # Get the previous stable release
  local previous_release=$(find_previous_release "$repo" "$stable_release")

  local pre_releases=$(gh release list --repo "$repo" --limit 1000 --json isPrerelease,tagName,createdAt | \
    jq --arg start_tag "$previous_release" --arg end_tag "$stable_release" -r '
      def between($start; $end):
        map(select(.tagName == $start).createdAt) as $start_date |
        map(select(.tagName == $end).createdAt) as $end_date |
        map(select(.isPrerelease and .createdAt > $start_date[0] and .createdAt <= $end_date[0])) |
        sort_by(.createdAt) |
        map(.tagName) |
        join(" ");
      between($start_tag; $end_tag)
  ')

  if [ -n "$pre_releases" ]; then
    for pre_release in $pre_releases; do
      gh release delete "$pre_release" --repo "$repo" --yes
    done
  fi
}

# Main execution for clean command
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Optional stable release name (if empty, uses latest stable)
# Returns:
#   0 on success, 1 on error
clean_command_main() {
  local repo=$1
  local release_name=$2

  # If no stable release is provided, get the latest stable release
  if [ -z "$release_name" ]; then
    release_name=$(gh release list --repo "$repo" --exclude-pre-releases --json tagName --limit 1 --order desc --jq '.[0].tagName')
    if [ -z "$release_name" ]; then
      echo "No stable release found in the repository."
      return 1
    fi
  fi

  clean_releases "$repo" "$release_name"
}
