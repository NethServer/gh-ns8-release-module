#!/usr/bin/env bash

# GitHub API interaction functions

# Scan for PRs in a commit range
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Start reference (commit SHA or tag)
#   $3 - End reference (commit SHA or tag)
# Returns:
#   Prints unique PR numbers to stdout
#   Returns 1 if no commits found, 2 if no PRs found
function scan_for_prs() {
  local repo=$1
  local start_ref=$2
  local end_ref=$3
  local merged_prs=""
  local pr_numbers

  # Initialize an empty array to hold unique PR numbers
  declare -a pr_numbers

  # Fetch the commits in the specified range
  local commits=$(gh api repos/"$repo"/compare/"$start_ref"..."$end_ref" --jq '.commits[].sha')

  # Check if commits are found in the specified range
  if [ -z "$commits" ]; then
    echo "No commits found in the specified range."
    return 1
  fi

  for commit_sha in $commits; do
    local prs=$(gh api repos/"$repo"/commits/"$commit_sha"/pulls --jq '.[].number')
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

# Get linked issues from a PR
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - PR number
#   $3 - Issues repository (owner/repo) to search for
# Returns:
#   Prints linked issue numbers to stdout
#   Returns 1 if no linked issues found
function get_linked_issues() {
  local repo=$1
  local pr_number=$2
  local issues_repo=$3
  local linked_issues

  # Extract owner and repo name from issues_repo
  local issues_owner="${issues_repo%/*}"
  local issues_name="${issues_repo#*/}"

  # Search for the patterns and extract the issue numbers:
  # owner/issues/1234
  # owner/repo#1234
  # https://github.com/owner/repo/issues/1234
  # Build dynamic regex pattern
  local pattern="(?<=${issues_owner}/issues/|${issues_repo}#|https:\/\/github\.com\/${issues_repo}\/issues\/)\d+"
  
  linked_issues=$(gh pr view "$pr_number" --repo "$repo" --json body --jq '.body' | \
  grep -oP "$pattern")

  if [ -z "$linked_issues" ]; then
    return 1
  fi

  echo "$linked_issues"
}

# Check if an issue is closed
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Issue number
# Returns:
#   0 if closed, 1 if open
function is_issue_closed() {
  local repo=$1
  local issue_number=$2
  local state

  state=$(gh issue view "$issue_number" --repo "$repo" --json state --jq '.state')

  if [ "$state" == "CLOSED" ]; then
    return 0
  else
    return 1
  fi
}

# Get labels for an issue
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Issue number
# Returns:
#   Prints space-separated label names to stdout
function get_issue_labels() {
  local repo=$1
  local issue_number=$2
  local labels

  labels=$(gh issue view "$issue_number" --repo "$repo" --json labels --jq '.labels[].name')

  echo "$labels"
}

# Get the parent issue number of a sub-issue
#
# Arguments:
#   $1 - Repository name (owner/repo)
#   $2 - Issue number
# Returns:
#   Prints parent issue number to stdout (empty if no parent)
function get_parent_issue_number() {
  local owner=$(echo "$1" | cut -d'/' -f1)
  local repo=$(echo "$1" | cut -d'/' -f2)
  local issueNumber=$2

  gh api graphql -f owner="$owner" -f repo="$repo" -F issueNumber="$issueNumber" -f query='
    query($owner: String!, $repo: String!, $issueNumber: Int!) {
      repository(owner: $owner, name: $repo) {
        issue(number: $issueNumber) {
          parent {
            number
          }
        }
      }
    }' --jq '.data.repository.issue.parent.number' -H 'GraphQL-Features: sub_issues'
}
