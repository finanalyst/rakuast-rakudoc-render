use v6.d;
grammar RakuDoc::MarkupMeta {
    # A meta string, used by X<> and M<>, may be
    # an unquoted string not containing ',' or ';',
    # a '|" quoted string containing ',' or ';'
    # an array of strings delimited by ','
    # an array of arrays of string delimited by ';'

    token TOP {
        <plain-string>
        | <plain-string-array>
        | <array-of-ps-arrays>
    }

    token plain-string-word { <-[' " , ; \h]>+ }
    token plain-string {
        <plain-string-word>+ % \h+
        | <quoted-chars>
    }
    token quoted-chars {
        \' ~ \' <inside-quotes>
        |
        \" ~ \" <inside-quotes>
    }
    token inside-quotes { <-[ ' " ]>+ }

    token plain-string-array { <plain-string>* % [\s* ',' \s*] }
    # Comma-separated 0-or-more substr
    token array-of-ps-arrays { <plain-string-array>* % [\s* ';' \s*] }
}
class RMActions {
    method TOP( $/ ) {
        my $type = $/.keys[0];
        my $value = $/{ $type }.made;
        make {
            :$type,
            :$value
        }
    }
    method plain-string( $/ ) {
        with $/<quoted-chars><inside-quotes> {
            make ~$/<quoted-chars><inside-quotes>
        }
        else {
            make ~$/
        }
    }
    method plain-string-array( $/ ) {
        make $/<plain-string>>>.Str
    }
    method array-of-ps-arrays( $/ ) {
        make $/<plain-string-array>>>.made
    }
}