#!/usr/bin/env bash

# Check command implementation

# Note: Libraries are sourced by main script, no need to source here

# Check if release is needed
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Latest release SHA
# Returns:
#   0 if release needed, 1 otherwise
check_if_release_needed() {
  local repo=$1
  local latest_release_sha=$2

  # Check if the latest release tag is the HEAD of the main branches
  if [ "$latest_release_sha" == "$(gh api repos/"$repo"/git/ref/heads/main --jq '.object.sha')" ]; then
    echo "The latest release tag is the HEAD of the main branch, there is nothing to release"
    return 1
  fi
  return 0
}

# Process issue data and store in associative arrays
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Issue number
#   Plus name references to associative arrays
process_issue() {
  local repo=$1
  local issue=$2
  local -n processed_issues_ref=$3
  local -n issue_refs_ref=$4
  local -n parent_issues_ref=$5
  local -n child_issues_ref=$6
  local -n issue_labels_ref=$7
  local -n issue_status_ref=$8
  local -n issue_progress_ref=$9

  # Skip if we've already processed this issue
  if [ ! -z "${processed_issues_ref[$issue]}" ]; then
    # Just increment reference counter
    issue_refs_ref[$issue]=$((${issue_refs_ref[$issue]:-0} + 1))
    return
  fi

  processed_issues_ref[$issue]=1
  # Increment reference counter
  issue_refs_ref[$issue]=$((${issue_refs_ref[$issue]:-0} + 1))

  local parent=$(get_parent_issue_number "$repo" "$issue")
  if [ ! -z "$parent" ]; then
    # This is a child issue
    child_issues_ref[$parent]+="$issue "
    # Store parent's info if we haven't already
    if [ -z "${processed_issues_ref[$parent]}" ]; then
      processed_issues_ref[$parent]=1
      parent_issues_ref[$parent]=1
      update_issue_metadata "$repo" "$parent" issue_labels_ref issue_status_ref issue_progress_ref
    fi
  else
    # This is a parent or standalone issue
    parent_issues_ref[$issue]=1
  fi

  # Store issue info regardless of parent/child status
  update_issue_metadata "$repo" "$issue" issue_labels_ref issue_status_ref issue_progress_ref
}

# Update metadata for a single issue
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Issue number
#   Plus name references to associative arrays
update_issue_metadata() {
  local repo=$1
  local issue=$2
  local -n issue_labels_ref=$3
  local -n issue_status_ref=$4
  local -n issue_progress_ref=$5

  local all_labels=$(get_issue_labels "$repo" "$issue")
  issue_labels_ref[$issue]=$(echo "$all_labels" | sed -e 's/testing//g' -e 's/verified//g' | xargs)
  issue_status_ref[$issue]=$(is_issue_closed "$repo" "$issue" && echo "🟣" || echo "🟢")

  # Check progress status
  if echo "$all_labels" | grep -q "verified"; then
    issue_progress_ref[$issue]="✅"
  elif echo "$all_labels" | grep -q "testing"; then
    issue_progress_ref[$issue]="🔨"
  else
    issue_progress_ref[$issue]="🚧"
  fi
}

# Process all PRs and collect issue information
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Latest release tag
#   Plus name references to variables and arrays
# Returns:
#   0 on success, 1 on error
process_prs_and_collect_issues() {
  local repo=$1
  local latest_release=$2
  local -n unlinked_prs_ref=$3
  local -n translation_prs_ref=$4
  local -n processed_issues_ref=$5
  local -n issue_refs_ref=$6
  local -n parent_issues_ref=$7
  local -n child_issues_ref=$8
  local -n issue_labels_ref=$9
  local -n issue_status_ref=${10}
  local -n issue_progress_ref=${11}

  local prs=$(scan_for_prs "$repo" "$latest_release" main)
  if [ "$?" -ne 0 ]; then
    return 1
  fi

  for pr in $prs; do
    local linked=$(get_linked_issues "$repo" "$pr")
    if [ "$?" -ne 0 ]; then
      # Handle translation and unlinked PRs
      local has_translation=$(gh api repos/"$repo"/pulls/"$pr" --jq '[.labels[].name] | any(. == "translation")')
      if [ "$has_translation" = "true" ]; then
        translation_prs_ref="${translation_prs_ref}https://github.com/$repo/pull/$pr\n"
      else
        unlinked_prs_ref="${unlinked_prs_ref}https://github.com/$repo/pull/$pr\n"
      fi
    else
      for issue in $linked; do
        process_issue "NethServer/dev" "$issue" processed_issues_ref issue_refs_ref parent_issues_ref child_issues_ref issue_labels_ref issue_status_ref issue_progress_ref
      done
    fi
  done
  return 0
}

# Main execution for check command
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Latest release tag
#   $3 - Latest release SHA
# Returns:
#   0 on success, 1 on error
check_command_main() {
  local repo=$1
  local latest_release=$2
  local latest_release_sha=$3

  echo "Checking PRs and issues since $latest_release..."
  echo ""

  if [ -z "$latest_release" ]; then
    echo "No releases found."
    return 1
  fi

  if ! check_if_release_needed "$repo" "$latest_release_sha"; then
    return 1
  fi

  # Initialize local arrays
  local unlinked_prs=""
  local translation_prs=""
  declare -A parent_issues
  declare -A child_issues
  declare -A issue_labels
  declare -A issue_status
  declare -A issue_progress
  declare -A issue_refs
  declare -A processed_issues

  if ! process_prs_and_collect_issues "$repo" "$latest_release" unlinked_prs translation_prs processed_issues issue_refs parent_issues child_issues issue_labels issue_status issue_progress; then
    echo "Error processing PRs."
    return 1
  fi

  display_summary "$unlinked_prs" "$translation_prs" parent_issues child_issues issue_status issue_progress issue_refs issue_labels

  return 0
}
