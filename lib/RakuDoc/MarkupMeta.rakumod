use v6.d;
#| A meta string, used by X<> and M<>, may be
#| an unquoted string not containing ',' or ';',
#| a '|" quoted string containing ',' or ';'
#| an array of strings delimited by ','
#| an array of arrays of string delimited by ';'
grammar RakuDoc::MarkupMeta {

    token TOP {
        <plain-string>
        | <plain-string-array>
        | <array-of-ps-arrays>
    }

    token plain-string-word { <-[' " , ; \h]>+ }
    token plain-string {
        <plain-string-word>+ % \h+
        | \h* <quoted-chars>
    }
    token quoted-chars {
        \' ~ \' <inside-sng-quotes>
        |
        \" ~ \" <inside-dbl-quotes>
    }
    token inside-dbl-quotes { <-[ " ]>+ }
    token inside-sng-quotes { <-[ ' ]>+ }

    token plain-string-array { <plain-string>* % [\s* ',' \s*] }
    # Comma-separated 0-or-more substr
    token array-of-ps-arrays { <plain-string-array>* % [\s* ';' \s*] }
}
class RMActions {
    method TOP( $/ ) {
        my $type = $/.keys[0];
        my $value = $/{$type}.made;
        given $type {
            when 'plain-string' { $value = [ [$value , ], ] }
            when 'plain-string-array' { $value = [$value , ] }
        }
        make {
            :$type,
            :$value
        }
    }
    method plain-string( $/ ) {
        if $/<quoted-chars>:exists {
            if $/<quoted-chars><inside-dbl-quotes>:exists {
                make $/<quoted-chars><inside-dbl-quotes>.Str
            }
            else {
                make $/<quoted-chars><inside-sng-quotes>.Str
            }
        }
        else {
            make ~$/
        }
    }
    method plain-string-array( $/ ) {
        make $/<plain-string>>>.made
    }
    method array-of-ps-arrays( $/ ) {
        make $/<plain-string-array>>>.made
    }
}