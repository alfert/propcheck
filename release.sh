#!/bin/bash
# release.sh old new
set -x

# old is always with -dev
old="0.0.1."
new="0.0.2-dev"
# do not set any variables beyond this line
old_version="$old-dev"
release_version="$old"
new_version="$new"
tag_name=v$release_version
set +x

git branch | grep '* master' > /dev/null
if [ 1 -eq $? ]; then
	echo "ERROR: Not on branch master"
	exit 1
fi

read -p "Check the variables. Press Ctrl-C for exit, return for continuing"

# update version in mix.exs
sed -i "" "s/\(version: \"\)$old_version\",/\\1$release_version\",/" mix.exs

# add to git
git commit -m "bump version to $release_version" mix.exs

# tag the commit
git tag -a -m "new release version v$release_version" v$release_version

# Upload to Hex.PM
mix hex.publish
mix hex.docs

# update version in mix.exs
sed -i "" "s/\(version: \"\)$release_version\",/\\1$new_version\",/" mix.exs

# add to git
git commit -m "bump version to $new_version" mix.exs

# push to github
git push origin master --tags
