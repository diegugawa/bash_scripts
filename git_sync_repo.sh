#!/bin/bash

# Shell script functions to help automate git repository state replication to a local checked out workspace.

# The location to the git repository to clone.
REPO="git@github.com:YOUR_ACCOUNT/GITPROJECT.git"

# The folder where we want to have the checkout of the git repository.
WORKSPACE="/tmp/meow";

# The ssh key to use for accessing the remote git repository.
KEY="${HOME}/.ssh/YOUR.key"


git_clone_repo() {
  local parent_folder="`dirname "${WORKSPACE}"`";

  if [ -d "${WORKSPACE}" ]; then
    echo "INFO: Workspace folder already exists: '${WORKSPACE}'. Not cloning repo at this time.";
    return 0;
  fi;

  echo "INFO: Cloning git repository ${REPO} into '${WORKSPACE}'";

  # add our key to the ssh config.
  # cd to the parent folder for checkout
  # git clone the repo.
  ssh-agent sh -c "ssh-add ${KEY}; cd "${parent_folder}"; git clone ${REPO}";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git clone.";
    return 1;
  fi;
}


git_pull_repo() {
  if [ ! -e "${WORKSPACE}" ]; then
     echo "ERROR: Workspace folder does not exist: '${WORKSPACE}'. Please clone the repo first.";
    return 1;
  fi;

  echo "INFO: Pulling git repository ${REPO} into '${WORKSPACE}'";
  ssh-agent sh -c "ssh-add ${KEY}; cd "${WORKSPACE}"; git pull";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git pull.";
    return 1;
  fi;
}

# Tests for local modifications, showing you a nice report of how many things are modified.
# This just shows you how to look for different kinds of modifications.
git_check_status() {
  if [ ! -e "${WORKSPACE}" ]; then
     echo "ERROR: Workspace folder does not exist: '${WORKSPACE}'. Please clone the repo first.";
    return 1;
  fi;


  # test for files that were added that require staging
  local files_new_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | grep "^??" | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_new_count} -gt 0 ]; then
    echo "INFO: found ${files_new_count} new files that require staging.";
  fi;


  # test for files that were modified that require staging
  local files_modified_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | grep "^ M" | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_modified_count} -gt 0 ]; then
    echo "INFO: found ${files_modified_count} modified files that require staging.";
  fi;

  # test for files that were deleted that require staging
  local files_deleted_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | grep "^ D" | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_deleted_count} -gt 0 ]; then
    echo "INFO: found ${files_deleted_count} deleted files that require staging.";
  fi;

  # test for staged added files
  local files_staged_added_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | grep "^A " | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_staged_added_count} -gt 0 ]; then
    echo "INFO: found ${files_staged_added_count} staged files added.";
  fi;

  # test for staged modified files
  local files_staged_modified_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | grep "^M " | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_staged_modified_count} -gt 0 ]; then
    echo "INFO: found ${files_staged_modified_count} staged files modified.";
  fi;

  # test for staged deleted files
  local files_staged_deleted_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | grep "^D " | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_staged_deleted_count} -gt 0 ]; then
    echo "INFO: found ${files_staged_deleted_count} staged files deleted.";
  fi;

  # test for staged renamed files
  local files_staged_renamed_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | grep "^R " | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_staged_renamed_count} -gt 0 ]; then
    echo "INFO: found ${files_staged_renamed_count} staged files renamed.";
  fi;
}

# This will stage all local files in the repo, without any consideration if they should be staged.
# Newly added files, modified files, deleted files.
git_stage_repo() {
  local files_modified_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | grep "^[ ?][MD?]" | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_modified_count} -eq 0 ]; then
    echo "INFO: No local modified files for workspace '${WORKSPACE}'. Nothing to stage here.";
    return 0;
  fi;

  echo "INFO: Staging ${files_modified_count} locally modified files for workspace '${WORKSPACE}'.";
  git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" add .
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git stage on workspace '${WORKSPACE}'.";
    return 1;
  fi;
}

# Invoking this will cause the staged contents of the git workspace to be committed.
# params
# 1: message (default the current time stamp)
git_commit_repo() {
  # commit will only process the staged files.
  # if there are no staged files, then we don't do anything here.
  local files_staged_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | grep "^[AMDR] " | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_staged_count} -eq 0 ]; then
    echo "INFO: No staged files for workspace '${WORKSPACE}'. Nothing to commit here.";
    return 0;
  fi;

  local message="${1}";
  if [ -z "${message}" ]; then
    message="Auto commit for `date +"%Y-%m-%d %H:%M:%S"` from `whoami`@`hostname`";
  fi;

  echo "INFO: Invoking git commit in workspace ${WORKSPACE}";
  git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" commit -m "${message}";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git commit on workspace '${WORKSPACE}'.";
    return 1;
  fi;
}

git_push_repo() {
  local files_modified_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_modified_count} -gt 0 ]; then
    echo "WARN: Workspace contains locally modified or staged files: '${WORKSPACE}'.";
  fi;

  echo "INFO: Invoking git push in workspace ${WORKSPACE}";
  git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" push;
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git push on workspace '${WORKSPACE}'.";
    return 1;
  fi;
}

# This will undo local modifications.
# Warning: changes to files staged and not committed will be lost.
# We can use this to undo local modifications.
# Danger: use at own risk
git_reset_local() {
  local files_modified_count="`git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | wc -l | awk '{print $1}'`";
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git status on workspace '${WORKSPACE}'.";
    return 1;
  fi;
  if [ ${files_modified_count} -gt 0 ]; then
    echo "WARN: Workspace contained ${files_modified_count} locally modified or staged files: '${WORKSPACE}'.";
  fi;

  git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" reset HEAD
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git reset on workspace '${WORKSPACE}'.";
    return 1;
  fi;

  git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" checkout -- .
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to invoke git checkout -- on workspace '${WORKSPACE}'.";
    return 1;
  fi;

  # Now find any files that are new (not added), and remove them
  git --work-tree="${WORKSPACE}" --git-dir="${WORKSPACE}/.git" status --short | grep "^??" | cut -c 4- | while read x; do echo "Removing untracked file $x"; rm -fv "${WORKSPACE}/${x}"; done;
  if [ $? -ne 0 ]; then
    echo "ERROR: Unable to remove local add files on workspace '${WORKSPACE}'.";
    return 1;
  fi;
}

# Perform a git clone or git pull to have the local workspace folder track the git repository.
update_workspace() {
  if [ ! -e ${WORKSPACE} ]; then
    git_clone_repo;
    if [ $? -ne 0 ]; then
      return 1;
    fi;
  else
    git_reset_local;
    git_pull_repo;
    if [ $? -ne 0 ]; then
      return 1;
    fi;
  fi;
}


##
# Begin program
##


update_workspace;
