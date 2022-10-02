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
