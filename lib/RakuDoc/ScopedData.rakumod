use v6.d;
use RakuDoc::Numeration;

#| ScopedData objects contain config, and aliases data that is scope limited
#| a new scope can be created with all the data of previous scope
#| when scope ends, new data is forgotten, old is restored
unit class RakuDoc::ScopedData;

has @!config = {}, ; #an array of hashes, with empty hash at start
has @!aliases = {}, ;
has @!starters;
has @!titles;
has @!save-spacer = 'None' but False, ;
#| the last item numeration
has Numeration @.items-numeration = Numeration.new , ;
#| the last defn numeration
has Numeration @.defns-numeration = Numeration.new , ;
#| debug information
method debug {
    qq:to/DEBUG/;
    Scope levels: { +@!starters }
    Scope starters: { +@!starters ?? @!starters.join(' ') !! 'original level' }
    DEBUG
}
#| starts a new scope
method start-scope(:$starter!, :$title, :$verbatim ) {
    @!starters.push: $starter;
    @!titles.push: $title // 'Block # ' ~ @!starters.elems;
    @!config.push: @!config[*-1].pairs.hash;
    @!aliases.push: @!aliases[*-1].pairs.hash;
    with $verbatim and @!save-spacer[*-1].not {
        @!save-spacer.push: $starter
    }
    else {
        @!save-spacer.push: @!save-spacer[*-1]
    }
    @!items-numeration.push: @!items-numeration[ * - 1 ];
    @!defns-numeration.push: @!defns-numeration[ * - 1 ]
}
#| ends the current scope, forgets new data
method end-scope {
    @!starters.pop;
    @!titles.pop;
    @!config.pop;
    @!aliases.pop;
    @!save-spacer.pop;
}
multi method config(%h) {
    @!config[*-1]{ .key } = .value for %h;
}
multi method config( --> Hash ) {
    @!config[*-1]
}
multi method aliases(%h) {
    @!aliases[*-1]{ .key } = .value for %h;
}
multi method aliases( --> Hash ) {
    @!aliases[*-1]
}
method last-starter {
    if +@!starters { @!starters[*-1] }
    else { 'original level' }
}
multi method last-title() {
    if +@!titles { @!titles[* - 1] }
    else { 'No starter yet' }
}
multi method last-title( $s ) {
    if +@!titles { @!titles[* - 1] = $s }
}
multi method verbatim() {
    @!save-spacer[ * - 1 ].so
}
multi method verbatim( :called-by($)! ) {
    @!save-spacer[ * - 1 ]
}
multi method item-inc( $level --> Str ) {
    @!items-numeration[ * - 1 ].inc($level).Str
}
multi method item-reset() {
    @!items-numeration[ * - 1 ].reset
}
multi method defn-inc( --> Str ) {
    @!defns-numeration[ * - 1 ].inc(1).Str
}
multi method defn-reset() {
    @!defns-numeration[ * - 1 ].reset
}

