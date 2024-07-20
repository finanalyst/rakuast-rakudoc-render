use v6.d;
use Method::Protected;

class PCellTracker {
    has %.cell-list;
    method add-payload( :$payload, :$id ) is protected {
        %!cell-list{ $id }[0] = $payload;
    }
    method get( $id ) is protected {
        %!cell-list{ $id }[0]
    }
    #| starts tracking a new id with spec. Uniqueness of id depends on user
    method track( Str $id, Str :$spec --> Str ) {
        %!cell-list{ $id } = [ Nil, $spec ] unless %!cell-list{ $id }:exists;
        $id
    }
    multi method list-unexpanded( --> Hash ) is protected {
        %!cell-list.pairs
                    .grep( *.value[0].defined.not )
                    .map({ .key => .value[1] }).hash
    }
    multi method list-unexpanded( $filter --> Hash ) is protected {
        %!cell-list.pairs
                    .grep( *.value[0].defined.not )
                    .grep({ .value[1] ~~ / ^ $filter \: / })
                    .map({ .key => .value[1] }).hash
    }
}
class PCell {
    has PCellTracker $.archive;
    has Str $.id;
    method Str {
        $!archive.get( $!id ) // "｢$!id UNAVAILABLE｣"
    }
    method is-expanded( --> Bool ) { $!archive.get($!id).defined }
    submethod BUILD(:$register, :$id, :$spec = '') {
        $!archive := $register;
        $!id = $!archive.track( $id, :$spec )
    }
    method debug {
        my $text = $!archive.get( $!id );
        "\x3018 PCell, "
                ~ ($text.defined ?? "Expanded to: $text \x3019" !! "Waiting for: $.id \x3019")
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
        @!string[0] .= trim-leading if @!string[0] ~~ Str;
        self
    }
    #| trims any white space from the end string, if any
    method trim-trailing {
        $.strip;
        if @!string.elems == 1 {
            @!string[0] .= trim-trailing if @!string[0] ~~ Str
        }
        elsif @!string.elems > 1 {
            @!string[* - 1] .= trim-trailing if @!string[* - 1] ~~ Str;
        }
        self
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
        @!string = @new if +@new;
        self
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


