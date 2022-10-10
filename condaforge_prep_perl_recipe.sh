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

# Name and version of this script
SCRIPT_NAME='prep_condaforge_perl_recipe.sh'
SCRIPT_VERSION='v0.1'

# Number of positional args. Set negative to disable check.
NO_POSITIONAL_ARGS=1

# Set options to parse here. Colon (:) after letter means option has a value.
OPT_STRING='r:bvh'

HEADING=$( perl -e '        # Center string by adding padding spaces
    $line_length=78; $s="* * * @ARGV * * *"; $pad=($line_length-length $s)/2;
    $pad=0 if $pad<0; print " " x $pad, $s
' $SCRIPT_NAME $SCRIPT_VERSION )
usage=$( cat <<EndOfUsage
$HEADING

Create a basic CondaForge recipe for a given Perl module.

Usage:  $SCRIPT_NAME [ARGS] PERL_MODULE

Arguments:  [...] denotes default values, xx doubles, ii ints, ss strings
    -r ss:  Path to your fork of CondaForge staged-recipes repository. [.]
    -b:     Stay in the current branch instead of creating a new one.
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
export LC_COLLATE='C'   # set sys language to C to avoid problems with sorting
export LC_NUMERIC='C'   # also recognize '.' as decimal point

# Directory of CondaForge repo.
# cf_repo_dir='staged-recipes'
cf_repo_dir='.'
in_current_branch=      # do not switch to a new branch

##############################################################################
##                              Option parsing                              ##
##############################################################################

while getopts "$OPT_STRING" opt; do
    case $opt in
#       e)
#           example="$OPTARG" ;;
        r)
            cf_repo_dir="$OPTARG" ;;
        b)
            in_current_branch=1 ;;
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

# Extract the version from the dist file reported by `cpanm --info`.
get_dist_version() {
    local dist_file="$1" base
    base="$(basename "$dist_file" '.tar.gz')"   # remove owner & tar.gz suffix
    echo "${base##*-}"                  # version follows the last dash ('-')
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

# Check we can load all of a given list of Perl modules
check_perl_mod() {
    for module in "$@"; do
        perl -we "use $module" ||
            die "Please install Perl module '$module' (run \`cpanm $module\`)."
    done
}


##############################################################################
##                                   Main                                   ##
##############################################################################

# Check that our tools are available.
check_exec 'conda' 'conda-skeleton' 'perl' 'cpanm' 'git' \
           'condaforge_patch_meta.pl'
check_perl_mod 'autodie qw(:all)'

##### Prepare repo for new recipe
# Change to CondaForge repo dir.
echo "### Working in CondaForge repo '$cf_repo_dir'"
cd "$cf_repo_dir" ||
    die 'Failed to enter repo, use -r to set the correct path.'
[ -f 'conda-forge.yml' ] ||
    die 'Could not find conda-forge.yml, is this really the CondaForge' \
        'staged-recipes repo?'

# Ensure this is a git repo
git_stat="$(git status --short)" || die 'This is not a git repo!'

# Check package information and existance. cpanm dies if module non-existent.
# The PERL_MM_OPT variable needs to be set to silence a stupid warning.
dist_file="$(PERL_MM_OPT=. cpanm --info "$perl_module")"
ver="$(get_dist_version "$dist_file")"

# Checkout new branch with package name.
package="$(make_package_name "$perl_module")"
echo "### Making recipe for CondaForge package '$package' from Perl module" \
     "'$perl_module' (version $ver) in distribution '$dist_file'"
if [ -z "$in_current_branch" ]; then
    # Ensure worktree is clean
    [ -z "$git_stat" ] || die 'git status of repo not clean.'

    echo '### Updating main branch'
    git checkout main
    git pull upstream main ||
        die 'Could not update main branch. Make sure remote "upstream" exists' \
            'and links to CondaForge staged-recipes'
    echo '### Creating new branch'
    git checkout -b "$package"
fi

##### Make initial recipe
# Use conda skeleton to create initial recipe.
echo '### Creating initial recipe using conda skeleton'
cd 'recipes'
[ -d "$package" ] && die "Dir recipes/$package/ exists already!"
# Force the up-to-date version as reported by cpanm.
conda skeleton cpan --version "$ver"  "$perl_module"
cd "$package" ||
    die "conda skeleton did not create dir '$package'. The specified" \
        "module could be part of another distribution (try \`cpanm --info" \
        "$perl_module\`), or a core module (try \`corelist $perl_module\`," \
        "where corelist is from Module::CoreList), or this is a conda" \
        "skeleton bug (happens often enough)."

# Move content out of version dir. Check we are using the latest version.
ver_dir="$(ls)"
[ "$ver" == "$ver_dir" ] ||
    echo "WARNING: cpanm reported version '$ver', but conda skeleton" \
         "created directory '$ver_dir'. Check that recipe uses the latest"\
         "version!"
mv "$ver_dir"/* '.'
rmdir "$ver_dir"

##### Update recipe to meet CondaForge standards.
# Update build.sh
linux_build_script='build.sh'
echo "### Updating $linux_build_script"
perl -i'.BAK' -wlne '
    s/--installdirs site/--installdirs vendor/;     # install to vendor dir...
    s/INSTALLDIRS=site/INSTALLDIRS=vendor/;         # ...instead of site
    print unless /^\s*#/;                           # remove comment lines
' "$linux_build_script"

# Update bld.bat (even though Windows builds are unsupported as of now).
win_build_script='bld.bat'
echo "### Updating $win_build_script"
perl -i'.BAK' -wlne '
    s/--installdirs site/--installdirs vendor/;     # install to vendor dir...
    s/INSTALLDIRS=site/INSTALLDIRS=vendor/;         # ...instead of site
    print unless /^\s*::/;                          # remove comment lines
' "$win_build_script"

# Update meta.yaml
meta_file='meta.yaml'
echo "### Updating $meta_file"
cp "$meta_file" "$meta_file.BAK"    # make backup. perl -i does not work here
condaforge_patch_meta.pl -m "$perl_module" "$meta_file.BAK" > "$meta_file"

# Report import tests such that the user can verify these work with the local
# install of the module. Background: (1) not all modules defined in a dist can
# be imported, and (2) the version of the main module sometimes does not
# match that of submodules, which leads to a build fail in the CondaForge CI.
echo '### Conda tests'
imports=( $(grep -v '{[{%]' meta.yaml | shyaml get-values 'test.imports') )
printf "%s\n" 'The following import tests will be done:' "${imports[@]}"

cat <<END_OF_MSG
All done. When you are ready, clean, commit and try to build locally:

    # Enter repo:
    cd '$cf_repo_dir'

    # Inspect recipe:
    less 'recipes/$package/$meta_file'

    # Clean and commit:
    rm 'recipes/$package/'*BAK &&
    git add 'recipes/$package' &&
    git commit -m 'Added recipe $package for Perl module $perl_module'

    # Build locally:
    python3 ./build-locally.py linux64

END_OF_MSG

exit 0                                          # EOF

