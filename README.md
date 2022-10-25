# condaforge-utils

Some utilities and helper scripts for creating CondaForge recipes, especially
for Perl modules.

**WARNING**: This is under heavy development, untested, may screw your files,
obliterate your machine, and may not even compile. Use at your own risk.

Any bugfixes, useful additions and other contributions welcome!


## Usage

0. Fork the `conda-forge/staged-recipes` repository and fetch (`git clone`) a
   local copy (hereafter: "the recipe repo").
1. Enter the recipe repo and run `condaforge_prep_perl_recipe.sh
   Perl::Module::Name` to create a new branch `perl-module-name` and a recipe
   of that name for the Perl module `Perl::Module::Name`.
3. Follow the instructions and edit the created recipe if necessary. Commit
   changes.
4. Optional: To add an additional recipe to *the same branch*, run
   `condaforge_prep_perl_recipe.sh -b Another::Perl::Module` (note the `-b`
   switch). This can be used to add recipes for dependencies of the original
   module. Repeat if necessary.
5. Try to build locally as described in the printed instructions. If any
   dependencies are missing, go back to (4).
6. Push to a new remote branch and open a new pull request to
   `conda-forge/staged-recipes`.


## Provided functionality

Three scripts are provided which, to a great extent, automatically create a
CondaForge recipe for a given Perl module, perform sanity checks and commonly
required tasks to comply with the CondaForge guidelines. The recipes are
initially built using `conda skeleton cpan`, but are modified after. The
scripts perform the following tasks:

### `condaforge_prep_perl_recipe.sh`

Master script that, given a Perl module name, drives the process of creating a
new git branch for it (optionally, cf. `-b` switch), creates the initial
recipe, and updates the created templates. Pay attention to the emitted
warnings (and probably ignore the not-so-helpful warnings from `conda
skeleton`).

The script performs various sanity checks, like checking the availability of
required programs first, ensures we are in the right repo, updates the repo
main branch using a remote called `upstream` etc.

### `condaforge_patch_meta.pl`

Script to patch the `meta.yaml` template created by `conda skeleton` to match
the requirements of CondaForge. Provide the Perl module name (`-m` switch) to
achieve optimal results. This script is called by
`condaforge_prep_perl_recipe.sh` automatically.

### `condaforge_test_perl_imports.sh`

This helper script takes a number of Perl module names as arguments and
tries to Perl-`use` each of it. Success and version number, or failure, are
reported for each module. This script is *not* called automatically by
`condaforge_prep_perl_recipe.sh`, because the latter is usually executed in a
Conda environment (to provide `conda-build`), and the import tests should
probably be tested with a system installation of the Perl module in question.
Instead, `condaforge_prep_perl_recipe.sh` generates a command than can be
copy-and-pasted in a terminal manually to run the tests.


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
