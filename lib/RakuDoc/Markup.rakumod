use v6.d;
unit grammar RakuDoc::Markup;
    # head is what is left of vertical bar, any non-vertical bar char, or empty
    # attrs is on right of bar
    # attrs is semicolon-separated list of things, can be double-quoted, or empty
    # What we care about are "head" and "meta" results
    # credit to @yary for this grammar

    # TODO rule instead of token? use .ws instead of \s or \h
    token TOP {
        <head>
        | <head> \s* '|' \s* <metas> \s*
        | ^ '|' \s* <metas> \s*
    }

    token head-word { <-[|\h]>+ }
    token head {
        <head-word>+ % \h+ | ''
    }

    token metas { <meta>* % [\s* ';' \s*] }
    # Semicolon-separated 0-or-more attr

    token meta-word { <-[;\"\h]>+ }
    # Anything without quote or solidus or space
    token meta-words { <meta-word>+ % \h* }
    token inside-quotes { <-[ " ]>+ }
    token meta-quoted {
        '"' ~ '"' <inside-quotes>*
    }
    token meta {
        <meta-words> | <meta-quoted>
    }
    # TODO: use "make" to pull inside-quotes value to meta
