# Issues of conda skeleton cpan

Report or fix the following issues:

- some (all?!) `Test::*` modules are not reported as dependency in meta.yaml
  by conda skeleton cpan
    - affected modules:
        - Test::Fatal
        - Test::Needs
        - Test::Requires
- Module::Build is erraneously classified as core module
    - conda skeleton refuses to even write a recipe for it
    - the `-write_core` option seems to be disfunctional
    - it once has been a core module, but has been removed, see below
    - the corelist util from Module::CoreList says:
        - corelist Module::Build
        - Data for 2022-09-20:
          Module::Build was first released with perl v5.9.4, deprecated (will
          be CPAN-only) in v5.19.0 and removed from v5.21.0
    - same for its dep inc::latest:
        - Data for 2022-09-20:
          inc::latest was first released with perl v5.11.2, deprecated (will
          be CPAN-only) in v5.19.4 and removed from v5.21.0
    - [issue](https://github.com/conda/conda-build/issues/4591) and
      [PR](https://github.com/conda/conda-build/pull/4592)
- C compiler deps are not properly added when XS files are found
    - [issue](https://github.com/conda/conda-build/issues/4598) and
      [PR](https://https://github.com/conda/conda-build/pull/4599)
