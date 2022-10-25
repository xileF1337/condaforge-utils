#!/bin/bash
# File  : condaforge_test_perl_imports.sh
# Author/Copyright: Felix Kuehnl
# Date  : 2022-09-30
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program, cf. file `COPYING`. If not, see
# <https://www.gnu.org/licenses/>.
#
##############################################################################

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

die()  { echo   "ERROR: $*" 1>&2; exit 1; }


##############################################################################
##                                   Main                                   ##
##############################################################################

[ $# -gt 0 ] ||
    die 'Pass name(s) of Perl module(s) for which to test import'

for mod in "$@"; do
    [ "$mod" == '-' ] && continue   # skip over '-' when pasting YAML file
    echo -n "### $mod: ";
    perl -we "
            use $mod;           # try to load module
            print 'version ', \$$mod::VERSION // 'undef', q{ };
        " && echo 'ok' || echo 'FAILED';
done

# EOF
