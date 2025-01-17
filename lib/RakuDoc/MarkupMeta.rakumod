use v6.d;
#| A meta string, used by X<> and M<>, may be
#| an unquoted string not containing ',' or ';',
#| an array of strings delimited by ','
#| an array of arrays of string delimited by ';'
#| Any quoting marks are left to the user to interpret
#| RakuDoc documents contain X< ... | ..." "> markup where the "/' are significant
#| RakuDoc documents contain X< ... | ..." > markup where the "/' are significant
grammar RakuDoc::MarkupMeta {

    token TOP {
        <plain-string>
        | <plain-string-array>
        | <array-of-ps-arrays>
    }

    token plain-string-word { <-[ , ; \h]>+ }
    token plain-string {
        <plain-string-word>+ % \h+
    }
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
        make ~$/
    }
    method plain-string-array( $/ ) {
        make $/<plain-string>>>.made
    }
    method array-of-ps-arrays( $/ ) {
        make $/<plain-string-array>>>.made
    }
}