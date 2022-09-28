#!/bin/bash
# File  : prep_condaforge_perl_recipe.sh
# Author: Felix Kuehnl
# Date  : 2022-09-28

# Strict mode: die on non-0 exit codes (-e) or when dereferencing unset
# variables (-u), propagate ERR traps to subshells (-E), and make pipes return
# exit code of first error (-o pipefail).
set -eEuo pipefail

# Abort on errors, displaying error message + code, kill all running jobs.
clean_and_die() {
    error_code="$1"; error_message="$2"
    echo -e "\nERROR: $error_message ($error_code) in script" \
        "'$(basename $0)'" 1>&2
    jobs=$(jobs -pr); [ -z "$jobs" ] || kill $(jobs -pr)
    exit $error_code
}

trap 'clean_and_die $? "terminated unexpectedly at line $LINENO"' ERR
trap 'clean_and_die  1 "interrupted"'           INT
trap 'clean_and_die  1 "caught TERM signal"'    TERM


##############################################################################
##                              Script options                              ##
##############################################################################

# Directory of condaforge repo.
CF_REPO_DIR='/home/felix/src/Conda/CondaForge/staged-recipes-fork'

# Name and version of this script
SCRIPT_NAME='prep_condaforge_perl_recipe.sh'
SCRIPT_VERSION='v0.1'

# Number of positional args. Set negative to disable check.
NO_POSITIONAL_ARGS=1

# Set options to parse here. Colon (:) after letter means option has a value.
OPT_STRING='vh'

HEADING=$( perl -e '        # Center string by adding padding spaces
    $line_length=78; $s="* * * @ARGV * * *"; $pad=($line_length-length $s)/2;
    $pad=0 if $pad<0; print " " x $pad, $s
' $SCRIPT_NAME $SCRIPT_VERSION )
usage=$( cat <<EndOfUsage
$HEADING

Create a basic CondaForge recipe for a given Perl module.

Usage:  $SCRIPT_NAME [ARGS]

Arguments:  [...] denotes default values, xx doubles, ii ints, ss strings
    -v:     Be verbose and show debug messages.
    -h:     Display this help and exit.
EndOfUsage
)
unset HEADING


##############################################################################
##                              Core functions                              ##
##############################################################################

# Display passed error message on STDERR. warn() continues while die() exits
# with error code 1.
die()  { echo   "ERROR: $*" 1>&2; exit 1; }
warn() { echo "WARNING: $*" 1>&2;         }


# Ensure existence and non-emptiness of a (regular) file
# Arguments:
#   file_name, and optionally
# Optional arguments:
#   file_description: To be displayed in error message [File]
#   can_be_empty: Whether empty files are allowed [false]
assert_file_exists() {
    local file_name="$1"
    local file_description="${2-File}"
    local can_be_empty=${3:-}
    local error=
    local message=

    [ -f "$file_name" ] || { error=1; message='not found'; }
    [ ! -n "$error" ] && [ ! -n "$can_be_empty" ] && [ ! -s "$file_name" ] &&
        { error=1; message='is empty'; }

    [ -z "$error" ] ||
        die "$file_description '$file_name' $message"
}

# For a list of executables, check whether each one is available in path.
check_exec() {
    for name in "$@"; do
        local type="$(type -t "$name")"
        if [ -z "$type" ]; then
            echo "Could not find '$name', make sure it is available!" 1>&2
            exit 1
        fi
    done
}

# Print a message if global variable is set, usually via -v switch
dbgm() {
    if [ -n "${BE_VERBOSE-}" ]; then
        echo "$@" 1>&2
    fi
    return 0
}

# Indent all text piped through with n spaces.
# Argument: n -- amount of spaces to indent [4]
indent() {
    local indent=${1-4}     # indent 4 spaces by default
    perl -pe "print q{ } x $indent"
}


##############################################################################
##                              Default values                              ##
##############################################################################

BE_VERBOSE=${BE_VERBOSE:+1}
# n=$'\n'                 # Newline
# t=$'\t'                 # Tab
export LC_COLLATE='C'   # set sys language to C to avoid problems with sorting
export LC_NUMERIC='C'   # also recognize '.' as decimal point


##############################################################################
##                              Option parsing                              ##
##############################################################################

while getopts "$OPT_STRING" opt; do
    case $opt in
#       e)
#           example="$OPTARG" ;;
        v)
            BE_VERBOSE=1 ;;
        h)
            echo "$usage"
            exit 0
            ;;
        *)
            die 'Invalid option, use -h to get help.'
    esac
