
- perl-devel-nytprof [all found on bioconda]
    - perl-json-maybexs
    - # perl-test-more [core, we don't need it as dep]
    - perl-test-differences
    - perl-getopt-long [core]
        - perl-pod-usage
            - perl-pod-perldoc
                - perl-text-parsewords
                - perl-encode
            - perl-pod-simple
                - perl-pod-escapes => PR open


- perl-pls [the Perl Language Server]
    - perl-pod-markdown [ok]
    - perl-future-queue [ok]
    - perl-perl-tidy [ok]
    - perl-perl-critic [ok]
    - perl-uri [ok]
    - perl-future [ok]
    - perl-io-async
    - perl-ppr [ok]
    - perl-ppi [ok]
    - perl-test-nowarnings [ok]
    - perl-test-subcalls [ok]
    - perl-test-object [ok]
    - perl-params-util [in moose pt 1]
    - perl-clone [ok]
    - perl-task-weaken [ok]
    - perl-test-refcount [ok]
    - perl-test-identity [ok]
    - perl-struct-dumb [ok]



## Not Available:

- perl-term-readline [Term::ReadLine]
- perl-extutils-hascompiler [ExtUtils::HasCompiler]
    - ==> requires `export LD="$CC"` to fix linker flag errors when calling
      e.g. `can_compile_loadable_object`
    - if it is not working properly within the conda env, it should probably
      not be provided as package ...


## To be ported from BioConda

- perl-libwww-perl
- perl-http-message
- perl-lwp-protocol-https
- perl-termreadkey [Term::ReadKey]
