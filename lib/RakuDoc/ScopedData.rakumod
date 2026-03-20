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
#| headers may have embedded RakuDoc markup, which cause AST paragraphs, but are not paraish blocks
#| In addition X<> markup in a header needs a target, which should be the same as the header target
#| so in-head is used to store the target of a head for its embedded X<>. Hence it is a string.
#| A blank string boolifies to False
has Str $.in-head is rw = '';
#| definitions have a second line that may be a paragraph but are not paraish blocks
has Bool $.in-defn is rw = False;
#| items have content that may be a Paragraph, but should not be a para block
has Bool $.in-item is rw = False;
has CounterTracker @!counter-tracker .= new;
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
    @!counter-tracker.push: @!counter-tracker.tail.clone;
    say 'New scope started. ', $.diagnostic if $!debug
}
#| ends the current scope, forgets new data
method end-scope {
    @!starters.pop;
    @!titles.pop;
    @!config.pop;
    @!aliases.pop;
    @!save-spacer.pop;
    # before popping the enumerations, we need to preserve warnings, if any
    my $last-ct = @!counter-tracker.pop;
    @!counter-tracker.tail.warnings.append: $last-ct.warnings;
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
multi method counter-tracker( --> CounterTracker ) {
    @!counter-tracker.tail
}
method numeration-warnings ( --> Positional ) {
    @!counter-tracker.tail.warnings
}