done

#### Positional args ####
shift $(($OPTIND-1))       # shift positional parameters to position 1, 2, ...
wrongNoParamMsg='Wrong number of positional parameters, use -h to get help'
[ $# -eq $NO_POSITIONAL_ARGS ] || [ $NO_POSITIONAL_ARGS -lt 0 ] ||
    die "$wrongNoParamMsg"


#### Collect positional args ####
# Use array/"${var[@]}" notation to preserve file names containing whitespace
# input_files=("$@")
perl_module="$1"


#### Print debug output like e. g. passed arguments ####
dbgm "                      * * * $SCRIPT_NAME $SCRIPT_VERSION  * * *"


##############################################################################
##                           Function definitions                           ##
##############################################################################

# Function to add decimal marks / thousands separators to an integer
_1000s_sep() {
    _1000S_SEP=$(
    perl -pne '
            while ( s/([-+]?\d+)(\d{3})/\1,\2/g ) {}
        ' <<< "$1"
    )
}

# Convert a Perl::Module::Name into a perl-conda-package-name.
make_package_name() {
    local perl_module="$1"
    echo "perl-$perl_module" | tr 'A-Z' 'a-z' | sed 's/::/-/g'
}

##############################################################################
##                                   Main                                   ##
##############################################################################

# Check that our tools are available.
check_exec 'conda' 'conda-skeleton' 'perl'
perl -we 'use YAML' || die 'Install the Perl YAML module'

##### Prepare repo for new recipe
# Change to CondaForge repo dir.
echo "Working in repo '$CF_REPO_DIR'"
cd "$CF_REPO_DIR"

# Ensure worktree is clean
[ -z "$(git status --short)" ] || die 'git status of repo not clean'

# Checkout new branch with package name.
package="$(make_package_name "$perl_module")"
echo "Making recipe for CondaForge package '$package' from Perl module '$perl_module'"
git checkout main
git pull upstream main ||
    die 'Could not update main branch. Make sure remote "upstream" exists' \
        'and links to CondaForge staged-recipes'
git checkout -b "$package"

##### Make initial recipe
# Use conda skeleton to create initial recipe.
cd 'recipes'
conda skeleton cpan "$perl_module"
cd "$package" ||
    die "conda skeleton did not create dir '$package'. The specified" \
        "module could be part of another distribution, check metacpan.org"

# Move content out of version dir.
ver_dir="$(ls)"
mv "$ver_dir/*" '.'
rmdir "$ver_dir"

##### Update recipe to meet CondaForge standards.
# Update build.sh
echo "Updating build.sh"
perl -i 'BAK' -wlne '
    s/--installdirs site/--installdirs vendor/;     # install to vendor dir...
    s/INSTALLDIRS=site/INSTALLDIRS=vendor/;         # ...instead of site
    print unless /^\s*#/;                           # remove comment lines
' 'build.sh'

# Update bld.bat (even though Windows builds are unsupported as of now).
echo "Updating bld.bat"
perl -i 'BAK' -wlne '
    s/--installdirs site/--installdirs vendor/;     # install to vendor dir...
    s/INSTALLDIRS=site/INSTALLDIRS=vendor/;         # ...instead of site
    print unless /^\s*::/;                          # remove comment lines
' 'bld.bat'

# Update meta.yaml
echo "Updating meta.yaml"
perl -i 'BAK' "$(dirname "$0")/prep_condaforge_meta.pl" 'meta.yaml'

cat <<END_OF_MSG
All done. When you are ready, clean, commit and try to build locally:

    cd '$CF_REPO_DIR' &&
    rm "recipes/$package/"*BAK &&
    git commit recipes &&
    python3 ./build-locally.py linux64

END_OF_MSG

exit 0                                          # EOF

