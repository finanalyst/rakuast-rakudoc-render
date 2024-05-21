use v6.d;

#| ScopedData objects contain config, and aliases data that is scope limited
#| a new scope can be created with all the data of previous scope
#| when scope ends, new data is forgotten, old is restored
unit class RakuDoc::ScopedData;

has @!config = {}, ; #an array of hashes, with empty hash at start
has @!aliases = {}, ;
has @!callees;
has @!titles;
#| debug information
method debug {
    qq:to/DEBUG/;
    Scope levels: { +@!callees }
    Scope callees: { +@!callees ?? @!callees.join(' ') !! 'original level' }
    DEBUG
}
#| starts a new scope
method start-scope(:$callee!, :$title ) {
    @!callees.push: $callee;
    @!titles.push: $title // 'Block # ' ~ @!callees.elems;
    @!config.push: @!config[*-1].pairs.hash;
    @!aliases.push: @!aliases[*-1].pairs.hash;
}
#| ends the current scope, forgets new data
method end-scope {
    @!callees.pop;
    @!titles.pop;
    @!config.pop;
    @!aliases.pop;
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
method last-callee {
    if +@!callees { @!callees[*-1] }
    else { 'original level' }
}
multi method last-title() {
    if +@!titles { @!titles[* - 1] }
    else { 'No callee yet' }
}
multi method last-title( $s ) {
    if +@!titles { @!titles[* - 1] = $s }
}

