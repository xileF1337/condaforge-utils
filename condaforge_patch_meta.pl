#!/usr/bin/env perl
# prep_condaforge_meta.pl
# Prepare the file meta.yaml as created by `conda skeleton cpan
# Some::Perl::Module` to match the requirements of CondaForge.

use warnings;
use strict;
use autodie ':all';

use Getopt::Long;

##############################################################################
##                                 Options                                  ##
##############################################################################

my $usage = <<'END_OF_USAGE';
                    * * * condaforge_patch_meta.pl * * *

Prepare the file meta.yaml as created by `conda skeleton cpan
Some::Perl::Module` to match the requirements of CondaForge.

To improve the recipe and automatically add additional deps, provide the name
of the Perl module of this recipe using the -m option. Note that
App::Cpanminus (cpanm) is required to query CPAN.

Usage: condaforge_patch_meta.pl [OPTS] meta.yaml

Options:
    -m, --module:
        Name of the Perl module for the given meta.yaml file. It is used to
        retrieve additional information using
    -h, --help:     Show this help.
END_OF_USAGE

# Parse options
my $module_name;
my $show_help;
GetOptions(
    'module|m=s'    => \$module_name,
    'help|h'        => \$show_help,
) or (warn $usage and exit -1);
print $usage and exit 0 if $show_help;

# List of GitHub accoutns to be added to the maintainer list.
my @maintainers = qw(xileF1337 cbrueffer);


##############################################################################
##                                Functions                                 ##
##############################################################################

# Retrieve dependencies of the given Perl module.
sub get_module_deps {
    my ($perl_module) = @_;

    # Check than Cpanminus is availabl.
    eval { readpipe "cpanm --help" };
    die 'Cannot retrieve module dependencies. Ensure Cpanminus (cpanm) is ',
        'installed and in PATH' if @_;

    # Get dependencies
    my @deps = readpipe "cpanm --showdeps '$perl_module'";
    chomp @deps;
    die "Could not retrieve dependencies for Perl module '$perl_module'"
        unless @deps;   # deps should at least contain perl and makemaker etc

    # Remove trailing version
    s/~[.\d]+$// for @deps;

    ...
}

##############################################################################
##                                   Main                                   ##
##############################################################################

die 'Pass a single meta.yaml file' unless @ARGV == 1;

local $\ = "\n";                    # auto-append newline to print statements

# Read input meta.yaml line-wise.
my @meta = <>;
chomp @meta;

if (defined $module_name) {
    ...;                # TODO add
}

# Pass 1: scan meta data and set options.
# When checking deps, note that core module deps are usually commented out
# but may still indicate certain requirements.
my ($add_buildsec, $add_make, $add_c_comp, $version);
my $dep_pfx = qr/^\s*(#\s*)?-/;  # match prefix of (commented out?) dep
for (@meta) {
    $add_buildsec = $add_make = 1   if /$dep_pfx perl-extutils-makemaker/;
    $add_buildsec = $add_c_comp = 1 if /$dep_pfx perl-(dynaloader|xsloader)/;
    $version = $1 if /^\{% set version = "([\d.]+)" %\}$/;
}
print STDERR 'WARNING: no version found' unless defined $version;

# Pass 2: modify and print.
for (@meta) {
    if (/^\s*license:/) {
        print STDERR 'Adding default Perl license';
        print STDERR 'WARNING: license key value was NOT perl_5, please ',
                     'double-check that license information is correct!'
            unless /perl_5$/;

        print for q{ }x2 . 'license: GPL-1.0-or-later OR Artistic-1.0-Perl',
                  q{ }x2 . 'license_file:',
                  q{ }x4 . '- {{ environ["PREFIX"] }}/man/man1/perlartistic.1',
                  q{ }x4 . '- {{ environ["PREFIX"] }}/man/man1/perlgpl.1';
        next;
    }
    if (/^\s*fn:/) {    # OBSOLETE for new conda skeleton versions
        print STDERR 'Removing source.fn key';
        next;
    }
    if (/^\s*url:/ and defined $version) {
        # Replace literal version in URL with {{ version }} variable.
        if (s/\Q$version.tar.gz/{{ version }}.tar.gz/) {
            print STDERR "Subsituting version $version in source.url key";
        }
        else {
            print STDERR "WARNING: Could not subsitute version $version",
                         " in source.url key";
        }
    }
    if (/^\s*# /) {
        print STDERR "Removing comment: $_",
        next;
    }
    print;                      # writes to file thanks to -i switch
    if (/^build:/) {            # build section
        print STDERR 'Adding skip: true for Windows builds';
        print q{ }x2, 'skip: true   # [win]';
    }
    if (/^\s+build:/) {         # requirements.build section
        print STDERR 'Adding make dep, ensure this dist really needs it',
            '(run cpanm --look MODULE: is there Makefile.PL?)';
        print q{ }x4, '- make';
    }
    if (/^requirements:/) {
        if ($add_buildsec) {
            print STDERR 'Adding requirements.build section';
            print q{ }x2, 'build:';
            if ($add_make) {
                print STDERR 'Adding make dep';
                print q{ }x4, '- make';
            }
            if ($add_c_comp) {
                print STDERR 'Adding c compiler dep';
                print q{ }x4, q[- {{ compiler('c') }}];
            }
            print q{};              # blank line
        }
    }
}

# Add "extra" section with maintainer list.
print STDERR "Adding 'extra' section with recipe-maintainers list ",
             "(@maintainers)";
print for q{}, 'extra:', q{ }x2 . 'recipe-maintainers:',
            map {q{ }x4 . "- $_"} @maintainers;

exit 0;                         #EoF
