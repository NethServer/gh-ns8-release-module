#!/usr/bin/env bash

# Create command implementation

# Note: Libraries are sourced by main script, no need to source here

# Main execution for create command
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Release name
#   $3 - Testing flag (1 or 0)
#   $4 - Draft argument (--draft or empty)
#   $5 - Target argument (--target <sha> or empty)
#   $6 - With linked issues flag (1 or 0)
# Returns:
#   0 on success, 1 on error
create_command_main() {
  local repo=$1
  local release_name=$2
  local testing_arg=$3
  local draft_arg=$4
  local target=$5
  local with_linked_issues=$6

  local prerelease=""
  local previous_release=""

  if [[ "$testing_arg" == 1 || "$release_name" =~ - ]]; then
    prerelease="--prerelease"
    # Get the name the latest release
    previous_release=$(gh release list --repo "$repo" --json tagName --limit 1 --order desc --jq '.[0].tagName')
    if [ -z "$release_name" ]; then
      release_name=$(next_testing_release "$repo")
      local status=$?
      if [ "$status" -eq 1 ]; then
        echo "$release_name"
        exit 1
      fi
    fi
  else
    # Get the name the latest release that is not a prerelease
    previous_release=$(gh release list --repo "$repo" --exclude-pre-releases --json tagName --limit 1 --order desc --jq '.[0].tagName')
  fi

  # Create release notes with linked issues
  if [ -n "$previous_release" ]; then
    # Generate release notes with linked issues
    {
      # Only include linked issues if flag is set
      if [ "$with_linked_issues" == 1 ]; then
        # Try to get merged PRs, suppress stderr to avoid error messages
        local merged_prs
        merged_prs=$(scan_for_prs "$repo" "$previous_release" "main" 2>/dev/null)
        local scan_status=$?

        # Only process PRs if scan was successful (returns 0)
        if [ "$scan_status" -eq 0 ] && [ -n "$merged_prs" ]; then
          # Extract linked issues from PRs
          local all_issues=""
          for pr in $merged_prs; do
            local linked_issues=$(get_linked_issues "$repo" "$pr")
            if [ -n "$linked_issues" ]; then
              all_issues="${all_issues}${linked_issues} "
            fi
          done

          # Format and output unique issues
          if [ -n "$all_issues" ]; then
            echo "## Linked Issues"
            for issue in $(echo "$all_issues" | tr ' ' '\n' | sort -u); do
              # Get issue title
              local issue_title=$(gh api repos/NethServer/dev/issues/"$issue" --jq '.title' 2>/dev/null)
              echo "- [NethServer/dev#${issue}](https://github.com/NethServer/dev/issues/${issue}): $issue_title"
            done
          fi
        fi
      fi
    } | gh release create $draft_arg $target $prerelease --repo "$repo" --title "$release_name" --generate-notes --notes-file - "$release_name"
  else
    # No previous release found, use standard generate-notes
    gh release create $draft_arg $target $prerelease --repo "$repo" --title "$release_name" --generate-notes "$release_name"
  fi
}
