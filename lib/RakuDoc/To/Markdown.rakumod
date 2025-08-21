use experimental :rakuast;
use RakuDoc::Render;
use RakuDoc::PromiseStrings;

class MarkDown::Processor is RakuDoc::Processor {
    #| Escape characters in a string, needs to be over-ridden
    multi method escape( Str:D $s ) {
        # will not double escape
        $s.trans(
                   qw｢ ` < &lt;  ｣
                => qw｢ `` &lt; &lt; ｣
        )
    }
    #| Stringify if not string
    multi method escape( $s ) { self.escape( $s.Str ) }
    #| mangle an id to make sure it will be a valid id in the output
    method mangle( $s ) {
        self.escape( $s ).subst(/ \s /, '_', :g)
    }
    #| name-id takes an ast
    #| returns a unique Str to be used as an anchor / target
    #| Used by any name (block) that is placed in the ToC
    #| Also used for the main anchor in the text for a footnote
    #| Not called if an :id is specified in the source
    #| This method should be sub-classed by Renderers for different outputs
    #| renderers can use method is-target-unique to test for uniqueness
    method name-id($ast --> Str) {
        my $target = self.mangle($ast.Str.trim);
        return self.register-target($target) if self.is-target-unique($target);
        my @rejects = $target, ;
        # if plain target is rejected, then start adding a suffix
        $target ~= '_0';
        ++$target while $target ~~ any(@rejects);
        self.register-target($target);
    }

    #| Like name-id, index-id returns a unique Str to be used as a target
    #| Target should be unique
    #| Should be sub-classed by Renderers
    method index-id(:$context, :$contents, :$meta ) {
        my $target = 'index-entry-' ~ self.mangle($contents.Str.trim);
        return self.register-target($target) if self.is-target-unique($target);
        my @rejects = $target, ;
        # if plain target is rejected, then start adding a suffix
        $target ~= '_0';
        $target += 1 while $target ~~ any(@rejects);
        self.register-target($target);
    }

    #| Like name-id, local-heading returns a Str to be used as a target
    #| A local-heading is assumed to exist because specified by document author
    #| Should be sub-classed by Renderers
    method local-heading($ast) {
        self.escape($ast.Str.trim);
    }
}
class RakuDoc::To::Markdown {
    has MarkDown::Processor $.rdp .=new(:output-format<md>);

    submethod TWEAK {
        my $rdp := self.rdp;
        $rdp.add-templates( self.markdown-templates, :source<RakuDoc::To::Markdown> );

        #| the plugins to be attached to the processor
        #| the order of the plugins matters as templates names
        #| attached last are used first
        my @Markup-plugins = 'Graphviz' , ;
        $rdp.add-plugins( 'RakuDoc::Plugin::Markdown::' «~« @Markup-plugins );
    }

    method render($ast) {
        my $fn = $*PROGRAM;
        my %source-data = %(
            name     => ~$fn,
            modified => $fn.modified,
            path     => $fn.dirname
        );
        my $r2md = self.new;
        my $rdp := $r2md.rdp;
        if %*ENV<MORE_MARKDOWN>:exists {
            exit note( "｢{%*ENV<MORE_MARKDOWN>}｣ is not a file" ) unless %*ENV<MORE_MARKDOWN>.IO ~~ :e & :f;
            try {
                $rdp.add-templates( EVALFILE( %*ENV<MORE_MARKDOWN> ), :source<User-supplied-markdown> );
                CATCH {
                    default { exit note "Could not utilise ｢{%*ENV<MORE_MARKDOWN>}｣ " ~ .message }
                }
            }
        }
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
        my constant INDEXED-ON = '<span style="color:green; background-color: antiquewhite;">';
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
        my constant DEVEL-TEXT-ON = '<span style="background-color: #feb236;">';
        my constant DEVEL-TEXT-OFF = '</span>';
        my constant DEVEL-VERSION-ON = '<span style="color: white; background-color: #d64161;">';
        my constant DEVEL-VERSION-OFF = "</span>";
        my constant DEVEL-NOTE-ON = '<span style="color: white; background-color: #ff7b25;">';
        my constant DEVEL-NOTE-OFF = "</span>";
        my constant DEFN-TEXT-ON = '&nbsp;&nbsp;<span style="background-color: lightgrey;">';
        my constant DEFN-TEXT-OFF = '</span>';
        my constant DEFN-TERM-ON = '<span style="font-weight: 600; font-style: italic">';
        my constant DEFN-TERM-OFF = '</span>';
        my constant BAD-MARK-ON = "`";
        my constant BAD-MARK-OFF = "`";
        my @bullets = <<\x2022 \x25b9 \x2023 \x2043 \x2219>> ;
        %(
            #| special key to name template set
            _name => -> %, $ { 'markdown templates' },
            #| renders =code blocks
            code => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                PStr.new: $del ~ "\n```\n"
                ~ %prm<contents>.Str.trim-trailing
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
                my $level = %prm<headlevel> // 1;
                my $head = $tmpl('head', %(:$level, :id(%prm<id>), :target(%prm<target>), :caption(%prm<caption>), :delta(%prm<delta>)));
                PStr.new: $head ~ %prm<formula> ~ "\n\n"
            },
            #| renders =head block
            head => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                # using level + 1 so that TITLE is always larger
                my $h = '#' x ( %prm<level> + 1)  ~ ' ' ;
                my $caption = %prm<caption>.split(/ \< ~ \> <-[>]>+? /).join.trim;
                $caption = "%prm<numeration> $caption" if %prm<numeration>;
                my $targ := %prm<target>;
                my $esc-cap = $tmpl.globals.escape.( $caption );
                $esc-cap = '' if ($caption eq $targ or $esc-cap eq $targ);
                my $id-target = %prm<id>:exists && %prm<id>
                    ?? qq[[\n<div id="{ $tmpl.globals.escape.(%prm<id>) }"></div>]]
                    !! '';
                PStr.new:
                    $id-target ~
                    ( $esc-cap ?? qq[[\n<div id="$esc-cap"></div>]] !! '') ~
                    qq[[<div id="$targ"></div>]] ~
                    ($del if $del) ~ "\n\n" ~
                    $h ~ $caption ~ "\n"
            },
            #| renders =numhead block
            numhead => -> %prm, $tmpl { $tmpl<head> },
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
                DEFN-TERM-ON ~ %prm<numeration> ~ '&nbsp;' ~ %prm<term> ~ DEFN-TERM-OFF ~ "\n\n" ~
                DEFN-TEXT-ON ~ %prm<contents> ~ DEFN-TEXT-OFF ~ "\n\n"
            },
            #| special template to render a numbered item list data structure
            numdefn-list => -> %prm, $tmpl { "\n" ~ [~] %prm<numdefn-list> },
            #| renders =item block
            item => -> %prm, $tmpl {
                my $num = %prm<level> - 1;
                my $indent = '&nbsp;&nbsp;' x %prm<level>;
                $num = @bullets.elems - 1 if $num >= @bullets.elems;
                my $bullet = %prm<bullet> // @bullets[$num];
                $indent ~ $bullet ~ ' ' ~ %prm<contents>.trim ~ "  \n"
            },
            #| special template to render an item list data structure
            item-list => -> %prm, $tmpl {
                [~] %prm<item-list>
            },
            #| renders =numitem block
            numitem => -> %prm, $tmpl {
                %prm<numeration> ~ ' ' ~ %prm<contents> ~ "  \n\n"
            },
            #| special template to render a numbered item list data structure
            numitem-list => -> %prm, $tmpl {
                [~] %prm<numitem-list>
            },
            #| renders =nested block
            nested => -> %prm, $tmpl {
                PStr.new: '> ' ~
                    (%prm<target> ?? '<span class="nested" id="' ~ %prm<target> ~ '"></span>' !! '') ~
                    %prm<contents> ~ ("\n\n" unless %prm<inline>)
            },
            #| renders =para block
            para => -> %prm, $tmpl {
                if %prm<is-in-head> {
                    PStr.new: %prm<contents>
                }
                else {
                    PStr.new:
                        (%prm<target> ?? '<span class="para" id="' ~ %prm<target> ~ '"></span>' !! '') ~
                        %prm<contents> ~ ("  \n" unless %prm<inline>)
                }
            },
            #| renders =place block
            place => -> %prm, $tmpl {
                my $level = %prm<headlevel> // 1;
                my $rv = $tmpl('head', %(:$level, |( %prm<id target caption delta>:p )));
                given %prm<content-type> {
                    when .contains('text') {
                        $rv ~= %prm<contents>
                    }
                    when .contains('image') {
                        $rv ~=  '![' ~ %prm<caption> ~ '](' ~ %prm<uri> ~ ')'
                    }
                    default {
                        $rv ~= qq[Placement of {%prm<content-type>} is not yet implemented\n\n ]
                    }
                }
                $rv ~ "\n\n";
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
                my $level = %prm<headlevel> // 1;
                my $head = $tmpl('head', %(:$level, |( %prm<id target caption delta>:p )));

                ( $head unless %prm<hidden> ) ~
                %prm<contents> ~ "\n\n"
            },
            #| renders =pod block
            pod => -> %prm, $tmpl { %prm<contents> },
            #| renders =table block
            table => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                # using level + 1 so that TITLE is always larger
                # a line above heading level one to separate sections
                my $rv = PStr.new: $del ~ "\n";
                $rv ~= qq[<div id="{%prm<target>}"></div>\n] if %prm<target>:exists and %prm<target>;
                $rv ~= qq[<div>{%prm<caption>}</div>] if %prm<caption>;
                if %prm<procedural> {
                    # Markdown appears to only allow, but require one header row
                    # so insert header separator once after first row
                    my Bool $separator = False;
                    # counters for colspan
                    my $skip = 0;
                    my $prev = 0;
                    my $post = 0;
                    for %prm<grid>.list -> @row {
                        $rv ~= [~] gather for @row {
                            if .<no-cell> and $skip {
                                --$skip
                            }
                            elsif .<no-cell> {
                                take ' | &nbsp;'
                            }
                            else {
                                # only handle col-span
                                # row-span no-cell just replace with nbsp
                                with .<span> {
                                    if .[0] > 1 {
                                        $skip = .[0] - 1;
                                        $prev = $skip div 2;
                                        $post = $skip - $prev;
                                    }
                                }
                                take ' | ' ~ '&nbsp; | ' x $prev ~
                                    ( '**' if .<label> or .<header>) ~
                                    .<data>.trim ~
                                    ( '**' if .<label> or .<header>) ~
                                    ' | &nbsp;' x $post;
                                $prev = $post = 0
                            }
                        }
                        $rv ~= " |\n";
                        unless $separator {
                                $separator = True;
                                $rv ~= '| :---: ' x @row.elems ~ "|\n";
                        }
                    }
                }
                else {
                    $rv ~= '| **' ~ %prm<headers>[0]>>.trim.join( '** | **') ~ "** |\n" if %prm<headers>.elems;
                    $rv ~= [~] (( 1 .. %prm<headers>[0].elems ).map({ '| :----: ' })) ~ "|\n" if %prm<headers>.elems;
                    $rv ~= [~] %prm<rows>.map({ '| ' ~ .join(' | ') ~ " |\n" }) ~ "\n"
                }
                $rv
            },
            #| renders any unknown block minimally
            unknown => -> %prm, $tmpl {
                my $level = %prm<headlevel> // 1;
                my $contents = qq[UNKNOWN { %prm<block-name> }];
                my $head = $tmpl('head', %(:$level, :id(%prm<id>), :target(%prm<target>), :caption("Unknown %prm<block-name>"), :$contents, :delta('')));
                PStr.new: $head ~
                    "```\n" ~
                    $tmpl.globals.escape.( %prm<contents>.Str.trim-trailing ) ~
                    "\n```\n\n"
            },
            #| Version numbers should appear on the same line as the heading
            VERSION => -> %prm, $tmpl {
                my $level = %prm<headlevel> // 1;
                my $content := %prm<contents>.Str;
                my $head = $tmpl('head', %(
                    :$level, :id(%prm<id>), :target(%prm<target>),
                    :caption(%prm<caption> ~ '&nbsp;' x 4 ~  $content ),
                    :delta(%prm<delta>)
                ));
                if %prm<hidden> { qq| <div class="rakudoc-version">$content\</div> | }
                else { $head }
            },
            #| special template to encapsulate all the output to save to a file
            final => -> %prm, $tmpl {
                "\n# " ~ %prm<title> ~ "\n\n" ~
                (%prm<subtitle> ?? ( "\t" ~ %prm<subtitle> ~ "\n\n" ) !! '') ~
                ( %prm<rendered-toc> if %prm<rendered-toc> && %prm<source-data><rakudoc-config><toc> ) ~
                %prm<body>.Str ~ "\n" ~
                %prm<footnotes>.Str ~ "\n" ~
                ( %prm<rendered-index> if %prm<rendered-index> && %prm<source-data><rakudoc-config><index>) ~
                "\n----\n\n----\n" ~
                "\nRendered from " ~ %prm<source-data><path> ~ '/' ~ %prm<source-data><name> ~
                (sprintf( " at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<modified>.DateTime) ~
                "\n\nSource last modified " ~ (sprintf( "at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<source-data><modified>.DateTime) ~
                "\n\n" ~
                ( %prm<warnings> if %prm<warnings>)
            },
            #| renders a single item in the toc
            toc-item => -> %prm, $tmpl {
                my $pref = '&nbsp;' x ( %prm<toc-entry><level> > 3 ?? 3 !! (%prm<toc-entry><level> - 1) * 2 )
                    ~ (%prm<toc-entry><level> > 1 ?? '- ' !! '');
                PStr.new: qq[$pref\<a href="#{ %prm<toc-entry><target> }">{%prm<toc-entry><caption>}</a>   \n]
            },
            #| special template to render the toc list
            toc => -> %prm, $tmpl {
                if %prm<toc-list>:exists && %prm<toc-list>.elems {
                    my $cap = %prm<caption> ?? ("----\n\n## " ~ %prm<caption> ~ "\n\n") !! '';
                    PStr.new: $cap ~
                    ([~] %prm<toc-list>) ~ "\n\n"
                }
                else {
                    PStr.new: ''
                }
            },
            #| renders a single item in the index
            index-item => -> %prm, $tmpl {
                my $n = %prm<level>;
                my @refs = %prm<refs>.grep(*.isa(Hash)).grep( *.<is-in-heading>.not ).map({
                        qq[<a href="#{ .<target> }">{ .<place> }\</a>]
                    });
                if @refs.elems {
                    PStr.new:
                    ("&nbsp;&nbsp;&nbsp;" x $n - 1 ) ~ INDEX-ENTRY-ON ~ %prm<entry> ~ INDEX-ENTRY-OFF ~ ': ' ~
                    @refs.join(', ') ~
                    ~ "\n\n"
                }
                else { Nil }
            },
            #| special template to render the index data structure
            index => -> %prm, $tmpl {
                my @inds = %prm<index-list>.grep({ .isa(Str) || .isa(PStr) });
                if @inds.elems {
                    my $cap = %prm<caption> ?? ("----\n\n## " ~ %prm<caption> ~ "\n\n") !! '';
                    PStr.new: $cap ~
                    ([~] @inds ) ~ "\n\n"
                }
                else { PStr.new: 'No indexed items'  ~ "\n\n" }
            },
            #| special template to render the footnotes data structure
            footnotes => -> %prm, $tmpl {
                if %prm<footnotes>.elems {
                PStr.new: "----\n\n## Footnotes\n" ~
                    %prm<footnotes>.map({
                        .<fnNumber> ~
                        qq[<a id=".<fnTarget>" href="#{ .<retTarget> }"> |^| </a>] ~
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
                        $n + 1 ~ ': ' ~ $tmpl.globals.escape.( $val )
                    }).join("\n\n") ~ "\n\n"
                }
                else { '' }
            },
            ## Markup codes with only display (format codes), no meta data allowed
            ## meta data via Config is allowed
            #| B< DISPLAY-TEXT >
            #| Basis/focus of sentence (typically rendered bold)
            markup-B => -> %prm, $ {
                if %prm<in-code> { %prm<contents> }
                else { BOLD-ON ~ %prm<contents> ~ BOLD-OFF }
            },
            #| C< DISPLAY-TEXT >
            #| Code (typically rendered fixed-width)
            markup-C => -> %prm, $tmpl {
                if %prm<in-code> { %prm<contents> }
                else { CODE-ON ~ %prm<contents> ~ CODE-OFF }
            },
            #| H< DISPLAY-TEXT >
            #| High text (typically rendered superscript)
            markup-H => -> %prm, $tmpl {
				if %prm<in-code> { %prm<contents> }
				else { SUPERSCR-ON ~ %prm<contents> ~ SUPERSCR-OFF }
			},
            #| I< DISPLAY-TEXT >
            #| Important (typically rendered in italics)
            markup-I => -> %prm, $tmpl {
				if %prm<in-code> { %prm<contents> }
				else { ITALIC-ON ~ %prm<contents> ~ ITALIC-OFF }
			},
            #| J< DISPLAY-TEXT >
            #| Junior text (typically rendered subscript)
            markup-J => -> %prm, $tmpl {
				if %prm<in-code> { %prm<contents> }
				else { SUBSCR-ON ~ %prm<contents> ~ SUBSCR-OFF }
			},
            #| K< DISPLAY-TEXT >
            #| Keyboard input (typically rendered fixed-width)
            markup-K => -> %prm, $tmpl {
				if %prm<in-code> { %prm<contents> }
				else { KEYBOARD-ON ~ %prm<contents> ~ KEYBOARD-OFF }
			},
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
            markup-O => -> %prm, $tmpl {
				if %prm<in-code> { %prm<contents> }
				else { STRIKE-ON ~ %prm<contents> ~ STRIKE-OFF }
			},
            #| R< DISPLAY-TEXT >
            #| Replaceable component or metasyntax
            markup-R => -> %prm, $tmpl {
				if %prm<in-code> { %prm<contents> }
				else { REPLACE-ON ~ %prm<contents> ~ REPLACE-OFF }
			},
            #| S< DISPLAY-TEXT >
            #| Space characters to be preserved
            markup-S => -> %prm, $tmpl {
                $tmpl.globals.escape.( %prm<contents> )
                    .subst(/ \h\h /, '&nbsp;&nbsp;', :g)
                    .subst(/ \v /, '<br>', :g)
            },
            #| T< DISPLAY-TEXT >
            #| Terminal output (typically rendered fixed-width)
            markup-T => -> %prm, $tmpl {
				if %prm<in-code> { %prm<contents> }
				else { TERMINAL-ON ~ %prm<contents> ~ TERMINAL-OFF }
			},
            #| U< DISPLAY-TEXT >
            #| Unusual (typically rendered with underlining)
            markup-U => -> %prm, $tmpl {
				if %prm<in-code> { %prm<contents> }
				else { UNDERLINE-ON ~ %prm<contents> ~ UNDERLINE-OFF }
			},
            #| V< DISPLAY-TEXT >
            #| Verbatim (internal markup instructions ignored)
            markup-V => -> %prm, $tmpl {
                $tmpl.globals.escape.( %prm<contents> )
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
                my $target = %prm<target>.trim.subst(/ '.*' /, ".%prm<output-format>", :g);
                LINK-TEXT-ON ~ %prm<link-label> ~ LINK-TEXT-OFF ~
                LINK-ON ~ $target ~ LINK-OFF
             },
            #| P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            #| Placement link
            markup-P => -> %prm, $tmpl {
                my $rv = PStr.new;
                given %prm<content-type> {
                    when .contains('text') {
                        $rv ~= %prm<contents>
                    }
                    when .contains('image') {
                        $rv ~=  '![' ~ %prm<caption> ~ '](' ~ %prm<uri> ~ ')'
                    }
                    default {
                        $rv ~= qq[Placement of {%prm<content-type>} is not yet implemented\n\n ]
                    }
                }
                given %prm<schema> {
                    when 'defn' {
                        DEFN-TERM-ON ~ $rv ~ DEFN-TERM-OFF ~ "\n\x2997" ~
                        %prm<defn-expansion> ~
                        "\n\x2998"
                    }
                    default { $rv }
                }
            },

            ##| Markup codes, mandatory display and meta data
            #| D< DISPLAY-TEXT |  METADATA = SYNONYMS >
            #| Definition inline ( D<term being defined|synonym1; synonym2> )
            markup-D => -> %prm, $tmpl {  DEFN-TERM-ON ~ %prm<contents> ~ DEFN-TERM-OFF },
            #| Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            #| Delta note ( Δ<visible text|version; Notification text> )
            markup-Δ => -> %prm, $tmpl {
                DEVEL-TEXT-ON ~ %prm<contents> ~ DEVEL-TEXT-OFF ~
                (%prm<note> ?? DEVEL-NOTE-ON ~ %prm<note> ~ DEVEL-NOTE-OFF !! '') ~
                DEVEL-VERSION-ON ~ '[for ' ~ %prm<versions> ~ ']' ~ DEVEL-VERSION-OFF
            },
            #| M< DISPLAY-TEXT |  METADATA = WHATEVER >
            #| Markup extra ( M<display text|functionality;param,sub-type;...>)
            markup-M => -> %prm, $tmpl {
				if %prm<in-code> { %prm<contents> }
				else { CODE-ON ~ %prm<contents> ~ CODE-OFF }
			},
            #| X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            #| Index entry ( X<display text|entry,subentry;...>)
            markup-X => -> %prm, $tmpl {
                qq[<span id="{ %prm<target> }">] ~
                INDEXED-ON ~ %prm<contents> ~ INDEXED-OFF ~
                '</span>'
            },
            #| Unknown markup, render minimally
            markup-bad => -> %prm, $tmpl { BAD-MARK-ON ~ $tmpl.globals.escape.( %prm<contents> ) ~ BAD-MARK-OFF },
        ); # END OF TEMPLATES (this comment is to simplify documentation generation)
    }
}
