#!/bin/bash

set -e

# Functions
function show_usage() {
	printf "\n\033[33m    %s\033[m\n\n" "$(basename "$0") -a <application> -r <release_tag> -m <message>"
	exit
}

function info() {
	printf '\033[1;34m==>\033[1;37m %s\033[m\n' "$1"
}

function fatal() {
	printf '\n\033[1;31m  [ERROR]\033[1;37m %s\033[m\n' "$1"
	[[ -n "$2" ]] && show_usage
	exit 1
}

function show_cursor() {
	printf '\033[?25h'
}

function hide_cursor() {
	printf '\033[?25l'
}

function clear_line() {
	printf '\033[2K\r'
}

function countdown() {
	local seconds="$1" suffix="s"
	hide_cursor
	trap 'show_cursor; exit;' EXIT
	for i in $(seq "$seconds" -1 1); do
		[ "$i" = 1 ] && suffix=""
		printf '\033[1;34m==>\033[1;37m Pausing for %d second%s\033[m' "$i" "$suffix"
		sleep 1
		clear_line
	done
	show_cursor
	trap - EXIT
}

# Default options
APPLICATION=""
RELEASE_VERSION=""
RELEASE_MESSAGE=""
RELEASE_BRANCH=master
UPDATES_BRANCH=updates

# GitHub Variables
GITHUB_OAUTH_TOKEN=${GITHUB_OAUTH_TOKEN:-<SET_ME>}
GITHUB_USERNAME=${GITHUB_USERNAME:gechr}
GITHUB_API_URL=https://api.github.com/repos/$GITHUB_USERNAME
GITHUB_RELEASE_DELAY=3

# Option parsing
while getopts ":h?:a:r:b:m:" opt; do
	case "$opt" in
		h)
			show_usage ;;
		a)
			APPLICATION=$OPTARG
			;;
		r)
			RELEASE_VERSION=$OPTARG
			;;
		b)
			RELEASE_BRANCH=$OPTARG
			;;
		u)
			UPDATES_BRANCH=$OPTARG
			;;
		m)
			RELEASE_MESSAGE=$OPTARG
			;;
	esac
done

# Sanity checks
if [[ "$APPLICATION" = "" ]]; then
	fatal 'Application name must be specified using `-a` parameter' 1
elif [[ "$RELEASE_VERSION" = "" ]]; then
	fatal 'Release version must be specified using `-r` parameter' 1
elif [[ ! "$RELEASE_VERSION" =~ ^([0-9]{1,2}\.){2}[0-9]{1,2}$ ]]; then
	fatal "Release version must be in the following format: <major>.<minor>.<patch> (e.g. 0.1.4)" 1
elif [[ "$RELEASE_MESSAGE" = "" ]]; then
	fatal 'Release message must be specified using `-m` parameter' 1
fi

# Variables
RELEASE_TAG=v${RELEASE_VERSION}
REPOSITORY="$HOME/Repositories/GitHub/$APPLICATION"
REPOSITORY_UPDATES="$HOME/Repositories/GitHub/${APPLICATION}_Updates"
PROJECT="$REPOSITORY/$APPLICATION.xcodeproj"
ARCHIVE_PATH="$HOME/Builds/$APPLICATION"

# Make sure we're on $RELEASE_BRANCH
info "Checking out '$RELEASE_BRANCH' branch"
git -C "$REPOSITORY" checkout -q "$RELEASE_BRANCH"

# Bump the version in Info.plist
info "Bumping version to $RELEASE_VERSION in Info.plist"
defaults write "$REPOSITORY/$APPLICATION/Info.plist" CFBundleVersion -string "$RELEASE_VERSION"
defaults write "$REPOSITORY/$APPLICATION/Info.plist" CFBundleShortVersionString -string "$RELEASE_VERSION"
plutil -convert xml1 "$REPOSITORY/$APPLICATION/Info.plist"

