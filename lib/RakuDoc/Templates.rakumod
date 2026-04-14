use v6.d;
use RakuDoc::PromiseStrings;
use RakuDoc::Numeration;

class Template {
    has &.block;
    has $.globals is rw;
    has $.name;
    has $.depth is rw;
    has %.call-params;
    has $.source;
    has Bool $.debug is rw = False;
    has Bool $.test is rw = False;
    has Bool $.pretty is rw = False;
    has Bool $.verbose is rw = False;
    multi method AT-KEY(Str:D $key) {
        self.CALL-ME($key)
    }
    multi method CALL-ME(%params) {
        say "Template used: ｢$!name｣, source: {$!source}" if $!debug;
        say("Template params:\n" ~ %params ) if $!verbose;
        %!call-params = %params;
        my $rv;
        if $!test && $!pretty.not {
            $rv = express-params(%params, $!name)
        }
        elsif $!pretty {
            try require ::('Data::Dump::Tree') <&ddt>;
            if ::('Data::Dump::Tree') ~~ Failure {
                note "Failed to load Data::Dump::Tree! The module is only needed for --pretty";
            }
            else { ddt( %params, :title($!name)); }
            $rv = express-params(%params, $!name)
        }
        else {
            $rv = &!block(%params, self);
        }
        say "Template output: ｢{ $rv }｣" if $!verbose;
        $rv
    }
    multi method CALL-ME(Str:D $key) {
        say "Embedded ｢$key｣ called with stored params" if $!debug;
        say("Template params:\n" ~ %!call-params ) if $!verbose;
        my $rv = ($.globals{$key})(%!call-params);
        say "Template output: ｢{ $rv }｣" if $!verbose;
        $rv
    }
    multi method CALL-ME(Str:D $key, %params) {
        say "Embedded ｢$key｣ called with new params" if $!debug;
        say("Template params:\n" ~ %params ) if $!verbose;
        my $rv = ($.globals{$key})(%params);
        say "Template output: ｢{ $rv }｣" if $!verbose;
        $rv
    }
    multi method prev {
        return '' unless $!depth - 1 >= 0;
        say "Previous template used: ｢$!name｣, source: {$!source}, with stored params" if $!debug;
        ($.globals.prior($!name, $!depth))(%!call-params);
    }
    multi method prev(%params) {
        return '' unless $!depth - 1 >= 0;
        say "Previous template used: ｢$!name｣, source: {$!source}, with new params" if $!debug;
        say("Template params:\n" ~ %params ) if $!verbose;
        ($.globals.prior($!name, $!depth))(%params);
    }
}

class X::Unexpected-Template is Exception {
    has $.key;
    method message {
        "Template ｢$.key｣ is not known"
    }
}

sub express-params( %params, $name ) is export {
    my $rv = "<$name>\n";
    for %params.sort(*.key)>>.kv -> ($k, $v) {
        my $vi = $v // 'UNINITIALISED';
        $vi = "Binary object with {$vi.bytes} bytes" if $vi ~~ Buf;
        $vi = $v.cache.join() if $v.isa( Seq );
#        $vi = $v>>.Str.raku if $v.isa( Array );
        $rv ~= $k ~ ': ｢' ~ $vi ~ "｣\n";
    }
    $rv ~= "</$name>\n";
}

#| A hash that remembers previous values
class Template-directory does Associative {
    has %.fields handles < push EXISTS-KEY iterator list keys values >;
    has %.data;
    has %.helper;
    has &.escape is rw;
    has &.mangle is rw;
    has $.source is rw = 'Initial';
    has Bool $.debug is rw = False;
    has Bool $.test is rw = False;
    has Bool $.pretty is rw = False;
    has Str $.verbose is rw = '';
    multi method AT-KEY ($key) is rw {
        with %!fields{$key}.tail {
            .globals = self;
            .debug = $!debug;
            .test = $!test;
            .pretty = $!pretty;
            .verbose = $.verbose.contains( $key );
            $_
        }
        else {
            X::Unexpected-Template.new(:$key).throw
        }
    }
    multi method DELETE-KEY ($key) {
        %!fields{$key}.pop
    }
    multi method ASSIGN-KEY (::?CLASS:D: $key, $new) {
        %!fields{$key} .= push(Template.new(:block($new), :name($key), :source($.source)));
        %!fields{$key}[* - 1].depth = %!fields{$key}.elems - 1;
    }
    method STORE (::?CLASS:D: \values, :$INITIALIZE) {
        %!fields = Empty;
        for values.list { self.ASSIGN-KEY(.key, .value) };
        self
    }
    method prior($name, $depth) {
        if $depth >= 1 {
            %!fields{$name}[$depth - 1].[* - 1].globals = self;
            %!fields{$name}[$depth - 1].debug = $!debug ;
            %!fields{$name}[$depth - 1]
        }
        else { '' }
    }
}
