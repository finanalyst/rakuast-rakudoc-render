use v6.d;
class Template {
    has &.block;
    has $.globals is rw;
    has $.name;
    has $.depth is rw;
    has %.call-params;
    multi method CALL-ME(%params) {
        %!call-params = %params;
        &!block(%params, self)
    }
    multi method CALL-ME(Str:D $key) {
        ($.globals{$key})(%!call-params)
    }
    multi method AT-KEY(Str:D $key) {
        self.CALL-ME($key)
    }
    multi method CALL-ME(Str:D $key, %params) {
        ($.globals{$key})(%params)
    }
    multi method prev {
        return '' unless $!depth - 1 >= 0;
        ($.globals.prev($!name, $!depth))(%!call-params);
    }
    multi method prev(%params) {
        return '' unless $!depth - 1 >= 0;
        ($.globals.prev($!name, $!depth))(%params);
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
    multi method AT-KEY ($key) is rw {
        with %!fields{$key} {
            .[*- 1].globals = self;
            .[*- 1]
        }
        else {
            X::Unexpected-Template.new(:$key).throw
        }
    }
    multi method DELETE-KEY ($key) {
        %!fields{$key}.pop
    }
    multi method ASSIGN-KEY (::?CLASS:D: $key, $new) {
        %!fields{$key} .= push(Template.new(:block($new), :name($key)));
        %!fields{$key}[*- 1].depth = %!fields{$key}.elems - 1;
    }
    method STORE (::?CLASS:D: \values, :$INITIALIZE) {
        %!fields = Empty;
        for values.list { self.ASSIGN-KEY(.key, .value) };
        self
    }
    method prev($name, $depth) {
        if $depth >= 1 { %!fields{$name}[$depth - 1] }
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
}

class PStr {
    has @.string;
    method Str {
        @!string>>.Str.join
    }
    method debug {
        @!string>>.map({ $_ ~~ PCell ?? .debug !! '｢' ~ .gist ~ '｣' }).join(',')
    }
    multi method pre(Str(Any) $s) {
        @!string.unshift($s);
        self
    }
    multi method pre(PCell $s) {
        @!string.unshift($s);
        self
    }
    multi method post(Str(Any) $s) {
        @!string.push($s);
        self
    }
    multi method post(PCell $s) {
        @!string.push($s);
        self
    }
    multi method merge(PStr $s) {
        @!string.push($s.string);
        self
    }
    method lead() {
        my Str $rv;
        while @!string[0] ~~ Str { $rv ~= @!string.shift }
        $rv
    }
    method tail() {
        my Str $rv;
        while @!string[*- 1] ~~ Str { $rv ~= @!string.pop }
        $rv
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