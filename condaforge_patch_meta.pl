#!/usr/bin/env perl
# prep_condaforge_meta.pl
# Prepare the file meta.yaml as created by `conda skeleton cpan
# Some::Perl::Module` to match the requirements of CondaForge.

use warnings;
use strict;
use autodie ':all';

use Getopt::Long;
use Module::CoreList;       # Check for core modules

# To verify URLs and resolve redirects:
use HTTP::Request;
use LWP::UserAgent;

use YAML ();

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
        retrieve additional information using cpanm (install App::Cpanminus!).
    -h, --help:     Show this help.
END_OF_USAGE

# Parse options
my $module_name;
my $show_help;
GetOptions(
    'module|m=s'    => \$module_name,
    'help|h'        => \$show_help,
) or (print STDERR $usage and exit -1);
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
    die 'Could not run cpanm -h. Ensure App::Cpanminus is ',
        'installed and cpanm is in PATH' if $@;

    # Get dependencies
    my @deps = readpipe "cpanm --showdeps '$perl_module'";
    chomp @deps;
    die "Could not retrieve dependencies for Perl module '$perl_module'"
        unless @deps;   # deps should at least contain perl and makemaker etc

    # Remove trailing version
    s/~[.\d]+$// for @deps;

    return map {$_ => 1} @deps;
}

# Is the given module a core module?
sub is_core {
    my ($module) = @_;
    return Module::CoreList::is_core($module);
}

