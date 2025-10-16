#!/usr/bin/env bash

# Display and formatting functions

# Display parent issues with their children
#
# Arguments:
#   All arguments passed are associative array references
#   Uses global-style variables for display formatting
#   $7 - Issues repository (owner/repo)
function display_parent_issues() {
  local -n parent_issues_ref=$1
  local -n child_issues_ref=$2
  local -n issue_status_ref=$3
  local -n issue_progress_ref=$4
  local -n issue_refs_ref=$5
  local -n issue_labels_ref=$6
  local issues_repo=$7

  for parent in "${!parent_issues_ref[@]}"; do
    # Skip if this is actually a child issue
    if [ ! -z "$(echo "${child_issues_ref[@]}" | grep -w "$parent")" ]; then
      continue
    fi

    local ref_display="${issue_refs_ref[$parent]:-0}"
    printf "%-6s %s %-45s (%s) %s\n" "${issue_status_ref[$parent]}" "${issue_progress_ref[$parent]}" "https://github.com/$issues_repo/issues/$parent" "$ref_display" "${issue_labels_ref[$parent]}"

    if [ ! -z "${child_issues_ref[$parent]}" ]; then
      for child in ${child_issues_ref[$parent]}; do
        local child_ref_display="${issue_refs_ref[$child]:-0}"
        printf "%-2s%-2s %s %-45s (%s) %s\n" "└─" "${issue_status_ref[$child]}" "${issue_progress_ref[$child]}" "https://github.com/$issues_repo/issues/$child" "$child_ref_display" "${issue_labels_ref[$child]}"
      done
    fi
  done
}

# Display standalone issues (no parent or children)
#
# Arguments:
#   All arguments passed are associative array references
#   $7 - Issues repository (owner/repo)
function display_standalone_issues() {
  local -n parent_issues_ref=$1
  local -n child_issues_ref=$2
  local -n issue_labels_ref=$3
  local -n issue_status_ref=$4
  local -n issue_progress_ref=$5
  local -n issue_refs_ref=$6
  local issues_repo=$7

  for issue in "${!issue_labels_ref[@]}"; do
    # Skip if this is a parent or child issue
    if [ ! -z "${child_issues_ref[$issue]}" ] || [ ! -z "$(echo "${child_issues_ref[@]}" | grep -w "$issue")" ]; then
      continue
    fi
    if [ -z "${parent_issues_ref[$issue]}" ]; then
      local ref_display="${issue_refs_ref[$issue]:-0}"
      printf "%-6s %s %-45s (%s) %s\n" "${issue_status_ref[$issue]}" "${issue_progress_ref[$issue]}" "https://github.com/$issues_repo/issues/$issue" "$ref_display" "${issue_labels_ref[$issue]}"
    fi
  done
}

# Display summary information
#
# Arguments:
#   $1 - Unlinked PRs string
#   $2 - Translation PRs string
#   Plus associative array references for issue data
#   $9 - Issues repository (owner/repo)
function display_summary() {
  local unlinked_prs=$1
  local translation_prs=$2
  local -n parent_issues_ref=$3
  local -n child_issues_ref=$4
  local -n issue_status_ref=$5
  local -n issue_progress_ref=$6
  local -n issue_refs_ref=$7
  local -n issue_labels_ref=$8
  local issues_repo=$9

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
  display_parent_issues parent_issues_ref child_issues_ref issue_status_ref issue_progress_ref issue_refs_ref issue_labels_ref "$issues_repo"

  # Display standalone issues
  display_standalone_issues parent_issues_ref child_issues_ref issue_labels_ref issue_status_ref issue_progress_ref issue_refs_ref "$issues_repo"

  # Check for any issues not in verified status
  local all_verified=true
  # First check all child issues are verified
  for parent in "${!child_issues_ref[@]}"; do
    for child in ${child_issues_ref[$parent]}; do
      if [[ "${issue_progress_ref[$child]}" != "✅" ]]; then
        all_verified=false
        break 2
      fi
    done
  done

  # Then check parent issues without child issues
  for issue in "${!issue_progress_ref[@]}"; do
    # Skip parent issues with children as we'll check children separately
    if [ ! -z "${child_issues_ref[$issue]}" ]; then
      continue
    fi
    if [[ "${issue_progress_ref[$issue]}" != "✅" ]]; then
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
