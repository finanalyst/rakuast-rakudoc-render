use experimental :rakuast;
use RakuDoc::Render;
use RakuDoc::PromiseStrings;

unit class RakuDoc::To::Markdown;

method render($ast) {
    my $fn = $*PROGRAM;
    my %source-data = %(
        name     => ~$fn,
        modified => $fn.modified,
        path     => $fn.dirname
    );
    my $rdp = RakuDoc::Processor.new;
    $rdp.add-templates( $.markdown-templates, :source<RakuDoc::To::MarkDown> );
    $rdp.render( $ast, :%source-data  )
}

# no post processing needed
method postprocess( $final ) { $final };

method markdown-templates {
    my constant RESET = "\e[0m";
    my constant BOLD-ON = "**";
    my constant BOLD-OFF = "**";
    my constant ITALIC-ON = "*";
    my constant ITALIC-OFF = "*";
    my constant UNDERLINE-ON = "__";
    my constant UNDERLINE-OFF = "__";
    my constant CODE-ON = "`";
    my constant CODE-OFF = "`";
    my constant STRIKE-ON = "~~";
    my constant STRIKE-OFF = "~~";
    my constant SUPERSCR-ON = "<sup>";
    my constant SUPERSCR-OFF = "</sup>";
    my constant SUBSCR-ON = "<sub>";
    my constant SUBSCR-OFF = "</sub>";
#    my constant DBL-UNDERLINE-ON = "\e[21m";
#    my constant DBL-UNDERLINE-OFF = "\e[24m";
#    my constant CURL-UNDERLINE-ON = "\e[4:3m";
#    my constant CURL-UNDERLINE-OFF = "\e[4:0m";
    my constant REPLACE-ON = "**__";
    my constant REPLACE-OFF = "__**";
    my constant INDEXED-ON = '<span style="color:green; background-color: antiquewhite">';
    my constant INDEXED-OFF = '</span>';
    my constant INDEX-ENTRY-ON = '<span style="background-color: antiquewhite; font-weight: 600;">';
    my constant INDEX-ENTRY-OFF = '</span>';
    my constant KEYBOARD-ON = "***";
    my constant KEYBOARD-OFF = "***";
    my constant TERMINAL-ON = "***__";
    my constant TERMINAL-OFF = "__***";
    my constant FOOTNOTE-ON = "<sup>";
    my constant FOOTNOTE-OFF = "</sup>";
    my constant LINK-TEXT-ON = "[";
    my constant LINK-TEXT-OFF = "]";
    my constant LINK-ON = "(";
    my constant LINK-OFF = ")";
    my constant DEPR-TEXT-ON = '<span style="color:red; background-color: pink">';
    my constant DEPR-TEXT-OFF = '</span>';
    my constant DEPR-ON = '<span style="background-color: pink">**';
    my constant DEPR-OFF = "</span>";
    my constant DEFN-TEXT-ON = '<span style="background-color: lightgrey">';
    my constant DEFN-TEXT-OFF = '</span>';
    my constant BAD-MARK-ON = "`";
    my constant BAD-MARK-OFF = "`";
    my @bullets = <<\x2022 \x25b9 \x2023 \x2043 \x2219>> ;
    %(
        #| special key to name template set
        _name => -> %, $ { 'markdown templates' },
        # escape contents
        escaped => -> %prm, $tmpl {
            %prm<contents>.Str.trans(
               qw｢ <    >    &     "       `   ｣
            => qw｢ &lt; &gt; &amp; &quot;  ``  ｣
            )
        },
        #| renders =code blocks
        code => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            PStr.new: $del ~ "\n```\n"
            ~ %prm<contents>
            ~ "\n```\n"
        },
        #| renders implicit code from an indented paragraph
        implicit-code => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            PStr.new: $del ~ "\n```\n"
            ~ %prm<contents>
            ~ "\n```\n"
        },
        #| renders =input block
        input => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            PStr.new: $del ~ "\n```\n  --- input --- \n"
            ~ %prm<contents>
            ~ "\n```\n"
        },
        #| renders =output block
        output => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            PStr.new: $del ~ "\n```\n  --- output --- \n"
            ~ %prm<contents>
            ~ "\n```\n"
         },
        #| renders =comment block
        comment => -> %prm, $tmpl { '' },
        #| renders =formula block
        formula => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            "\n\n" ~ "----\n" ~
            $del ~ "\n" ~
            '#' x %prm<level>  ~ ' ' ~ %prm<caption> ~ qq[<div id="{ %prm<target> }"> </div>] ~ "\n\n" ~
            %prm<formula> ~ "\n\n"
        },
        #| renders =head block
        head => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            # using level + 1 so that TITLE is always larger
            # a line above heading level one to separate sections
            ('----' if %prm<level> == 1) ~
            "\n" ~ $del ~ "\n" ~
            '#' x ( %prm<level> + 1)  ~ ' ' ~
            %prm<contents> ~ qq[<div id="{ %prm<target> }"> </div>] ~
            "\n"
        },
        #| renders =numhead block
        numhead => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            my $title = %prm<numeration> ~ ' ' ~ %prm<contents>;
            # using level + 1 so that TITLE is always larger
            # a line above heading level one to separate sections
            ('----' if %prm<level> == 1) ~
            "\n" ~ $del ~ "\n" ~
            '#' x ( %prm<level> + 1)  ~ ' ' ~
            $title ~ qq[<div id="{ %prm<target> }"> </div>] ~
            "\n"
        },
        #| renders the numeration part for a toc
        toc-numeration => -> %prm, $tmpl { %prm<contents> },
        #| rendering the content from the :delta option
        #| see inline variant markup-Δ
        delta => -> %prm, $tmpl {
            DEPR-TEXT-ON ~
            %prm<note> ~ DEPR-TEXT-OFF ~
            " for " ~
            DEPR-ON ~
            %prm<versions> ~ DEPR-OFF ~
            "\n\n"
        },#| renders =defn block
        defn => -> %prm, $tmpl {
            BOLD-ON ~ %prm<term> ~ BOLD-OFF ~ "  \n" ~
            "\t" ~ %prm<contents> ~ "\n\n"
        },
        #| renders =numdefn block
        #| special template to render a defn list data structure
        defn-list => -> %prm, $tmpl { "\n" ~ [~] %prm<defn-list> },
        #| special template to render a numbered defn list data structure
        numdefn => -> %prm, $tmpl {
            BOLD-ON ~ %prm<numeration> ~ ' ' ~ %prm<term> ~ BOLD-OFF ~ "  \n\n" ~
            "\t" ~ %prm<contents> ~ "\n\n"
        },
        #| special template to render a numbered item list data structure
        numdefn-list => -> %prm, $tmpl { "\n" ~ [~] %prm<numdefn-list> },
        #| renders =item block
        item => -> %prm, $tmpl {
            my $num = %prm<level> - 1;
            my $indent = '  ' x %prm<level>;
            $num = @bullets.elems - 1 if $num >= @bullets.elems;
            my $bullet = %prm<bullet> // '-';
            $indent ~ $bullet ~ ' ' ~ %prm<contents> ~ "  \n"
        },
        #| special template to render an item list data structure
        item-list => -> %prm, $tmpl {
            "\n" ~ [~] %prm<item-list>
        },
        #| renders =numitem block
        numitem => -> %prm, $tmpl {
            %prm<numeration> ~ ' ' ~ %prm<contents> ~ "  \n\n"
        },
        #| special template to render a numbered item list data structure
        numitem-list => -> %prm, $tmpl {
            "\n" ~ [~] %prm<numitem-list>
        },
        #| renders =nested block
        nested => -> %prm, $tmpl {
            PStr.new: "\t" ~ %prm<contents> ~ "\n\n"
        },
        #| renders =para block
        para => -> %prm, $tmpl { %prm<contents> ~ "\n\n" },
        #| renders =place block
        place => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            my $rv = PStr.new;
            $rv ~= $del ~ "\n";
            $rv ~= %prm<contents> ;
            $rv ~= "\n\n";
        },
        #| renders =rakudoc block
        rakudoc => -> %prm, $tmpl { %prm<contents> ~ "\n" }, #pass through without change
        #| renders =section block
        section => -> %prm, $tmpl {
            (%prm<delta> // '') ~
            %prm<contents> ~ "\n"
        },
        #| renders =SEMANTIC block, if not otherwise given
        semantic => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            # using level + 1 so that TITLE is always larger
            # a line above heading level one to separate sections
            ('----' if %prm<level> == 1) ~
            "\n" ~ $del ~ "\n" ~
            '#' x ( %prm<level> + 1)  ~ ' ' ~
            %prm<caption> ~ qq[<div id="{ %prm<target> }"> </div>] ~
            "\n" ~
            %prm<contents> ~ "\n\n"
        },
        #| renders =pod block
        pod => -> %prm, $tmpl { %prm<contents> },
        #| renders =table block
        table => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            # using level + 1 so that TITLE is always larger
            # a line above heading level one to separate sections
            my $rv = ('----' if %prm<level> == 1) ~
            "\n" ~ $del ~ "\n" ~
            '#' x ( %prm<level> + 1)  ~ ' ' ~
            %prm<caption> ~ qq[<div id="{ %prm<target> }"> </div>] ~
            "\n" ;
                if %prm<procedural> {
#                    # calculate column widths naively, will include possible markup, and
#                    # will fail if embedded tables
#                    # TODO comply with justification, now right-justify col-head, top-justify row labels.
#                    my @col-wids;
#                    my $wid;
#                    for %prm<grid>.list -> @row {
#                        for @row.kv -> $n, %cell {
#                            next if %cell<no-cell>;
#                            $wid = duospace-width(%cell<data>.Str) + 2;
#                            @col-wids[$n] = $wid if $wid > (@col-wids[$n] // 0)
#                        }
#                    }
#                    my $table-wid = (+@col-wids * 3) + 4 + [+] @col-wids;
#                    my @rendered-grid;
#                    my $col-count;
#                    for %prm<grid>.kv -> $r, @row {
#                        $col-count = 0;
#                        for @row.kv -> $n, %cell {
#                            next if %cell<no-cell>;
#                            my $data = %cell<data>.Str.trim;
#                            my $chars = duospace-width($data);
#                            my $col-wid = @col-wids[$n];
#                            if %cell<span>:exists {
#                                #for the col-span
#                                if %cell<span>[0] > 1 {
#                                    for ^( %cell<span>[0] - 1) {
#                                        $col-wid += @col-wids[ $n + $_ + 1] + 2
#                                    }
#                                }
#                                #for the row-span
#                                if %cell<span>[1] > 1 {
#                                    for ^ (%cell<span>[1] - 1 ) {
#                                        @rendered-grid[$r + $_ + 1][$n] ~= ' ' x $col-wid ~ ' |'
#                                    }
#                                }
#                            }
#                            my $pref = ( $col-wid - $chars ) div 2;
#                            my $post = $col-wid - $pref - $chars;
#                            @rendered-grid[ $r ][ $n ] ~=
#                                ' ' x $pref ~
#                                (%cell<header> || %cell<label> ?? BOLD-ON !! '') ~
#                                $data ~
#                                (%cell<header> || %cell<label> ?? BOLD-OFF !! '')
#                                ~ ' ' x $post ~ ' |';
#                        }
#                    }
#                    my $cap-shift = ( $table-wid - $cap-width ) div 2;
#                    my $row-shift = $cap-shift <= 0 ?? - $cap-shift !! 0;
#                    $cap-shift = 0 if $cap-shift <= 0;
#                    PStr.new: $del ~
#                        "\n" ~ ' ' x $cap-shift ~ $caption ~"\n" ~
#                        @rendered-grid.map({
#                        ' ' x $row-shift ~ '| ' ~ $_.grep( *.isa(Str) ).join('') ~ "\n"
#                        }).join('') ~ "\n\n"
#                   ;
                }
                else {
#                    my $cap-shift = (([+] %prm<headers>[0]>>.Str>>.chars) + (3 * +%prm<headers>[0]) + 4 - $cap-width ) div 2;
#                    my $row-shift = $cap-shift <= 0 ?? - $cap-shift !! 0;
#                    $cap-shift = 0 if $cap-shift <= 0;
#                    PStr.new: $del ~
#                        ' ' x $cap-shift ~
#                        $caption ~ "\n" ~
#                        ' ' x $row-shift ~
#                        '| ' ~ BOLD-ON ~ %prm<headers>[0].join( BOLD-OFF ~ ' | ' ~ BOLD-ON ) ~ BOLD-OFF ~ " |\n" ~
#                        %prm<rows>.map({
#                            ' ' x $row-shift ~
#                            '| ' ~ $_.join(' | ') ~ " |\n"
#                        }).join('') ~ "\n\n"
                }
        },
        #| renders =custom block
        custom => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            # using level + 1 so that TITLE is always larger
            # a line above heading level one to separate sections
            ('----' if %prm<level> == 1) ~
            "\n" ~ $del ~ "\n" ~
            '#' x ( %prm<level> + 1)  ~ ' ' ~
            %prm<caption> ~ qq[<div id="{ %prm<target> }"> </div>] ~
            "\n" ~
            %prm<raw> ~ "\n\n"
        },
        #| renders any unknown block minimally
        unknown => -> %prm, $tmpl {
            "----\n\n## " ~ qq[<div id="{ %prm<target> }">UNKNOWN { %prm<block-name> }</div>\n\n] ~
            $tmpl<escaped>
                .subst(/ \h\h /, '&nbsp;&nbsp;', :g)
                 .subst(/ \v /, '<br>', :g) ~
                 "\n\n"
        },
        #| special template to encapsulate all the output to save to a file
        final => -> %prm, $tmpl {
            "\n# " ~ %prm<title> ~ "\n\n" ~
            (%prm<subtitle> ?? ( '> ' ~ %prm<subtitle> ~ "\n\n" ) !! '') ~
            ( %prm<rendered-toc> if %prm<rendered-toc> ) ~
            %prm<body>.Str ~ "\n" ~
            %prm<footnotes>.Str ~ "\n" ~
            ( %prm<rendered-index> if %prm<rendered-index> ) ~
            "\n----\n\n----\n" ~
            "\nRendered from " ~ %prm<source-data><path> ~ '/' ~ %prm<source-data><name> ~
            (sprintf( " at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<modified>.DateTime) ~
            "\n\nSource last modified " ~ (sprintf( "at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<source-data><modified>.DateTime) ~
            "\n\n" ~
            ( %prm<warnings> if %prm<warnings>)
        },
        #| renders a single item in the toc
        toc-item => -> %prm, $tmpl {
            my $pref = ' ' x ( %prm<toc-entry><level> > 4 ?? 4 !! (%prm<toc-entry><level> - 1) * 2 )
                ~ (%prm<toc-entry><level> > 1 ?? '- ' !! '');
            PStr.new: qq[$pref\<a href="#{ %prm<toc-entry><target> }">{%prm<toc-entry><caption>}</a>   \n]
        },
        #| special template to render the toc list
        toc => -> %prm, $tmpl {
            PStr.new: "----\n\n## " ~ %prm<caption> ~ "\n" ~
            ([~] %prm<toc-list>) ~ "\n\n"
        },
        #| renders a single item in the index
        index-item => -> %prm, $tmpl {
            sub si( %h, $n ) {
                my $rv = '';
                for %h.sort( *.key )>>.kv -> ( $k, %v ) {
                    $rv ~= "  " x $n ~ "- $k : "
                        ~ %v<refs>.map({ qq[<a href="#{ .<target> }">{ .<place> }</a>] }).join(', ')
                        ~ "\n\n"
                        ~ si( %v<sub-index>, $n + 1 );
                }
                $rv
            }#qq[<div id="{ %prm<target> }"> </div>] ~
            PStr.new:
                INDEX-ENTRY-ON ~ %prm<entry> ~ INDEX-ENTRY-OFF ~ ':  ' ~
                %prm<entry-data><refs>.map({ qq[<a href="#{ .<target> }">{ .<place> }</a>] }).join(', ')
                ~ "\n\n"
                ~ si( %prm<entry-data><sub-index>, 1 );
        },
        #| special template to render the index data structure
        index => -> %prm, $tmpl {
            PStr.new: "----\n\n## " ~ %prm<caption> ~"\n" ~
            ([~] %prm<index-list>) ~ "\n\n"
        },
        #| special template to render the footnotes data structure
        footnotes => -> %prm, $tmpl {
            if %prm<footnotes>.elems {
            PStr.new: "----\n\n## Footnotes\n" ~
                %prm<footnotes>.map({
                    .<fnNumber> ~
                    qq[<a href="#{ .<retTarget> }"> |^| </a>] ~
                    .<contents>.Str
                }).join("\n") ~ "\n\n"
            }
            else { '' }
        },
        #| special template to render the warnings data structure
        warnings => -> %prm, $tmpl {
            if %prm<warnings>.elems {
                PStr.new: "\n\n----\n\n----\n\n## WARNINGS\n\n" ~
                %prm<warnings>.kv.map( -> $n, $val {
                    $n + 1 ~ ': ' ~ $tmpl( 'escaped', %( :contents( $val ) ) )
                }).join("\n\n") ~ "\n\n"
            }
            else { '' }
        },
        ## Markup codes with only display (format codes), no meta data allowed
        ## meta data via Config is allowed
        #| B< DISPLAY-TEXT >
        #| Basis/focus of sentence (typically rendered bold)
        markup-B => -> %prm, $ {
            BOLD-ON ~ %prm<contents> ~ BOLD-OFF
        },
        #| C< DISPLAY-TEXT >
        #| Code (typically rendered fixed-width)
        markup-C => -> %prm, $tmpl { CODE-ON ~ %prm<contents> ~ CODE-OFF },
        #| H< DISPLAY-TEXT >
        #| High text (typically rendered superscript)
        markup-H => -> %prm, $tmpl { SUPERSCR-ON ~ %prm<contents> ~ SUPERSCR-OFF },
        #| I< DISPLAY-TEXT >
        #| Important (typically rendered in italics)
        markup-I => -> %prm, $tmpl { ITALIC-ON ~ %prm<contents> ~ ITALIC-OFF },
        #| J< DISPLAY-TEXT >
        #| Junior text (typically rendered subscript)
        markup-J => -> %prm, $tmpl { SUBSCR-ON ~ %prm<contents> ~ SUBSCR-OFF },
        #| K< DISPLAY-TEXT >
        #| Keyboard input (typically rendered fixed-width)
        markup-K => -> %prm, $tmpl { KEYBOARD-ON ~ %prm<contents> ~ KEYBOARD-OFF },
        #| N< DISPLAY-TEXT >
        #| Note (text not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.))
        markup-N => -> %prm, $tmpl {
            PStr.new:
            qq[<a id="{ %prm<retTarget> }" href="#{ %prm<fnTarget> }">] ~
            FOOTNOTE-ON ~ '[ ' ~ %prm<fnNumber> ~ ' ]' ~ FOOTNOTE-OFF ~
            '</a>'
        },
        #| O< DISPLAY-TEXT >
        #| Overstrike or strikethrough
        markup-O => -> %prm, $tmpl { STRIKE-ON ~ %prm<contents> ~ STRIKE-OFF },
        #| R< DISPLAY-TEXT >
        #| Replaceable component or metasyntax
        markup-R => -> %prm, $tmpl { REPLACE-ON ~ %prm<contents> ~ REPLACE-OFF },
        #| S< DISPLAY-TEXT >
        #| Space characters to be preserved
        markup-S => -> %prm, $tmpl { %prm<contents> },
        #| T< DISPLAY-TEXT >
        #| Terminal output (typically rendered fixed-width)
        markup-T => -> %prm, $tmpl { TERMINAL-ON ~ %prm<contents> ~ TERMINAL-OFF },
        #| U< DISPLAY-TEXT >
        #| Unusual (typically rendered with underlining)
        markup-U => -> %prm, $tmpl { UNDERLINE-ON ~ %prm<contents> ~ UNDERLINE-OFF },
        #| V< DISPLAY-TEXT >
        #| Verbatim (internal markup instructions ignored)
        markup-V => -> %prm, $tmpl { %prm<contents> },

        ##| Markup codes, optional display and meta data

        #| A< DISPLAY-TEXT |  METADATA = ALIAS-NAME >
        #| Alias to be replaced by contents of specified V<=alias> directive
        markup-A => -> %prm, $tmpl { %prm<contents> },
        #| E< DISPLAY-TEXT |  METADATA = HTML/UNICODE-ENTITIES >
        #| Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> )
        markup-E => -> %prm, $tmpl { %prm<contents> },
        #| F< DISPLAY-TEXT |  METADATA = LATEX-FORM >
        #| Formula inline content ( F<ALT|LaTex notation> )
        markup-F => -> %prm, $tmpl { CODE-ON ~ %prm<formula> ~ CODE-OFF },
        #| L< DISPLAY-TEXT |  METADATA = TARGET-URI >
        #| Link ( L<display text|destination URI> )
        markup-L => -> %prm, $tmpl {
            LINK-TEXT-ON ~ %prm<link-label> ~ LINK-TEXT-OFF ~
            LINK-ON ~ %prm<target> ~ LINK-OFF
         },
        #| P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
        #| Placement link
        markup-P => -> %prm, $tmpl {
            given %prm<schema> {
                when 'defn' {
                    BOLD-ON ~ %prm<contents> ~ BOLD-OFF ~ "\n\n\x29DB  " ~
                    DEFN-TEXT-ON ~ %prm<defn-expansion> ~ DEFN-TEXT-OFF ~
                    "\n\x29DA"
                }
                default { %prm<contents> }
            }
        },

        ##| Markup codes, mandatory display and meta data
        #| D< DISPLAY-TEXT |  METADATA = SYNONYMS >
        #| Definition inline ( D<term being defined|synonym1; synonym2> )
        markup-D => -> %prm, $tmpl {  BOLD-ON ~ %prm<contents> ~ BOLD-OFF },
        #| Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
        #| Delta note ( Δ<visible text|version; Notification text> )
        markup-Δ => -> %prm, $tmpl {
            DEPR-TEXT-ON ~ %prm<meta> ~ DEPR-TEXT-OFF ~
            DEPR-ON ~ '[ for ' ~ %prm<contents> ~ ']' ~ DEPR-OFF
        },
        #| M< DISPLAY-TEXT |  METADATA = WHATEVER >
        #| Markup extra ( M<display text|functionality;param,sub-type;...>)
        markup-M => -> %prm, $tmpl { CODE-ON ~ %prm<contents> ~ CODE-OFF },
        #| X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
        #| Index entry ( X<display text|entry,subentry;...>)
        markup-X => -> %prm, $tmpl {
            qq[<span id="{ %prm<target> }">] ~
            INDEXED-ON ~ %prm<contents> ~ INDEXED-OFF ~
            '</span>'
        },
        #| Unknown markup, render minimally
        markup-bad => -> %prm, $tmpl { BAD-MARK-ON ~ $tmpl<escaped> ~ BAD-MARK-OFF },
    ); # END OF TEMPLATES (this comment is to simplify documentation generation)
}