# Parse a YAML file, given line by line (including newlines).
sub parse_yaml {
    my (@meta) = @_;

    # We remove lines starting with {% (=Jinja var defs) and remove {{ and }}
    # (=Jinja var substitutions).
    my $meta = join q{}, map {s/[{][{] //; s/ [}][}]//; $_} grep {not /^[{]%/}
                                                                 @meta;
    return %{ YAML::Load($meta) };
}

# Thats a heuristic!! Convert conda package name to perl module name.
# Chomp of leader perl-, replace dashes (-) by double colons (::) and convert
# the first letter of each part to upper case. This fails for modules
# containing upper-case letters in any other position.
sub pkg_to_mod_name {
    my ($pkg) = @_;

    $pkg =~ s/^perl-//;
    return join "::", map {ucfirst} split /-/, $pkg;
}


# Given a URL, perform a GET request on it and print messages if (1) the
# request fails, or (2) if the request is redirected. Returns the URL with the
# redirection resolved (if any), or the URL within "BROKEN" tags on errors.
sub resolve_url_redirect {
    my ($url) = @_;

    # Prepare a HTTP request to retrieve the URL.
    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new(GET => $url);

    # Perform the HTTP request.
    my $response = $ua->request($req);

    # Check for errors and return result.
    if ($response->is_success) {
        # There may be a row of requests, the last one has the resolved URL.
        my $resolved_url = $response->request->uri;

        # Inform user if the resolved URL differs from the input.
        print STDERR "Updating with resolved URL $resolved_url"
            unless $url eq $resolved_url;

        return $resolved_url;
    }
    else {
        print STDERR "WARNING: Could not resolve URL!";
        return "<BROKEN>$url</BROKEN>";
    }
}


##############################################################################
##                                   Main                                   ##
##############################################################################

die 'Pass a single meta.yaml file' unless @ARGV == 1;

local $\ = "\n";                    # auto-append newline to print statements

# Read input meta.yaml line-wise. The parsed data structure is only used for
# look-ups; the file content is printed vanilla and only modified under
# explicitely defined conditions.
my @meta = <>;
my %yaml = parse_yaml(@meta);
chomp @meta;

# Retrieve dependencies of module.
my %mod_deps;
if (defined $module_name) {
    eval { %mod_deps = get_module_deps($module_name) };
    print STDERR "WARNING: $@" if $@;
}
else {
    print STDERR "WARNING: no module name provided (-m), cannot do some checks.";
}

# Set options depending on deps.
my $add_make          = $mod_deps{'ExtUtils::MakeMaker'};
my $add_c_comp        = $mod_deps{'XSLoader'} || $mod_deps{'DynaLoader'};
my $add_test_needs    = $mod_deps{'Test::Needs'};
my $add_test_fatal    = $mod_deps{'Test::Fatal'};
my $add_test_requires = $mod_deps{'Test::Requires'};
my $add_module_build  = $mod_deps{'Module::Build'};

# There seems to be a general problem with Test::* module deps, better print
# all that we find but not yet handle explicitly.
my @unhandled_test_mods = do {
    my %handled = map {'Test::' . $_  => 1} qw(Needs Fatal Requires);
    grep {/^Test::/ and not $handled{$_} and not is_core($_)} keys %mod_deps;
};
print STDERR join "\n" . q{ }x4, 'WARNING: unhandled Test::* module(s):',
                                 @unhandled_test_mods
    if @unhandled_test_mods;

# Pass 1: scan meta data and set options.
# When checking deps, note that core module deps are usually commented out
# but may still indicate certain requirements.
my ($version);
# my $dep_pfx = qr/^\s*(#\s*)?-/;  # match prefix of (commented out?) dep
for (@meta) {
    # $add_make = 1   if /$dep_pfx perl-extutils-makemaker/;
    # $add_c_comp = 1 if /$dep_pfx perl-(dynaloader|xsloader)/;
    $version = $1 if /^\{% set version = "([\d.]+)" %\}$/;
}
print STDERR 'WARNING: no version found' unless defined $version;

# Pass 2: modify and print.
my $cur_block = q{};            # current top-level "block" we are in
for (@meta) {
    if (/^(\w+):$/) {           # keep track of current top-level block
        $cur_block = $1;
        print q{};              # print a blank line (only) before new block
    }
    if (/^\s*$/) {
        next;                   # remove all other blank lines
    }
    if (/^\s*license:\s*(.*)$/) {
        my $license = $1;
        if ($license eq 'artistic_2') {
            print STDERR 'Adding Artistic license 2';
            print STDERR 'WARNING: Ensure license is packaged in file ',
                         'LICENSE (run cpanm --look MODULE) or change value!';
            print foreach
                q{ }x2 . 'license: Artistic-2.0',
                q{ }x2 . 'license_file: LICENSE',
        }
        else { # add default Perl 5 license in other cases
            print STDERR 'Adding default Perl license';
            print STDERR "WARNING: license key value was '$license', please ",
                         'double-check that license information is correct!'
                unless $license eq 'perl_5';

            print foreach
                q{ }x2 . 'license: GPL-1.0-or-later OR Artistic-1.0-Perl',
                q{ }x2 . 'license_file:',
                q{ }x4 . '- {{ environ["PREFIX"] }}/man/man1/perlartistic.1',
                q{ }x4 . '- {{ environ["PREFIX"] }}/man/man1/perlgpl.1';
        }
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
        print STDERR "Removing comment: $_";
        next;
    }
    if ($cur_block eq 'requirements') {
        if (/^\s+build:/) {         # requirements.build section
            print STDERR 'Skipping empty requirements.build key' and next
                unless $yaml{requirements}{build} or $add_c_comp or $add_make;
        }
        if (/^\s+#- ([-\w]+)$/) {   # commented out requirement
            # Skip these lines, for the reason, see below (requirements.run).
            print STDERR "Skipping commented out requirement: $_";
            next;
        }
    }
    if ($cur_block eq 'about') {
        if (/^\s*home:\s*(.*)$/) {
            my $url = $1;
            print STDERR "Trying to resolve home URL $url ...";
            print q{ }x2, 'home: ', resolve_url_redirect($url);
        }
    }

    print;                          # print current line

    if (/^build:/) {                # build section
        print STDERR 'Adding skip: true for Windows builds';
        print q{ }x2, 'skip: true   # [win]';
    }
    if ($cur_block eq 'requirements') {
        if (/^\s+build:/) {         # requirements.build section
            print q{ }x4, '- make' and print STDERR 'Adding make dep'
                if $add_make;
            print q{ }x4, "- {{ compiler('c') }}"
                    and print STDERR 'Adding C compiler dep'
                if $add_c_comp;
        }
        if (/^\s+host:/) {          # requirements.host section
            print q{ }x4, '- perl-test-needs'
                    and print STDERR 'Adding Test::Needs dep'
                if $add_test_needs;
            print q{ }x4, '- perl-test-fatal'
                    and print STDERR 'Adding Test::Fatal dep'
                if $add_test_fatal;
            print q{ }x4, '- perl-test-requires'
                    and print STDERR 'Adding Test::Requires dep'
                if $add_test_requires;
            print q{ }x4, '- perl-module-build'
                    and print STDERR 'Adding Module::Build dep'
                if $add_module_build;
        }
        if (/^\s+run:/) {           # requirements.run section
        }
        # # These commented out deps are likely due to the convention of
        # # enabling (weak) run exports for Perl modules. This means that a
        # # given module is automatically added as a runtime requirement (in the
        # # same version!) when it is added as a build requirement. This means
        # # we don't have to add it explicitely as a runtime dep.
        # if (/^\s+#- ([-\w]+)$/) {   # commented out requirement.
        #     my $dep = $1;
        #     my $mod_name = pkg_to_mod_name($dep); # that one may be wrong!
        #     print STDERR "WARNING: found commented out (possibly) non-core module dep '$dep'"
        #         unless is_core($mod_name);
        # }
    }
}

# Add "extra" section with maintainer list.
print STDERR "Adding 'extra' section with recipe-maintainers list ",
             "(@maintainers)";
print for q{}, 'extra:', q{ }x2 . 'recipe-maintainers:',
            map {q{ }x4 . "- $_"} @maintainers;

exit 0;                         #EoF