# Commit changes quietly
info "Committing changes"
git -C "$REPOSITORY" commit -q -m "Prepare for $RELEASE_TAG release" "$APPLICATION/Info.plist"

# Tag with vX.Y.Z
info "Tagging repository with '$RELEASE_TAG'"
git -C "$REPOSITORY" tag -a -m "$RELEASE_MESSAGE" "$RELEASE_TAG"

# Build the .app bundle
info "Building application '$APPLICATION'"
xctool -project "$PROJECT" -scheme "$APPLICATION" clean archive -archivePath "$ARCHIVE_PATH"

# Move into a temporary directory
TMPDIR=$(mktemp -d)
info "Created temporary directory for packaging - $TMPDIR"
cd "$TMPDIR"

# Zip the .app bundle
PACKAGE="$APPLICATION.app"
PACKAGE_ZIP="$PACKAGE.zip"
info "Copying $PACKAGE into current directory"
cp -r "$HOME/Builds/$APPLICATION.xcarchive/Products/Applications/$PACKAGE" .
zip -r "$PACKAGE_ZIP" "$PACKAGE"
rm -rf "$PACKAGE"

# Push commit
info "Pushing changes"
git -C "$REPOSITORY" push origin "$RELEASE_BRANCH"

# Push tag
info "Pushing tag"
git -C "$REPOSITORY" push origin "$RELEASE_TAG"

# Wait for a few seconds for the tag to become available for release
countdown $GITHUB_RELEASE_DELAY

# Prepare GitHub release
info "Creating release"
RELEASE_ID=$(curl -sS \
                  -H "Authorization: token $GITHUB_OAUTH_TOKEN" \
                  -H "Content-Type: application/json" \
                  -d "{ \"tag_name\": \"$RELEASE_TAG\", \"target_commitish\": \"$RELEASE_BRANCH\", \"name\": \"$RELEASE_VERSION\", \"body\": \"$RELEASE_MESSAGE\", \"draft\": false, \"prerelease\": false }" \
                  "$GITHUB_API_URL/$APPLICATION/releases" | jq --raw-output .id)

# Upload zip file
RELEASE_UPLOAD_URL="https://uploads.github.com/repos/$GITHUB_USERNAME/$APPLICATION/releases/$RELEASE_ID/assets?name=$PACKAGE_ZIP"
info "Uploading $PACKAGE_ZIP"
curl --data-binary "@$PACKAGE_ZIP" \
     -H "Content-Type: application/zip" \
     -H "Authorization: token $GITHUB_OAUTH_TOKEN" \
     -o /dev/null \
     "$RELEASE_UPLOAD_URL"

# Update appcast.xml
sed -i "/<\/language>/a \ \ \ \ <item>\n      <title>Version $RELEASE_VERSION</title>\n      <sparkle:releaseNotesLink>\n        https://github.com/$GITHUB_USERNAME/$APPLICATION/releases/tag/$RELEASE_TAG\n      </sparkle:releaseNotesLink>\n      <pubDate>$(date -R)</pubDate>\n      <enclosure\n        url=\"https://github.com/$GITHUB_USERNAME/$APPLICATION/releases/download/$RELEASE_TAG/$PACKAGE_ZIP\"\n        sparkle:version=\"$RELEASE_VERSION\"\n        length=\"$(/usr/bin/stat -f%z "$PACKAGE_ZIP")\"\n        type=\"application/octet-stream\" />\n      <sparkle:minimumSystemVersion>10.11</sparkle:minimumSystemVersion>\n    </item>" "$REPOSITORY_UPDATES/appcast.xml"

# Commit changes quietly
info "Committing changes"
git -C "$REPOSITORY_UPDATES" commit -q -m "Release version $RELEASE_VERSION" appcast.xml

# Push commit
info "Pushing changes"
git -C "$REPOSITORY_UPDATES" push origin "$UPDATES_BRANCH"
