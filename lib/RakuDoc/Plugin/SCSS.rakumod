use experimental :rakuast;
use RakuDoc::Templates;
use RakuDoc::PromiseStrings;
use RakuDoc::Render;

unit class RakuDoc::Plugin::SCSS;
has %.config = %(
    :name-space<SCSS>,
	:license<Artistic-2.0>,
	:credit<https://sass-lang.com/>,
	:author<Richard Hainsworth, aka finanalyst>,
	:version<0.1.0>,
    :css([]),
);

submethod TWEAK {
    my $proc = shell( <<sass --version>>, :out, :merge);
    exit note 'RakuDoc::Plugin::SCSS Plugin fails because the program sass is not reachable.' unless $proc.out.slurp(:close) ~~ / \d \. \d+ /;
}
method enable( RakuDoc::Processor:D $rdp ) {
    self.convert-scss( $rdp );
    $rdp.add-data( %!config<name-space>, %!config );
}
method convert-scss( $rdp ) {
    my %d := $rdp.templates.data;
    my %scss = %d.pairs
        .grep({ .value ~~ Associative })
        .grep({ .value.<scss> ~~ Positional })
        .map( { .key => .value.<scss> });
    my @p-tuples := %!config<css>;
    for %scss.kv -> $plugin, $tuple-list {
        if $tuple-list ~~ Positional {
            for $tuple-list.list -> ($scss, $order) {
                if $scss ~~ Str && $order ~~ Int {
                    my Proc $sass-process = shell( <<sass --stdin --style=compressed>>, :in, :err, :out );
                    $sass-process.in.spurt( $scss ,:close);
                    with $sass-process.out.slurp(:close) {
                        @p-tuples.push: [ "/* $plugin */\n$_", $order ];
                    }
                    with $sass-process.err.slurp(:close) {
                        note "SCSS error in plugin ｢$plugin｣: $_" if $_
                    }
                }
                else { note "Element ｢$_｣ of config attribute ｢scss｣ for plugin ｢$plugin｣ not a [Str, Int] tuple"}
            }
        }
        else { note "Config attribute ｢scss｣ for plugin ｢$plugin｣ must be a Positional, but got ｢$tuple-list｣"}
    }
}