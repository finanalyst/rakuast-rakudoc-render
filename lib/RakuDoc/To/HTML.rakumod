use experimental :rakuast;
use RakuDoc::Render;
use RakuDoc::PromiseStrings;

unit class RakuDoc::To::HTML;

method render($ast) {
    my $fn = $*PROGRAM;
    my %source-data = %(
        name     => ~$fn,
        modified => $fn.modified,
        path     => $fn.dirname
    );
    my $rdp = RakuDoc::Processor.new;
    $rdp.add-templates( $.html-templates, :source<RakuDoc::To::HTML> );
    if %*ENV<MORE_HTML>:exists {
        exit note( "｢{%*ENV<MORE_HTML>}｣ is not a file" ) unless %*ENV<MORE_HTML>.IO ~~ :e & :f;
        try {
            $rdp.add-templates( EVALFILE( %*ENV<MORE_HTML> ), :source<User-supplied-markdown> );
            CATCH {
                default { exit note "Could not utilise ｢{%*ENV<MORE_HTML>}｣ " ~ .message }
            }
        }
    }
    $rdp.render( $ast, :%source-data  )
}

# no post processing needed
method postprocess( $final ) { $final };

method html-templates {
    my constant BOLD-ON = "<strong>";
    my constant BOLD-OFF = "</strong>";
    my constant ITALIC-ON = "<i>";
    my constant ITALIC-OFF = "</i>";
    my constant UNDERLINE-ON = "<u>";
    my constant UNDERLINE-OFF = "</u>";
    my constant CODE-ON = "<code>";
    my constant CODE-OFF = "</code>";
    my constant STRIKE-ON = "<s>";
    my constant STRIKE-OFF = "</s>";
    my constant SUPERSCR-ON = "<sup>";
    my constant SUPERSCR-OFF = "</sup>";
    my constant SUBSCR-ON = "<sub>";
    my constant SUBSCR-OFF = "</sub>";
    my constant REPLACE-ON = '<span class="replace">';
    my constant REPLACE-OFF = '</span>';
    my constant INDEXED-ON = '<span class="indexed">';
    my constant INDEXED-OFF = '</span>';
    my constant INDEX-ENTRY-ON = '<span class="index-entry">';
    my constant INDEX-ENTRY-OFF = '</span>';
    my constant KEYBOARD-ON = '<span class="keyboard">';
    my constant KEYBOARD-OFF = '</span>';
    my constant TERMINAL-ON = '<span class="terminal">';
    my constant TERMINAL-OFF = '</span>';
    my constant FOOTNOTE-ON = "<sup>";
    my constant FOOTNOTE-OFF = "</sup>";
    my constant LINK-TEXT-ON = "<u>";
    my constant LINK-TEXT-OFF = "</u>";
    my constant DEVEL-TEXT-ON = '<span class="developer-text">';
    my constant DEVEL-TEXT-OFF = '</span>';
    my constant DEVEL-VERSION-ON = '<span class="developer-version">';
    my constant DEVEL-VERSION-OFF = "</span>";
    my constant DEVEL-NOTE-ON = '<span class="developer-note">';
    my constant DEVEL-NOTE-OFF = "</span>";
    my constant DEFN-TEXT-ON = '<div class="defn-text">';
    my constant DEFN-TEXT-OFF = '</div>';
    my constant DEFN-TERM-ON = '<div class="defn-term>';
    my constant DEFN-TERM-OFF = '</div>';
    my constant BAD-MARK-ON = '<span class="bad-markdown">';
    my constant BAD-MARK-OFF = '</span>';
    my @bullets = <<\x2022 \x25b9 \x2023 \x2043 \x2219>> ;
    %(
        #| special key to name template set
        _name => -> %, $ { 'markdown templates' },
        # escape contents
        escaped => -> %prm, $tmpl {
            if %prm<contents> {
                %prm<contents>.Str.trans(
                   qw｢ <    >    &     "       ｣
                => qw｢ &lt; &gt; &amp; &quot;  ｣
                )
            }
            else { '' }
        },
        #| renders =code blocks
        code => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            PStr.new: q[<div class="code-block">] ~
            $del ~
            %prm<contents> ~
            "\n</div>\n"
        },
        #| renders implicit code from an indented paragraph
        implicit-code => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            PStr.new: q[<div class="code-block">] ~
            $del ~
            %prm<contents> ~
            "\n</div>\n"
        },
        #| renders =input block
        input => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            PStr.new: q[<div class="input-block">] ~
            $del ~
            %prm<contents> ~
            "\n</div>\n"
        },
        #| renders =output block
        output => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            PStr.new: q[<div class="output-block">] ~
            $del ~
            %prm<contents> ~
            "\n</div>\n"
         },
        #| renders =comment block
        comment => -> %prm, $tmpl { '' },
        #| renders =formula block
        formula => -> %prm, $tmpl {
            my $title = %prm<caption>;
            my $h = 'h' ~ (%prm<level> // '1');
            my $targ = $tmpl('escaped', %(:contents(%prm<target>) ));
            qq[[\n<div class="raku-id-target" id="{ $tmpl('escaped', %(:contents(%prm<id>),)) }">]] ~
                qq[[<$h id="$targ" class="raku-$h">]] ~
                qq[[<a href="#{ $tmpl('escaped', %(:contents(%prm<top>), )) }" title="go to top of document">]] ~
                $title ~
                qq[[</a></$h>\n]] ~
                (%prm<delta> // '')
        },
        #| renders =head block
        head => -> %prm, $tmpl {
            my $h = 'h' ~ (%prm<level> // '1');
            my $title = %prm<contents>;
            my $targ = $tmpl('escaped', %(:contents(%prm<target>) ));
            qq[[\n<div class="raku-id-target" id="{ $tmpl('escaped', %(:contents(%prm<id>),)) }">]] ~
                qq[[<$h id="$targ" class="raku-$h">]] ~
                qq[[<a href="#{ $tmpl('escaped', %(:contents(%prm<top>), )) }" title="go to top of document">]] ~
                $title ~
                qq[[</a></$h>\n]] ~
                (%prm<delta> // '')
        },
        #| renders =numhead block
        numhead => -> %prm, $tmpl {
            my $title = %prm<numeration> ~ ' ' ~ %prm<contents>;
            my $h = 'h' ~ (%prm<level> // '1');
            my $targ = $tmpl('escaped', %(:contents(%prm<target>) ));
            qq[[\n<div class="raku-id-target" id="{ $tmpl('escaped', %(:contents(%prm<id>),)) }">]] ~
                qq[[<$h id="$targ" class="raku-$h">]] ~
                qq[[<a href="#{ $tmpl('escaped', %(:contents(%prm<top>), )) }" title="go to top of document">]] ~
                $title ~
                qq[[</a></$h>\n]] ~
                (%prm<delta> // '')
        },
        #| renders the numeration part for a toc
        toc-numeration => -> %prm, $tmpl { %prm<contents> },
        #| rendering the content from the :delta option
        #| see inline variant markup-Δ
        delta => -> %prm, $tmpl {
            ( %prm<note> ??
                   DEVEL-NOTE-ON ~ %prm<note> ~ DEVEL-NOTE-OFF
                !! ''
            ) ~
            DEVEL-VERSION-ON ~
            " for " ~
            %prm<versions> ~ DEVEL-VERSION-OFF ~
            "\n\n"
        },#| renders =defn block
        defn => -> %prm, $tmpl {
            DEFN-TERM-ON ~ %prm<term> ~ DEFN-TERM-OFF ~ "\n\n" ~
            DEFN-TEXT-ON ~ %prm<contents> ~ DEFN-TEXT-OFF ~ "\n\n"
        },
        #| renders =numdefn block
        #| special template to render a defn list data structure
        defn-list => -> %prm, $tmpl { "\n" ~ [~] %prm<defn-list> },
        #| special template to render a numbered defn list data structure
        numdefn => -> %prm, $tmpl {
            DEFN-TERM-ON ~ %prm<numeration> ~ %prm<term> ~ DEFN-TERM-OFF ~ "\n\n" ~
            DEFN-TEXT-ON ~ %prm<contents> ~ DEFN-TEXT-OFF ~ "\n\n"
        },
        #| special template to render a numbered item list data structure
        numdefn-list => -> %prm, $tmpl { "\n" ~ [~] %prm<numdefn-list> },
        #| renders =item block
        item => -> %prm, $tmpl {
#            my $num = %prm<level> - 1;
#            my $indent = '&nbsp;&nbsp;' x %prm<level>;
#            $num = @bullets.elems - 1 if $num >= @bullets.elems;
#            my $bullet = %prm<bullet> // @bullets[$num];
            qq[<li {
                    %prm<bullet>:exists ??
                        'style="list-style:' ~ %prm<bullet> ~ ';"'
                      !! ' '
                  }>{%prm<contents>}</li>\n]
        },
        #| special template to render an item list data structure
        item-list => -> %prm, $tmpl {
            "\n<ul>" ~ ([~] %prm<item-list>) ~ "</ul>\n"
        },
        #| renders =numitem block
        numitem => -> %prm, $tmpl {
            qq[<li>{%prm<contents>}</li>\n]
        },
        #| special template to render a numbered item list data structure
        numitem-list => -> %prm, $tmpl {
            "\n<ol>" ~ ([~] %prm<numitem-list>) ~ "</ol>\n"
        },
        #| renders =nested block
        nested => -> %prm, $tmpl {
            PStr.new: qq[<p class="nested"{
                %prm<target> ?? ' id="' ~ %prm<target> ~ '"' !! ''
            }>{%prm<contents>}</div>\n]
        },
        #| renders =para block
        para => -> %prm, $tmpl {
            PStr.new: qq[<p{
                %prm<target> ?? ' id="' ~ %prm<target> ~ '"' !! ''
            }>{%prm<contents>}</p>\n]
        },
        #| renders =place block
        place => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            my $rv = PStr.new;
            $rv ~= $del ~ "\n";
            $rv ~= qq[<div id="{ %prm<target> }"> </div>];
            $rv ~= qq[<div id="{ %prm<id> }"> </div>] if %prm<id>;
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
            my $h = 'h' ~ (%prm<level> // '1');
            my $title = %prm<caption>;
            my $targ = $tmpl('escaped', %(:contents(%prm<target>) ));
            qq[[\n<div class="raku-id-target" id="{ $tmpl('escaped', %(:contents(%prm<id>),)) }">]] ~
                qq[[<$h id="$targ" class="raku-$h">]] ~
                qq[[<a href="#{ $tmpl('escaped', %(:contents(%prm<top>), )) }" title="go to top of document">]] ~
                $title ~
                qq[[</a></$h>\n]] ~
                (%prm<delta> // '') ~
                %prm<contents> ~ "\n\n"
        },
        #| renders =pod block
        pod => -> %prm, $tmpl { %prm<contents> },
        #| renders =table block
        table => -> %prm, $tmpl {
            my $h = 'h' ~ (%prm<level> // '1');
            my $title = %prm<caption>;
            my $targ = $tmpl('escaped', %(:contents(%prm<target>) ));
            my $rv = PStr.new:
                qq[[\n<div class="raku-id-target" id="{ $tmpl('escaped', %(:contents(%prm<id>),)) }">]] ~
                    qq[[<$h id="$targ" class="raku-$h">]] ~
                    qq[[<a href="#{ $tmpl('escaped', %(:contents(%prm<top>), )) }" title="go to top of document">]] ~
                    $title ~
                    qq[[</a></$h>\n]] ~
                    (%prm<delta> // '') ~ '<table>';
            if %prm<procedural> {
                for %prm<grid>.list -> @row {
                    $rv ~= "\n<tr>";
                    for @row -> $cell {
                        next if $cell<no-cell>;
                        my $content;
                        $content ~= ' colspan="' ~ $cell<span>[0] ~'"' if $cell<span>:exists and $cell<span>[0] != 1;
                        $content ~= ' rowspan="' ~ $cell<span>[1] ~'"' if $cell<span>:exists and $cell<span>[1] != 1;
                        $content ~= ' class="';
                        with $cell<align> { for .list {
                            $content ~= "rakudoc-cell-$_ "
                        } }
                        $content ~= 'rakudoc-cell-label' if $cell<label>;
                        with $cell<data> { $content ~= '">' ~ $cell<data> }
                        else { $content ~= '">' }
                        if $cell<header> {
                            $rv ~= "<th$content\</th>"
                        }
                        else {
                            $rv ~= "<td$content\</td>"
                        }
                    }
                    $rv ~= "</tr>"
                }
            }
            else {
                $rv ~= "\t<thead>\n\t\t<tr><th>" ~ %prm<headers>[0]>>.trim.join( '</th><th>') ~ "</th></tr>\n\t</thead>" ;
                $rv ~= "\t<tbody>\n\t\t";
                $rv ~= [~] %prm<rows>.map({ '<tr><td>' ~ .map(*.trim).join('</td><td>') ~ "</td></tr>\n\t\t" });
                $rv ~= "\t</tbody>\n";
            }
            $rv ~= "</table>\n"
        },
        #| renders =custom block
        custom => -> %prm, $tmpl {
            my $h = 'h' ~ (%prm<level> // '1');
            my $title = %prm<caption>;
            my $targ = $tmpl('escaped', %(:contents(%prm<target>) ));
            qq[[\n<div class="raku-id-target" id="{ $tmpl('escaped', %(:contents(%prm<id>),)) }">]] ~
                qq[[<$h id="$targ" class="raku-$h">]] ~
                qq[[<a href="#{ $tmpl('escaped', %(:contents(%prm<top>), )) }" title="go to top of document">]] ~
                $title ~
                qq[[</a></$h>\n]] ~
                (%prm<delta> // '') ~
                %prm<raw> ~ "\n\n"
        },
        #| renders any unknown block minimally
        unknown => -> %prm, $tmpl {
            my $h = 'h' ~ (%prm<level> // '1');
            my $title = qq[UNKNOWN { %prm<block-name> }];
            my $targ = $tmpl('escaped', %(:contents(%prm<target>) ));
            qq[[\n<div class="raku-id-target" id="{ $tmpl('escaped', %(:contents(%prm<id>),)) }">]] ~
                qq[[<$h id="$targ" class="raku-$h">]] ~
                qq[[<a href="#{ $tmpl('escaped', %(:contents(%prm<top>), )) }" title="go to top of document">]] ~
                $title ~
                qq[[</a></$h>\n]] ~
                (%prm<delta> // '') ~
                $tmpl<escaped>
                    .subst(/ \h\h /, '&nbsp;&nbsp;', :g)
                    .subst(/ \v /, '<br>', :g) ~
                     "\n\n"
        },
        #| special template to encapsulate all the output to save to a file
        #| These sub-templates should allow sub-classes of RakuDoc::To::HTML
        #| to provide replacement templates on a more granular basis
        final => -> %prm, $tmpl {
            qq:to/PAGE/
            <!DOCTYPE html>
            <html { $tmpl<html-root> } >
                <head>
                { $tmpl<head-block> }
                </head>
                <body>
                { $tmpl<top-of-page> }
                { $tmpl<main-content> }
                { $tmpl<footer> }
            </body>
            </html>
            PAGE
        },
        ## sections of the final document
        #| root section, what does in the html tab
        html-root => -> %prm, $tmpl {
            qq[lang="{%prm<source-data><language>}"\n]
        },
        #| head-block, what goes in the head tab
        head-block => -> %prm, $tmpl {
            qq:to/HEAD/
                <title>{%prm<title>}</title>
            HEAD
        },
        #| the first section of body, including navigation
        top-of-page => -> %prm, $tmpl {
            my $rv = '';
            if %prm<title-target>:exists and %prm<title-target> ne '' {
                $rv ~= qq[<div id="{
                    $tmpl('escaped', %( :contents(%prm<title-target>), ))
                }"></div>]
            }
            $rv ~= %prm<title> ~ "\n\n" ~
            (%prm<subtitle> ?? ( "\t" ~ %prm<subtitle> ~ "\n\n" ) !! '') ~
            ( %prm<rendered-toc> if %prm<rendered-toc> )
        },
        #| the main section of body
        main-content => -> %prm, $tmpl {
            %prm<body>.Str ~
            %prm<footnotes>.Str ~ "\n" ~
            ( %prm<rendered-index> if %prm<rendered-index> )
        },
        #| the last section of body
        footer => -> %prm, $tmpl {
            qq:to/FOOTER/;
            \n<div class="footer">
                Rendered from <span class="footer-field">{%prm<source-data><path>}/{%prm<source-data><name>}</span>
            <span class="footer-field">{sprintf( " at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<modified>.DateTime }</span>
            <span class="footer-field>Source last modified {(sprintf( "at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<source-data><modified>.DateTime)}</span>
            { qq[<div class="warnings">%prm<warnings>\</div>] if %prm<warnings> }
            </div>
            FOOTER
        },
        #| renders a single item in the toc
        toc-item => -> %prm, $tmpl {
            PStr.new: qq[<a href="#{ %prm<toc-entry><target> }">{%prm<toc-entry><caption>}</a>]
        },
        #| special template to render the toc list
        toc => -> %prm, $tmpl {
            my $rv = qq[<div class="toc">{%prm<caption>}</div>];
            if %prm<toc>.defined and %prm<toc>.keys {
                $rv = "<ul class=\"menu-list\">\n";
                my $last-level = 1;
                for %prm<toc>.list -> %el {
                    my $lev = %el<level>;
                    given $last-level {
                        when $_ > $lev {
                            while $last-level > $lev {
                                $rv ~= "\n</ul>\n";
                                $last-level--;
                            }
                        }
                        when $_ < $lev {
                            while $lev > $last-level {
                                $last-level++;
                                $rv ~= "\n<ul>\n";
                            }
                        }
                    }
                    $rv ~= "\n<li>"
                        ~ '<a href="#'
                        ~ $tmpl('escaped', %( :contents(%el.<target>), ))
                        ~ '">'
                        ~ (%el.<text> // '')
                        ~ '</a></li>';
                }
                $rv ~= "\n</ul>\n";
            }
            $rv
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
            qq[<div class="index">
            <div class="index-caption">{%prm<caption>}</div>
            {[~] %prm<index-list>}
            </div>\n]
        },
        #| special template to render the footnotes data structure
        footnotes => -> %prm, $tmpl {
            if %prm<footnotes>.elems {
                qq:to/FOOTNOTES/
                    <div class="footnotes">
                    <div class="footnote-caption">Footnotes</div>
                    { [~] %prm<footnotes>.map({
                        qq:to/FOOTNOTE/
                            <div class="footnote">.<fnNumber>
                            <a id=".<fnTarget>" href="#{ .<retTarget> }"> |^| </a>
                            .<contents>.Str ~
                            </div>
                        FOOTNOTE
                    }) }
                    </div>
                FOOTNOTES
            }
            else { '' }
        },
        #| special template to render the warnings data structure
        warnings => -> %prm, $tmpl {
            if %prm<warnings>.elems {
                qq:to/WARNINGS/
                    <div class="footnotes">
                    <div class="footnote-caption">Warnings</div>
                        <ol>
                        { [~] %prm<warnings>.map({
                            '<li>' ~ $tmpl( 'escaped', %( :contents( $_ ) ) ) ~ "</li>\n"
                            })
                        }
                        </ol>
                    </div>
                WARNINGS
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
        markup-S => -> %prm, $tmpl {
            $tmpl<escaped>
                .subst(/ \h\h /, '&nbsp;&nbsp;', :g)
                .subst(/ \v /, '<br>', :g)
        },
        #| T< DISPLAY-TEXT >
        #| Terminal output (typically rendered fixed-width)
        markup-T => -> %prm, $tmpl { TERMINAL-ON ~ %prm<contents> ~ TERMINAL-OFF },
        #| U< DISPLAY-TEXT >
        #| Unusual (typically rendered with underlining)
        markup-U => -> %prm, $tmpl { UNDERLINE-ON ~ %prm<contents> ~ UNDERLINE-OFF },
        #| V< DISPLAY-TEXT >
        #| Verbatim (internal markup instructions ignored)
        markup-V => -> %prm, $tmpl {
            $tmpl<escaped>
                .subst(/ \h\h /, '&nbsp;&nbsp;', :g)
                .subst(/ \v /, '<br>', :g)
        },

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
            my $target = %prm<target>;
            my $text = %prm<link-label>;
            given %prm<type> {
                when 'local' {
                    if %prm<place>:exists {
                        qq[<a href="$target.html#%prm<place>">$text\</a>]
                    }
                    else {
                        qq[<a href="$target.html">$text\</a>]
                    }
                }
                when 'internal' {
                    qq[<a href="#$target">$text\</a>]
                }
                default {
                    qq[<a href="$target">$text\</a>]
                }
            }
        },
        #| P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
        #| Placement link
        markup-P => -> %prm, $tmpl {
            given %prm<schema> {
                when 'defn' {
                    "\n\n&#x2997;  " ~
                    DEFN-TEXT-ON ~ %prm<defn-expansion> ~ DEFN-TEXT-OFF ~
                    "\n&#x2998;"
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
            DEVEL-TEXT-ON ~ %prm<contents> ~ DEVEL-TEXT-OFF ~
            (%prm<note> ?? DEVEL-NOTE-ON ~ %prm<note> ~ DEVEL-NOTE-OFF !! '') ~
            DEVEL-VERSION-ON ~ %prm<versions> ~ DEVEL-VERSION-OFF
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