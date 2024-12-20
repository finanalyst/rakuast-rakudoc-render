use v6.d;
use RakuDoc::Templates;
use RakuDoc::Render;

unit class RakuDoc::Plugin::Markdown::Graphviz;
has %.config =
    :name-space<graphviz>,
    :block-name('Graphviz'),
	:license<Artistic-2.0>,
	:credit<https://graphviz.org/credits/ Common Public License Version 1.0>,
	:version<0.2.0>,
;
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates, :source<GraphViz plugin> );
    $rdp.add-data( %!config<name-space>, %!config );
}
method templates {
    %( # Markdown for github does not allow for cross site injection, so svg has to be saved to a local file
        Graphviz => sub (%prm, $tmpl) {
            my $level = %prm<headlevel> // 1;
            my $rv = $tmpl('head', %(:$level, |(%prm<id target caption delta>:p)));
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
            if $proc-rv {
                my $fn = $tmpl.globals.data<source-data><name> ~ '_' ~ $tmpl.globals.mangle.(%prm<caption>);
                my $fnref = $fn.IO.basename;
                $fn .= subst(/ \/ /,'%2f',:g );
                if "$fn.svg".IO ~~ :e & :f {
                    $fnref ~= '_0';
                    $fn ~= '_0';
                    while "$fn.svg".IO ~~ :e & :f {
                        $fn++;
                        $fnref++
                    }
                }
                $fn ~= '.svg';
                $fn.IO.spurt: $proc-rv;
                $rv ~= qq|![]({$fnref}.svg)|
            }
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