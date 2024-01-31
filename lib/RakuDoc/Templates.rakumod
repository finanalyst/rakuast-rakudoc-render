use v6.d;
class Template {
    has &.block;
    has $.globals is rw;
    has $.name;
    has $.depth is rw;
    has %.call-params;
    has $.source;
    has Bool $.debug is rw = False;
    multi method AT-KEY(Str:D $key) {
        self.CALL-ME($key)
    }
    multi method CALL-ME(%params) {
        say "Template used: ｢$!name｣, source: {$!source}" if $!debug;
        %!call-params = %params;
        &!block(%params, self)
    }
    multi method CALL-ME(Str:D $key) {
        say "Embedded ｢$key｣ called with stored params" if $!debug;
        ($.globals{$key})(%!call-params)
    }
    multi method CALL-ME(Str:D $key, %params) {
        say "Embedded ｢$key｣ called with new params" if $!debug;
        ($.globals{$key})(%params)
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
    multi method AT-KEY ($key) is rw {
        with %!fields{$key} {
            .[* - 1].globals = self;
            .[* - 1].debug = $!debug;
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

class PCell {
    has Supply $.s;
    has Str $!text;
    has Str $.id;
    method Str {
        $!s.tap: {
            $!text = .<payload>.Str.join if .<id> eq $!id;
        }
        $!text // "｢$!id UNAVAILABLE｣"
    }
    submethod BUILD(Supplier::Preserving :$com-channel, :$!id) {
        $!s = $com-channel.Supply
    }
    method debug {
        $.Str; # trigger tap if need be
        "\x3018 PCell, "
                ~ ($!text.defined ?? "Expanded to: $!text \x3019" !! "Waiting for: $.id \x3019")
    }
    method is-expanded( --> Bool ) {
        $.Str; # trigger tap
        $!text.defined
    }
}

class PStr {
    has @.string = ('', );
    multi method new( *@string ) {
        self.bless(:@string)
    }
    method Str {
        @!string>>.Str.join
    }
    method debug {
        @!string>>.map({ $_ ~~ PCell ?? .debug !! '｢' ~ .gist ~ '｣' }).join(',')
    }
    multi method pre(Str(Any) $s) {
        @!string.unshift($s);
        $.strip;
        self
    }
    multi method pre(PCell $s) {
        @!string.unshift($s);
        $.strip;
        self
    }
    multi method post(Str(Any) $s) {
        @!string.append($s);
        $.strip;
        self
    }
    multi method post(PCell $s) {
        @!string.append($s);
        $.strip;
        self
    }
    multi method merge(PStr $s) {
        @!string.append($s.string);
        $.strip;
        self
    }
    #| Strips PStr and returns first Str or '' if 1st is PCell
    method lead( --> Str ) {
        $.strip;
        @!string[0] ~~ Str ?? @!string[0] !! ''
    }
    #| Strips PStr and returns last Str or '' if last is PCell
    method tail( --> Str ) {
        $.strip;
        @!string[*-1] ~~ Str ?? @!string[* - 1] !! ''
    }
    #| trims any white space from the end string, if any
    method trim-leading {
        $.strip;
        @!string[0] .= trim-leading if @!string[0] ~~ Str
    }
    #| trims any white space from the end string, if any
    method trim-trailing {
        $.strip;
        @!string[* - 1] .= trim-trailing if @!string[* - 1] ~~ Str
    }
    #| trims any white space from the end string, if any
    method trim {
        $.trim-leading;
        $.trim-trailing;
    }
    #| replace any PCells that have been expanded with a plain Str
    #| concatenate any adjacent Str elements
    method strip() {
        my @new;
        for @!string -> $elem is copy {
            $elem = $elem.Str if $elem ~~ PCell and $elem.is-expanded;
            if ($elem ~~ Str) and +@new and (@new[*-1] ~~ Str) {
                @new[*-1] ~= $elem
            }
            else { @new.append: $elem }
        }
        @!string = @new if +@new
    }
    #| return whether there are PCells in the string
    method has-PCells( --> Bool ) {
        my Bool $has = False;
        $has ||= ($_ ~~ PCell).so for @!string;
        $has
    }
    #| return how many segments (elems of string array)
    method segments( --> Int ) {
        @!string.elems
    }
}

multi sub infix:<~>(Str $s, PStr $p --> PStr) is export {
    $p.pre($s)
}
multi sub infix:<~>(PStr $p, Str $s --> PStr) is export {
    $p.post($s)
}
multi sub infix:<~>(PCell $s, PStr $p --> PStr) is export {
    $p.pre($s)
}
multi sub infix:<~>(PStr $p, PCell $s --> PStr) is export {
    $p.post($s)
}
multi sub infix:<~>(PStr $p, PStr $s --> PStr) is export {
    $p.merge($s)
}
multi sub infix:<~>(Str $s, PCell $p --> PStr) is export {
    my PStr $rv .=new;
    $rv.post($s).post($p)
}