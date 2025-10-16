#!/usr/bin/env bash

# Comment command implementation

# Note: Libraries are sourced by main script, no need to source here

# Create comments on linked issues for a release
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Release name
#   $3 - Issues repository (owner/repo)
# Returns:
#   0 on success, 1 on error
create_comment() {
  local repo=$1
  local release_name=$2
  local issues_repo=$3

  # Check if the current release is a pre-release
  local is_prerelease=$(gh release view "$release_name" --repo "$repo" --json isPrerelease --jq '.isPrerelease')

  # Get the latest release
  local previous_release=$(find_previous_release "$repo" "$release_name")

  # Get the list of merged PRs for the release
  local merged_prs=$(scan_for_prs "$repo" "$previous_release" "$release_name")

  # Collect all linked issues
  local linked_issues=""
  for pr in $merged_prs; do
    local pr_issues=$(get_linked_issues "$repo" "$pr" "$issues_repo")
    if [ -n "$pr_issues" ]; then
      linked_issues="${linked_issues}\n${pr_issues}"
    fi
  done

  # Process each unique issue
  for issue in $(echo -e "$linked_issues" | sort | uniq); do
    if ! is_issue_closed "$issues_repo" "$issue"; then
      local comment
      if [ "$is_prerelease" == "true" ]; then
        comment="Testing release \`$repo\` [$release_name](https://github.com/$repo/releases/tag/$release_name)"
      else
        comment="Release \`$repo\` [$release_name](https://github.com/$repo/releases/tag/$release_name)"
      fi
      gh issue comment "$issue" --repo "$issues_repo" --body "$comment"

      local parent_issue=$(get_parent_issue_number "$issues_repo" "$issue")
      if [ -n "$parent_issue" ]; then
        gh issue comment "$parent_issue" --repo "$issues_repo" --body "$comment"
      fi
    fi
  done
}

# Main execution for comment command
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Optional release name (if empty, uses latest)
#   $3 - Issues repository (owner/repo)
# Returns:
#   0 on success, 1 on error
comment_command_main() {
  local repo=$1
  local release_name=$2
  local issues_repo=$3

  # If the argument `--release-name` is not provided, get the name the latest release
  if [ -z "$release_name" ]; then
    release_name=$(gh release list --repo "$repo" --json tagName --limit 1 --order desc --jq '.[0].tagName')
  fi

  create_comment "$repo" "$release_name" "$issues_repo"
}
