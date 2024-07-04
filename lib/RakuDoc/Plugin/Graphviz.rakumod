use v6.d;
use RakuDoc::Templates;
use RakuDoc::Render;

unit class RakuDoc::Plugin::Graphviz;
has %.config =
    :name-space<graphviz>,
    :block-name('Graphviz'),
	:license<Artistic-2.0>,
	:credit<https://graphviz.org/credits/ Common Public License Version 1.0>,
	:version<0.1.0>,
;
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates );
    $rdp.add-data( %!config<name-space>, %!config );
}
method templates {
    %(
        Graphviz => sub (%prm, $tmpl) {
            # check that dot executes
            my $proc = shell 'command -v dot', :out;
            unless $proc.out.slurp(:close) { # if dot does not exist, then no output
                    return "\n"~'<div class="graphviz">The program ｢dot｣ fom Graphviz needs installing to get an image</div>'
            }
            my $data = %prm<raw>;
            $proc = Proc::Async.new(:w, 'dot', '-Tsvg');
            my $proc-rv;
            my $proc-err;
            $proc.stdout.tap(-> $d { $proc-rv ~= $d });
            $proc.stderr.tap(-> $v { $proc-err ~= $v });
            my $promise = $proc.start;
            $proc.put($data);
            $proc.close-stdin;
            try {
                await $promise;
                CATCH {
                    default {}
                }
            }
            my $rv = "\n"~'<div class="graphviz">';
            if $proc-rv { $rv ~= $proc-rv }
            elsif $proc-err {
               $rv ~= '<div style="color: red">'
                ~ $proc-err.subst(/^ .+? 'tdin>:' \s*/, '') ~ '</div>'
                ~ '<div>Graph input was <div style="color: green">' ~ $data ~ '</div></div>'
            }
            $rv ~= '</div>'
        },
    )
}