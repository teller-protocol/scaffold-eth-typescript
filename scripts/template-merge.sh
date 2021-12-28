#!/bin/zsh

cp_file_name="TEMPLATE_MERGE"

template="template"
template_url="https://github.com/teller-protocol/scaffold-eth-typescript.git"
tag_name="$template/latest-merge"

template_main="main"
origin_main="main"
template_branch_main="$template/$template_main"
origin_branch_main="origin/$origin_main"
tmp_branch_main="tmp/$origin_main"

init_branch=$(git rev-parse --abbrev-ref HEAD)
if [ -f $cp_file_name ]; then
  init_branch=$(cat $cp_file_name)
fi

success_msg() {
  echo
  echo "Successfully merged changes from template repo :)"
  echo
  echo "1. The repo's $origin_branch_main branch has been updated with the changes and pushed remotely"
  echo "2. $origin_branch_main has been merged with your working branch ($init_branch)"
  echo
}

cp_fail_msg() {
  echo
  echo "!! There was an issue merging the changes from the template repo !!"
  echo
  echo "1. Please correct any resulting conflicts"
  echo "2. Stage your merge conflicts"
  echo "3. Rerun this script!"
  echo "  - NOTE: do NOT use external app/commands to resolve the conflict!!"
  echo
}

# Checks if the template is added or the urls match
remote_add() {
  local url
  url=$(git remote get-url $template &> /dev/null)
  if [ $? -eq 0 ]; then
    if [ "$url" != $template_url ]; then
      git remote set-url template $template_url
    fi
  else
    git remote add template $template_url
  fi
}

checkout_origin() {
  git checkout -B $origin_main $origin_branch_main &> /dev/null && git pull --ff-only &> /dev/null
}

checkout_init() {
  git checkout "$init_branch" &> /dev/null
}

# Ensures the template is added and then fetches
remote_fetch() {
  remote_add && git fetch $template &> /dev/null
}

# Creates a local file to denote we have started the cherry-pick
cherry_pick() {
  echo "$init_branch" >> $cp_file_name
  git cherry-pick $tmp_branch_main
}

# Pushes changes and cleans up local repo
post_cherry_pick() {
  git push && (
    # Remove the cherry pick file
    rm $cp_file_name
    git add $cp_file_name

    # Checkout the original branch and delete the temp branch
    checkout_init
    git branch -D $tmp_branch_main &> /dev/null

    # Update the tag and current branch
    update_tag
    update_current_branch
  )
}

# Continues the cherry pick and post cleanup
post_cherry_pick_fail() {
  git -c core.editor=true cherry-pick --continue &&
    post_cherry_pick
}

# Merges in the changes from the template repo
# If this is not the first time, we will cherry-pick the changes since the last time
merge() {
  local merge_msg
  merge_msg="Merge changes from template"

  # Check if the template tag exists
  if [ "$(git tag -l $tag_name)" ]; then
    # Create a temp branch to work on
    git checkout -B $tmp_branch_main $tag_name &> /dev/null
    # Squash template changes into working tree
    git merge $template_branch_main --squash && (
      # Apply changes in commit
      git commit -m "$merge_msg"
      checkout_origin

      # Cherry pick the squashed commit into local repo
      cherry_pick && post_cherry_pick
    )
  else
    # REQUIRED: --allow-unrelated-histories
    git merge $template_branch_main --allow-unrelated-histories --squash -m "$merge_msg"
  fi
}

# Update the tag to point to the latest commit and push
update_tag() {
  git tag -f $tag_name "$(git rev-parse --short $template_branch_main)"
  git push -f --tag
}

update_current_branch() {
  # If we were not previously on the 'main' branch,
  # then check it out and merge in the changes
  if [ "$init_branch" != $origin_main ]; then
    checkout_init && git merge --no-ff $origin_main &> /dev/null
  fi
}

# Check if we already tried this and need to resolve a conflict
if [ -f $cp_file_name ]; then
  post_cherry_pick_fail && success_msg
else
  remote_fetch && (
    if merge; then
      success_msg
    else
      cp_fail_msg

      exit 77
    fi
  )
fi
