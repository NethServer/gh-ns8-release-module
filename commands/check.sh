#!/usr/bin/env bash

# Check command implementation

# Note: Libraries are sourced by main script, no need to source here
# Note: Uses module-scoped variables instead of parameters for simplicity

# Module-scoped variables (populated by check_command_main)
unlinked_prs=""
translation_prs=""
declare -A parent_issues
declare -A child_issues
declare -A issue_labels
declare -A issue_status
declare -A issue_progress
declare -A issue_refs
declare -A processed_issues

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
#   $3 - Issues repository (owner/repo)
process_issue() {
  local repo=$1
  local issue=$2
  local issues_repo=$3

  # Skip if we've already processed this issue
  if [ ! -z "${processed_issues[$issue]}" ]; then
    # Just increment reference counter
    issue_refs[$issue]=$((${issue_refs[$issue]:-0} + 1))
    return
  fi

  processed_issues[$issue]=1
  # Increment reference counter
  issue_refs[$issue]=$((${issue_refs[$issue]:-0} + 1))

  local parent=$(get_parent_issue_number "$issues_repo" "$issue")
  if [ ! -z "$parent" ]; then
    # This is a child issue
    child_issues[$parent]+="$issue "
    # Store parent's info if we haven't already
    if [ -z "${processed_issues[$parent]}" ]; then
      processed_issues[$parent]=1
      parent_issues[$parent]=1
      update_issue_metadata "$issues_repo" "$parent"
    fi
  else
    # This is a parent or standalone issue
    parent_issues[$issue]=1
  fi

  # Store issue info regardless of parent/child status
  update_issue_metadata "$issues_repo" "$issue"
}

# Update metadata for a single issue
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Issue number
update_issue_metadata() {
  local repo=$1
  local issue=$2

  local all_labels=$(get_issue_labels "$repo" "$issue")
  issue_labels[$issue]=$(echo "$all_labels" | sed -e 's/testing//g' -e 's/verified//g' | xargs)
  issue_status[$issue]=$(is_issue_closed "$repo" "$issue" && echo "🟣" || echo "🟢")

  # Check progress status
  if echo "$all_labels" | grep -q "verified"; then
    issue_progress[$issue]="✅"
  elif echo "$all_labels" | grep -q "testing"; then
    issue_progress[$issue]="🔨"
  else
    issue_progress[$issue]="🚧"
  fi
}

# Process all PRs and collect issue information
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Latest release tag
#   $3 - Issues repository (owner/repo)
# Returns:
#   0 on success, 1 on error
process_prs_and_collect_issues() {
  local repo=$1
  local latest_release=$2
  local issues_repo=$3

  local prs=$(scan_for_prs "$repo" "$latest_release" main)
  if [ "$?" -ne 0 ]; then
    return 1
  fi

  for pr in $prs; do
    local linked=$(get_linked_issues "$repo" "$pr" "$issues_repo")
    if [ "$?" -ne 0 ]; then
      # Handle translation and unlinked PRs
      local has_translation=$(gh api repos/"$repo"/pulls/"$pr" --jq '[.labels[].name] | any(. == "translation")')
      if [ "$has_translation" = "true" ]; then
        translation_prs="${translation_prs}https://github.com/$repo/pull/$pr\n"
      else
        unlinked_prs="${unlinked_prs}https://github.com/$repo/pull/$pr\n"
      fi
    else
      for issue in $linked; do
        process_issue "$repo" "$issue" "$issues_repo"
      done
    fi
  done
  return 0
}

