use v6.d;
use RakuDoc::Templates;
use RakuDoc::Render;

unit class RakuDoc::Plugin::HTML::Graphviz;
has %.config =
    :name-space<graphviz>,
    :block-name('Graphviz'),
	:license<Artistic-2.0>,
	:credit<https://graphviz.org/credits/ Common Public License Version 1.0>,
	:version<0.2.0>,
	:scss( [ self.scss-str, 1], ),
;
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates, :source<GraphViz plugin> );
    $rdp.add-data( %!config<name-space>, %!config );
}
method templates {
    %(
        Graphviz => sub (%prm, $tmpl) {
            my $level = %prm<headlevel> // 1;
            my $rv = $tmpl('head', %(:$level, :id(%prm<id>), :target(%prm<target>), :caption(%prm<caption>), :delta(%prm<delta>)));
            # check that dot executes
            my $proc = shell 'command -v dot', :out;
            unless $proc.out.slurp(:close) { # if dot does not exist, then no output
                return qq|$rv\n<div class="graphviz">The program ｢dot｣ fom Graphviz needs installing to get an image\</div>|
            }
            my $data = %prm<raw>;
            my $attrs = '';
            $attrs = ('-G' <<~<< .comb(/\S+/)).join(' ') with %prm<attrs>;
            $proc = Proc::Async.new(:w, <<dot -Tsvg $attrs >>);
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
            if $proc-rv { $rv ~= qq[<div class="graphviz">$proc-rv\</div>] }
            elsif $proc-err {
               $rv ~= '<div class="graphviz-error">'
                ~ $proc-err.subst(/^ .+? 'tdin>:' \s*/, '')
                ~ '<div>Graph input was <span class="data">' ~ $data ~ '</span></div>'
                ~ '</div>'
            }
            else {
                $rv ~= '<div class="graphviz-error">No output from dot command</div>'
            }
            $rv
        },
    )
}
method scss-str {
    q:to/SCSS/
    /* Graphviz styling */
    div.graphviz {
        display: flex;
        justify-content: space-around;
        align-items: center;
        margin: auto;
        margin-bottom: 1rem;
    }
    .graphviz-error {
        display: flex;
        justify-content: space-around;
        align-items: center;
        color: red;
        font-weight: bold;
        span.data {
            color: green;
        }
    }
    SCSS
}