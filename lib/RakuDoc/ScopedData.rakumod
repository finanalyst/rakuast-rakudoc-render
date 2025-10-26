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
has @!save-spacer = 'None' => False , ;
has Str $.in-head is rw = '';
#| item and defn numerations by default are block scoped,
#| Other para-ish numerations are in a Processed object
has Hash @.numerations = %(
    item => Numeration.new,
    defn => Numeration.new,
    ),
;
has Bool $.debug is rw = False;
#| debug information
method diagnostic {
    qq[ Scope levels: { +@!starters }
    Scope starters: { +@!starters ?? @!starters.join(' ') !! 'original level' }
    Space savers: { +@!save-spacer ?? @!save-spacer.map({ .key ~ ' => ' ~ .value}).join(', ') !! 'original level' }]
}
#| starts a new scope
method start-scope(:$starter!, :$title, :$verbatim ) {
    @!starters.push: $starter;
    @!titles.push: $title // 'Block # ' ~ @!starters.elems;
    @!config.push: @!config.tail.pairs.hash;
    @!aliases.push: @!aliases.tail.pairs.hash;
    with $verbatim and @!save-spacer.tail.not {
        @!save-spacer.push: $starter => $verbatim.so
    }
    else {
        @!save-spacer.push: @!save-spacer.tail
    }
    @!numerations.push: @!numerations.tail.pairs.map({ .key => .value.clone }).hash;
    say 'New scope started. ', $.diagnostic if $!debug
}
#| ends the current scope, forgets new data
method end-scope {
    @!starters.pop;
    @!titles.pop;
    @!config.pop;
    @!aliases.pop;
    @!save-spacer.pop;
    # before popping the enumations, we need to preserve warnings, if any
    my %last-numerations = @!numerations.pop;
    for %last-numerations.keys {
        my @warns = %last-numerations{ $_ }.warnings;
        next unless +@warns;
        @!numerations.tail{ $_ }.warnings.append: @warns
    }
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
    @!save-spacer.tail.value
}
multi method verbatim( :called-by($)! ) {
    @!save-spacer.tail.key
}
multi method numeration( $type --> Numeration ) {
    @!numerations.tail{$type}
}
multi method numeration-inc( $type, $level --> Numeration ) {
    @!numerations.tail{$type}.inc($level)
}
multi method numeration-reset( $type --> Numeration ) {
    @!numerations.tail{$type}.reset
}
multi method numeration-set( $type, $level, $num --> Numeration ) {
    @!numerations.tail{$type}.set($level, $num)
}
method numeration-warnings( --> Array ) {
    @!numerations.tail.pairs.sort.map( { ((.key ~ ' counter: ') <<~>> .value.warnings).Slip } ).Array
}