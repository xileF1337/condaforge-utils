# condaforge-utils

Some utilities and helper scripts for creating CondaForge recipes, especially
for Perl modules.

**WARNING**: This is under heavy development, untested, may screw your files,
obliterate your machine, and may not even compile. Use at your own risk.

Any bugfixes, useful additions and other contributions welcome!

## Provided functionality

Three scripts are provided which, to a great extent, automatically create a
CondaForge recipe for a given Perl module, perform sanity checks and commonly
required tasks to comply with the CondaForge guidelines. The recipes are
initially built using `conda skeleton cpan`, but are modified after. The
scripts perform the following tasks:

## `condaforge_prep_perl_recipe.sh`

Master script that, given a Perl module name, drives the process of creating a
new git branch for it (optionally, cf. `-b` option), creates the initial
recipe, and updates the created templates. Pay attention to the emitted
warnings (and probably ignore the not-so-helpful warnings from `conda
skeleton`).

## `condaforge_patch_meta.pl`

Script to patch the `meta.yaml` template created by `conda skeleton` to match
the requirements of CondaForge. Provide the Perl module name (`-m` switch) to
achieve optimal results.

## `condaforge_test_perl_imports.sh`


## Usage


## Dependencies

`condaforge_prep_perl_recipe.sh` automatically checks the availability of all
dependencies before doing anything and reports anything missing.


## Copyright & License

Copyright Sept--Oct 2022 Felix K&uuml;hnl

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program, cf. file `COPYING`. If not, see <https://www.gnu.org/licenses/>.


<!-- END OF FILE -->
