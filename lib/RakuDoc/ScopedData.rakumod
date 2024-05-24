use v6.d;

#| ScopedData objects contain config, and aliases data that is scope limited
#| a new scope can be created with all the data of previous scope
#| when scope ends, new data is forgotten, old is restored
unit class RakuDoc::ScopedData;

has @!config = {}, ; #an array of hashes, with empty hash at start
has @!aliases = {}, ;
has @!starters;
has @!titles;
has @!save-space = '';
#| debug information
method debug {
    qq:to/DEBUG/;
    Scope levels: { +@!starters }
    Scope starters: { +@!starters ?? @!starters.join(' ') !! 'original level' }
    DEBUG
}
#| starts a new scope
method start-scope(:$starter!, :$title, :$save-space ) {
    @!starters.push: $starter;
    @!titles.push: $title // 'Block # ' ~ @!starters.elems;
    @!config.push: @!config[*-1].pairs.hash;
    @!aliases.push: @!aliases[*-1].pairs.hash;
    with $save-space and @!save-space[*-1].not {
        @!save-space.push: $starter
    }
    else {
        @!save-space.push: @!save-space[*-1]
    }
}
#| ends the current scope, forgets new data
method end-scope {
    @!starters.pop;
    @!titles.pop;
    @!config.pop;
    @!aliases.pop;
    @!save-space.pop;
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
    @!save-space[ * - 1 ].so
}
multi method verbatim( :called-by($)! ) {
    @!save-space[ * - 1 ]
}