# Display summary information
display_check_summary() {
  local issues_repo=$1
  
  echo "Summary:"
  echo "--------"
  if [ ! -z "$unlinked_prs" ]; then
    echo -e "\033[33mPRs without linked issues:\033[0m"
    echo -e "$unlinked_prs"
  fi

  if [ ! -z "$translation_prs" ]; then
    echo -e "\033[36mTranslation PRs:\033[0m"
    echo -e "$translation_prs"
  fi

  echo -e "\033[1mIssues:\033[0m"

  # First, display parent issues with their children
  display_parent_issues_check "$issues_repo"

  # Display standalone issues
  display_standalone_issues_check "$issues_repo"

  # Check for any issues not in verified status
  local all_verified=true
  # First check all child issues are verified
  for parent in "${!child_issues[@]}"; do
    for child in ${child_issues[$parent]}; do
      if [[ "${issue_progress[$child]}" != "✅" ]]; then
        all_verified=false
        break 2
      fi
    done
  done

  # Then check parent issues without child issues
  for issue in "${!issue_progress[@]}"; do
    # Skip parent issues with children as we'll check children separately
    if [ ! -z "${child_issues[$issue]}" ]; then
      continue
    fi
    if [[ "${issue_progress[$issue]}" != "✅" ]]; then
      all_verified=false
      break
    fi
  done

  if [ -z "$unlinked_prs" ] && $all_verified; then
    echo
    echo -e "\033[32m✅ All checks passed! Ready to release.\033[0m"
  fi

  # Print legend
  echo "---"
  echo "Issue status:    🟢 Open    🟣 Closed"
  echo "Progress status: 🚧 In Progress    🔨 Testing    ✅ Verified"
}

# Display parent issues with their children
display_parent_issues_check() {
  local issues_repo=$1
  
  for parent in "${!parent_issues[@]}"; do
    # Skip if this is actually a child issue
    if [ ! -z "$(echo "${child_issues[@]}" | grep -w "$parent")" ]; then
      continue
    fi

    local ref_display="${issue_refs[$parent]:-0}"
    printf "%-6s %s %-45s (%s) %s\n" "${issue_status[$parent]}" "${issue_progress[$parent]}" "https://github.com/$issues_repo/issues/$parent" "$ref_display" "${issue_labels[$parent]}"

    if [ ! -z "${child_issues[$parent]}" ]; then
      for child in ${child_issues[$parent]}; do
        local child_ref_display="${issue_refs[$child]:-0}"
        printf "%-2s%-2s %s %-45s (%s) %s\n" "└─" "${issue_status[$child]}" "${issue_progress[$child]}" "https://github.com/$issues_repo/issues/$child" "$child_ref_display" "${issue_labels[$child]}"
      done
    fi
  done
}

# Display standalone issues (no parent or children)
display_standalone_issues_check() {
  local issues_repo=$1
  
  for issue in "${!issue_labels[@]}"; do
    # Skip if this is a parent or child issue
    if [ ! -z "${child_issues[$issue]}" ] || [ ! -z "$(echo "${child_issues[@]}" | grep -w "$issue")" ]; then
      continue
    fi
    if [ -z "${parent_issues[$issue]}" ]; then
      local ref_display="${issue_refs[$issue]:-0}"
      printf "%-6s %s %-45s (%s) %s\n" "${issue_status[$issue]}" "${issue_progress[$issue]}" "https://github.com/$issues_repo/issues/$issue" "$ref_display" "${issue_labels[$issue]}"
    fi
  done
}

# Main execution for check command
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Latest release tag
#   $3 - Latest release SHA
#   $4 - Issues repository (owner/repo)
# Returns:
#   0 on success, 1 on error
check_command_main() {
  local repo=$1
  local latest_release=$2
  local latest_release_sha=$3
  local issues_repo=$4

  echo "Checking PRs and issues since $latest_release..."
  echo ""

  if [ -z "$latest_release" ]; then
    echo "No releases found."
    return 1
  fi

  if ! check_if_release_needed "$repo" "$latest_release_sha"; then
    return 1
  fi

  # Reset module-scoped variables
  unlinked_prs=""
  translation_prs=""
  parent_issues=()
  child_issues=()
  issue_labels=()
  issue_status=()
  issue_progress=()
  issue_refs=()
  processed_issues=()

  if ! process_prs_and_collect_issues "$repo" "$latest_release" "$issues_repo"; then
    echo "Error processing PRs."
    return 1
  fi

  display_check_summary "$issues_repo"

  return 0
}
