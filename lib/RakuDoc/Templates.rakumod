use v6.d;
use PrettyDump;

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
            $rv = "<$!name>\n";
            for %params.sort(*.key)>>.kv -> ($k, $v is rw) {
                $v = 'UNINITIALISED' without $v;
                $rv ~= $k ~ ': ｢' ~ $v ~  "｣\n"
            }
            $rv ~= "</$!name>\n";
        }
        elsif $!pretty {
            my $indent = ' ' x 2;
            for %params.sort(*.key)>>.kv -> ($k, $v is rw) {
                $v = 'UNINITIALISED' without $v;
                given $v {
                    when Str { $v .= subst(/ \n /, "\n$indent", :g) }
                    default {
                        $v = pretty-dump( $v ).subst(/ \n /, "\n$indent", :g)
                    }
                }
                $rv ~= $indent ~ $k ~ ': ｢' ~ $v ~  "｣\n"
            }
            $rv = "\n<$!name>\n$rv\</$!name>\n";
        }
        else {
            $rv = &!block(%params, self);
        }
        say "Template output: ｢$rv｣" if $!verbose;
        $rv
    }
    multi method CALL-ME(Str:D $key) {
        say "Embedded ｢$key｣ called with stored params" if $!debug;
        say("Template params:\n" ~ %!call-params ) if $!verbose;
        my $rv = ($.globals{$key})(%!call-params);
        say "Template output: ｢$rv｣" if $!verbose;
        $rv
    }
    multi method CALL-ME(Str:D $key, %params) {
        say "Embedded ｢$key｣ called with new params" if $!debug;
        say("Template params:\n" ~ %params ) if $!verbose;
        my $rv = ($.globals{$key})(%params);
        say "Template output: ｢$rv｣" if $!verbose;
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
        ($.globals.prior($!name, $!depth))(%params);
    }
}

class X::Unexpected-Template is Exception {
    has $.key;
    method message {
        "Template ｢$.key｣ is not known"
    }
}

#| A hash that remembers previous values
class Template-directory does Associative {
    has %.fields handles < push EXISTS-KEY iterator list keys values >;
    has %.data;
    has %.helper;
    has $.source is rw = 'Initial';
    has Bool $.debug is rw = False;
    has Bool $.test is rw = False;
    has Bool $.pretty is rw = False;
    has Str $.verbose is rw = '';
    multi method AT-KEY ($key) is rw {
        with %!fields{$key} {
            .[* - 1].globals = self;
            .[* - 1].debug = $!debug;
            .[* - 1].test = $!test;
            .[* - 1].pretty = $!pretty;
            .[* - 1].verbose = $.verbose eq $key;
            .[* - 1]
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
            %!fields{$name}[$depth - 1].debug = $!debug ;
            %!fields{$name}[$depth - 1]
        }
        else { '' }
    }
}
