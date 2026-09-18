use v6.d;
use Test;
use License::SPDX;
#no precompilation;
#note 'no precompilation';
#use REPL;
#note 'using repl';

unit module RakuDoc-Plugin-Test;

# rakudo must be able to parse json, so it doesn't
# make sense to require a dependency to parse it
our sub from-json($text) {
    ::("Rakudo::Internals::JSON").from-json($text)
}
our sub to-json(|c) {
    ::("Rakudo::Internals::JSON").to-json(|c)
}

proto sub MAIN(|c) is export {*}

multi sub MAIN(Str $namespace = 'RakuDoc') {
    # obtain list of plugins from META6
    my $meta-path = 'META6.json';
    my %meta = try { %(from-json($meta-path.IO.slurp)) } || exit note "Invalid json? File: { $meta-path }";
    my %plugins = %meta<provides>
            .pairs
            .grep({ .key ~~ / ^ $namespace  '::Plugin' / });
    my $licence-list = License::SPDX.new;
    my @mandatory-fields = <name-space version license credit >;
    plan %plugins.elems;
    for %plugins.kv -> $p-name, $p-path  {
        my $object;
        subtest "testing $p-name", {
#            plan @mandatory-fields.elems + 4;
            eval-lives-ok $p-path.IO.slurp, 'evals';
            if $namespace eq 'RakuDoc' {
#                skip('compiled name space problem', @mandatory-fields.elems + 3)
#            }
#            else {
                lives-ok {
                    $object = ::($p-name).new
                }, 'object instantiates';
                my %config := $object.config;
                isa-ok %config, Hash, 'got config';
                for @mandatory-fields {
                    ok %config{$_}, "mandatory config field $_ has content";
                }
                ok $licence-list.get-license(%config<license>), 'license is accepted SPDX type';
            }
#            done-testing
        }
    }
    done-testing
}