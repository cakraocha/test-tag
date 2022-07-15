#!/bin/bash

# function to check whether the version is in accordance to semver
# e.g. 1.0.1
function chsv_check_version() {
  if [[ $1 =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$ ]]; then
    echo "$1"
  else
    echo ""
  fi
}

# function to check semver version with prefix 'v'
# e.g. v1.0.1
function chsv_check_version_ex() {
  if [[ $1 =~ ^v.+$ ]]; then
    chsv_check_version "${1:1}"
  else
    chsv_check_version "${1}"
  fi
}

# format of the merge commit have to have the ':'
# e.g. '32890d0 Merge pull request #6 from oscerai/dev v1.0.1: test to increment minor'
if [[ $str == *[':']* ]]
then
  VERSION=`cut -d ":" -f1 <<< "$VERSION"`
  VERSION=$(echo "${VERSION##* }")
# if no ':', then the format is incorrect
# we just see whether the current commit already has a tag in it
# if no tag attach, then return 1 due to wrong format and no tag attached
else
  GIT_COMMIT=`git rev-parse HEAD`
  NEEDS_TAG=`git describe --contains $GIT_COMMIT 2>/dev/null`

  if [ "$NEEDS_TAG" ]; then
    echo "Tag already exists with this commit. Using existing tag.."
    echo ::set-output name=git-tag::$NEW_TAG
    exit 0
  else
    echo "Wrong commit format and no tag found."
    exit 1
  fi
fi

# check the version whether it is in accordance to semver
# if yes, we use that tag
check=`chsv_check_version_ex $str`
if [ "$check" ]; then
  VERSION="v${check}"
  echo "Using tag from commit ${VERSION}"
  git tag $VERSION
  git push origin tag $VERSION
  echo ::set-output name=git-tag::$VERSION
  exit 0
# else, it must be a major, minor, or patch increment
else
  # get highest tag number, and add v0.1.0 if doesn't exist
  git fetch --prune --unshallow 2>/dev/null
  CURRENT_VERSION=`git describe --abbrev=0 --tags 2>/dev/null`

  if [[ $CURRENT_VERSION == '' ]]
  then
    echo "No tags available. Please create your own first tag."
    exit 1
  else
    echo "Current Version: $CURRENT_VERSION"
    CURRENT_VERSION_PARTS=(${CURRENT_VERSION//./ })

    # get number parts
    VNUM1=${CURRENT_VERSION_PARTS[0]}
    VNUM2=${CURRENT_VERSION_PARTS[1]}
    VNUM3=${CURRENT_VERSION_PARTS[2]}

    if [[ $VERSION == 'major' ]]
    then
      VNUM1=v$((VNUM1+1))
    elif [[ $VERSION == 'minor' ]]
    then
      VNUM2=$((VNUM2+1))
    elif [[ $VERSION == 'patch' ]]
    then
      VNUM3=$((VNUM3+1))
    else
      echo "No version type (https://semver.org/) or incorrect type specified, available commits msg [major, minor, patch]"
      exit 1
    fi

    NEW_TAG="v$VNUM1.$VNUM2.$VNUM3"
    echo "($VERSION) updating $CURRENT_VERSION to $NEW_TAG"

    # get current hash and see if it already has a tag
    GIT_COMMIT=`git rev-parse HEAD`
    NEEDS_TAG=`git describe --contains $GIT_COMMIT 2>/dev/null`

    # only tag if no tag already
    if [ -z "$NEEDS_TAG" ]; then
      echo "Tagged with $NEW_TAG"
      git tag $NEW_TAG
      git push origin tag $NEW_TAG
    else
      echo "Tag already exists with this commit. Using existing tag.."
      CURRENT_TAG=`cut -d ":" -f1 <<< "$NEEDS_TAG"`
      echo ::set-output name=git-tag::$CURRENT_TAG
      exit 0
    fi
    echo ::set-output name=git-tag::$NEW_TAG
  fi
fi

exit 0
