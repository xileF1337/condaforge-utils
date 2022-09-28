#!/usr/bin/env perl
# prep_condaforge_meta.pl
# Prepare the file meta.yaml as created by `conda skeleton cpan
# Some::Perl::Module` to match the requirements of CondaForge.

use warnings;
use strict;

##############################################################################
##                                 Options                                  ##
##############################################################################

# List of GitHub accoutns to be added to the maintainer list.
my @maintainers = qw(xileF1337 cbrueffer);


##############################################################################
##                                   Main                                   ##
##############################################################################

die 'Pass a single meta.yaml file' unless @ARGV == 1;

local $\ = "\n";                    # auto-append newline to print statements

# Read input meta.yaml line-wise.
my @meta = <>;
chomp @meta;

# Pass 1: scan meta data and set options.
my ($add_buildsec, $add_make, $add_c_comp, $version);
for (@meta) {
    $add_buildsec = $add_make = 1   if /^\s*- perl-extutils-makemaker/;
    $add_buildsec = $add_c_comp = 1 if /^\s*- perl-xsloader/;
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
    if (/^\s*fn:/) {
        print STDERR 'Skipping source.fn key';
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
    print;                      # writes to file thanks to -i switch
    if (/^build:/) {
        print STDERR 'Adding skip: true for Windows builds';
        print q{ }x2, 'skip: true   # [win]';
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
print for q{}, 'extra:', q{ }x2 . 'recipe-maintainers:',
            map {q{ }x4 . "- $_"} @maintainers;

exit 0;                         #EoF
