#!/bin/bash
# Creates a release including
#   * git tags
#   * creating and publishing the hex packages
#   * creating and publishing the hex documentation
#   * patch mix.exs and release.sh towards the new version
# development version have always the "-dev" suffix in their
# version name.

# set -x

# CONFIGURATION
old="1.1.3"
new="1.1.4"
# do not set any variables beyond this line

# check that old and new version differ
if [ "$old" == "$new" ]
then
	echo "old and new version must differ, please edit script"
	exit 1
fi

old_version="$old-dev"
release_version="$old"
new_version="$new-dev"
tag_name=v$release_version
script_name="`basename $0`"
set +x

git branch | grep '* master' > /dev/null
if [ 1 -eq $? ]; then
	echo "ERROR: Not on branch master"
	exit 1
fi

echo "Development version = $old_version"
echo "Release version     = $release_version"
echo "New version         = $new_version"
read -p "Check the variables. Press Ctrl-C for exit, return for continuing"

# update version in mix.exs
sed -i "" "s/\(version: \"\)$old_version\",/\\1$release_version\",/" mix.exs

# add to git
git commit -m "bump version to $release_version" mix.exs

# tag the commit
git tag -a -m "new release version v$release_version" v$release_version

# Upload to Hex.PM
echo "Publish to Hex.pm"
mix hex.publish

# update version in mix.exs
sed -i "" "s/\(version: \"\)$release_version\",/\\1$new_version\",/" mix.exs
# update in release.sh
sed -i "" "s/\(old=\"\)$old_version\"/\\1$new\"/" $script_name

# add to git
git commit -m "bump version to $new_version" mix.exs

# push to github
git push origin master --tags

# call for action
echo "Release created. Please edit $script_name and mix.exs for the next version!"
