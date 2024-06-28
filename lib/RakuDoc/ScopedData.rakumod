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
has @!save-spacer = 'None' but False ;
#| the last item numeration
has Numeration @.items-numeration = Numeration.new , ;
#| the last defn numeration
has Numeration @.defns-numeration = Numeration.new , ;
has Bool $.debug is rw = False;
#| debug information
method diagnostic {
    qq[ Scope levels: { +@!starters }
    Scope starters: { +@!starters ?? @!starters.join(' ') !! 'original level' } ]
}
#| starts a new scope
method start-scope(:$starter!, :$title, :$verbatim ) {
    @!starters.push: $starter;
    @!titles.push: $title // 'Block # ' ~ @!starters.elems;
    @!config.push: @!config.tail.pairs.hash;
    @!aliases.push: @!aliases.tail.pairs.hash;
    with $verbatim and @!save-spacer.tail.not {
        @!save-spacer.push: $starter
    }
    else {
        @!save-spacer.push: @!save-spacer.tail
    }
    @!items-numeration.push: @!items-numeration.tail;
    @!defns-numeration.push: @!defns-numeration.tail;
    say 'New scope started. ', $.diagnostic if $!debug
}
#| ends the current scope, forgets new data
method end-scope {
    @!starters.pop;
    @!titles.pop;
    @!config.pop;
    @!aliases.pop;
    @!save-spacer.pop;
    say 'Scope ended. ', $.diagnostic if $!debug
}
multi method config(%h) {
    @!config.tail{ .key } = .value for %h;
}
multi method config( --> Hash ) {
    @!config.tail
}
multi method aliases(%h) {
    @!aliases.tail{ .key } = .value for %h;
}
multi method aliases( --> Hash ) {
    @!aliases.tail
}
method last-starter {
    if +@!starters { @!starters.tail }
    else { 'original level' }
}
multi method last-title() {
    if +@!titles { @!titles.tail }
    else { 'No starter yet' }
}
multi method last-title( $s ) {
    if +@!titles { @!titles.tail = $s }
}
multi method verbatim() {
    @!save-spacer.tail.so
}
multi method verbatim( :called-by($)! ) {
    @!save-spacer.tail
}
multi method item-inc( $level --> Str ) {
    @!items-numeration.tail.inc($level).Str
}
multi method item-reset() {
    @!items-numeration.tail.reset
}
multi method defn-inc( --> Str ) {
    @!defns-numeration.tail.inc(1).Str
}
multi method defn-reset() {
    @!defns-numeration.tail.reset
}

