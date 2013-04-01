#!/bin/bash -e
set -e

############################################################
#####                  Releasable                      #####
### Pure bash script for handling git release versioning ###
############################################################


############################################################
#####                   DEFAULTS                       #####
############################################################

RELEASE_PREFIX='release'
VERSION_PREFIX='v'
CHANGELOG_FILE='CHANGELOG'
VERSION_FILE='VERSION'
CHANGELOG_SCOPE=':all_commits'
CHANGELOG_STRATEGY=':overwrite'

START_POINT=''
END_POINT=''

USAGE_OUTPUT="Usage : $(basename "$0") -v 'opt' [-r 'opt'][-p 'opt'] [-s 'opt'][-f 'opt'][-A][-P][-C][-V] --- create git release tag with changelog

options:
  required:
    -v set the software versioning type (major or minor or patch)
  versioning:
    -r  set the release prefix (default: release)
    -p  set the version prefix (default: v)
  changelog:
    -s  set the start point (default: the last tag name that matches the versioning prefix)
    -f  set the end/finish point (default: HEAD)
    -A  append to changelog (default: overwrite)
    -P  set to only pull requests (default: all commits)
    -C  set the changelog filename (default: CHANGELOG)
    -V  set the version file name (default: VERSION)
  general:
    -h  show this help text
    -t  test only (will not execute script)


usage examples:

  1) Basic usage with defaults
    Given the last release was at 1.0.4, with a tag of 'our-releases/REL1.0.4' :

    $(basename "$0") -v minor -r 'our-releases' -p 'REL-'

    Tag generated           : our-releases/REL1.1.4
    Version file contains   : 1.1.4
    CHANGELOG file contains : commit information for all commits between last release and HEAD

  2) Pull requests only (changelog generated only with body of pull request titles)

    $(basename "$0") -v minor -r 'releases' -p 'v' -P

  3) Generate custom changelog and version file

    $(basename "$0") -v minor -r 'releases' -p 'v' -C 'MYCHANGELOGFILE' -V 'MYVERSIONFILE'

"

#Supporting functions
script_source=$( dirname "${BASH_SOURCE[0]}" )
. $script_source/support/releaseable.sh

############################################################
#####                  INPUT CAPTURE                   #####
############################################################

while getopts htAPv:r:s:f:p:C:V: option
do
  case "${option}"
  in
    h)
      echo "$USAGE_OUTPUT" >&2
      exit 0
      ;;
    t) SKIP_EXECUTE=true;;
    P) CHANGELOG_SCOPE=":pulls_only";;
    A) CHANGELOG_STRATEGY=":append";;
    v) VERSION_TYPE="$OPTARG";;
    r) RELEASE_PREFIX="$OPTARG";;
    p) VERSION_PREFIX="$OPTARG";;
    s) START_POINT="$OPTARG";;
    f) END_POINT="$OPTARG";;
    C) CHANGELOG_FILE="$OPTARG";;
    V) VERSION_FILE="$OPTARG";;

    ?)
      printf "illegal option: '%s'\n" "$OPTARG" >&2
      echo "$USAGE_OUTPUT" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))


if [ ! $SKIP_EXECUTE ]; then
  ############################################################
  #####                  VALIDATION                      #####
  ############################################################

  validate_version_type "$VERSION_TYPE" "$USAGE_OUTPUT"
  ensure_git_directory
  ensure_git_is_clean

  ############################################################
  #####                   RELEASE                        #####
  ############################################################
  VERSIONING_PREFIX=$(versioning_prefix $RELEASE_PREFIX $VERSION_PREFIX)

  last_tag_name=$(get_last_tag_name $VERSIONING_PREFIX);

  if [[ "$START_POINT" = '' ]]; then
    START_POINT=$last_tag_name
  fi;

  next_version_number=$(get_next_version_number_from_tag $VERSION_TYPE $last_tag_name)
  next_tag_name="${VERSIONING_PREFIX}${next_version_number}"
  generate_version_file "$next_version_number" "$VERSION_FILE"

  changelog_content=$(generate_changelog_content "$next_version_number" "$CHANGELOG_SCOPE" "$START_POINT" "$END_POINT")

  generate_changelog_file "$changelog_content" "$CHANGELOG_STRATEGY" "$CHANGELOG_FILE"

  #TODO : Test mode should display process
  #TODO : Verbose debug mode

  #TODO : Split up functions and specs into more logical divisions (changelog, git)

  set +e #Allow commit to fail if no files have changed
  git add -A
  git commit -m "Release : ${next_tag_name}"
  set -e

  git tag $next_tag_name
  #TODO: Optional force push of tag
  #TODO : Ask for confirmation unless -f (force) is passed
  #git push --tags
fi;
