use experimental :rakuast;
use RakuDoc::Render;
use RakuDoc::PromiseStrings;
use RakuAST::Deparse::Highlight;

class HTML::Processor is RakuDoc::Processor {
    ## A set of methods to generate anchors / targets
    ## Output formats, eg. MarkDown and HTML, have different
    ## criteria. HTML rendering of Raku documentation has its
    ## own legacy algorithms
    ## So, different methods are used for
    ## - names (blocks) to be included in ToC, which needs to target the block
    ## - footnotes
    ## - indexed text, where Raku HTML has anchors that depend on context and meta
    ## - external links to other documents, which do not have to be unique

    multi method escape( Str:D $s ) {
        # will not double escape
        $s.trans(qw｢ &lt; &gt; & " > < ｣ => qw｢ &lt; &gt; &amp; &quot; &gt; &lt;｣)
    }
    #| Stringify if not string
    multi method escape( $s ) { self.escape( $s ?? $s.Str !! '' ) }
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
        return self.register-target($target) if $.is-target-unique($target);
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
        return self.register-target($target) if $.is-target-unique($target);
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
        self.mangle($ast.Str.trim)
    }
}

class RakuDoc::To::HTML {
    has HTML::Processor $.rdp .=new(:output-format<html>);

    submethod TWEAK {
        $!rdp.add-templates( self.html-templates, :source<RakuDoc::To::HTML> );
        my $css;
        if 'resources/css/vanilla.css'.IO ~~ :e & :f { # use local value if available
            $css = 'resources/css/vanilla.css'.IO.slurp;
        }
        else {
            $css = %?RESOURCES<css/vanilla.css>.slurp(:close)
        }
        $!rdp.add-data('css', $css);
        $!rdp.debug( %*ENV<RAKURENDEROPTS>.list ) if %*ENV<RAKURENDEROPTS>:exists
    }
    method render($ast) {
        my $fn = $*PROGRAM;
        my %source-data = %(
            name     => ~$fn,
            modified => $fn.modified,
            path     => $fn.dirname,
        );
        my $r2html = self.new;
        my $rdp := $r2html.rdp;
        if %*ENV<MORE_HTML>:exists {
            exit note( "｢{%*ENV<MORE_HTML>}｣ is not a file" ) unless %*ENV<MORE_HTML>.IO ~~ :e & :f;
            try {
                $rdp.add-templates( EVALFILE( %*ENV<MORE_HTML> ), :source<User-supplied-markdown> );
                CATCH {
                    default { exit note "Could not utilise ｢{%*ENV<MORE_HTML>}｣ " ~ .message }
                }
            }
        }
        if %*ENV<ALT_CSS>:exists {
            exit note( "｢{%*ENV<ALT_CSS>}｣ is not a file" ) unless %*ENV<ALT_CSS>.IO ~~ :e & :f;
            $rdp.add-data('css', %*ENV<ALT_CSS>.IO.slurp);
        }
        $rdp.render( $ast, :%source-data  )
    }

    # no post processing needed
    method postprocess( $final ) { $final };

    method html-templates {
        my constant BASIS-ON = '<span class="basis">';
        my constant BASIS-OFF = '</span>';
        my constant IMPORTANT-ON = '<span class="important">';
        my constant IMPORTANT-OFF = '</span>';
        my constant UNUSUAL-ON = '<span class="unusual">';
        my constant UNUSUAL-OFF = '</span>';
        my constant CODE-ON = '<span class="code">';
        my constant CODE-OFF = '</span>';
        my constant OVERSTRIKE-ON = '<span class="overstrike">';
        my constant OVERSTRIKE-OFF = '</span>';
        my constant HIGH-ON = '<span class="high">';
        my constant HIGH-OFF = '</span>';
        my constant JUNIOR-ON = '<span class="junior">';
        my constant JUNIOR-OFF = '</span>';
        my constant REPLACE-ON = '<span class="replace">';
        my constant REPLACE-OFF = '</span>';
        my constant KEYBOARD-ON = '<span class="keyboard">';
        my constant KEYBOARD-OFF = '</span>';
        my constant TERMINAL-ON = '<span class="terminal">';
        my constant TERMINAL-OFF = '</span>';
        my constant FOOTNOTE-ON = '<span class="footnote">';
        my constant FOOTNOTE-OFF = '</span>';
        my constant DEVEL-TEXT-ON = '<span class="developer-text">';
        my constant DEVEL-TEXT-OFF = '</span>';
        my constant DEVEL-VERSION-ON = '<span class="developer-version">';
        my constant DEVEL-VERSION-OFF = "</span>";
        my constant DEVEL-NOTE-ON = '<span class="developer-note">';
        my constant DEVEL-NOTE-OFF = "</span>";
        my constant DEFN-TEXT-ON = '<div class="defn-text">';
        my constant DEFN-TEXT-OFF = '</div>';
        my constant DEFN-TERM-ON = '<div class="defn-term">';
        my constant DEFN-TERM-OFF = '</div>';
        my constant BAD-MARK-ON = '<span class="bad-markdown">';
        my constant BAD-MARK-OFF = '</span>';
        my @bullets = <<\x2022 \x25b9 \x2023 \x2043 \x2219>> ;
        my regex spantab { '<' \/? 'span' <-[>]>* '>'};
        %(
            #| special key to name template set
            _name => -> %, $ { 'markdown templates' },
            #| escape contents of code block, which may contain <span ...> & </span> tabs, not to be escaped
            escape-code => -> %prm, $tmpl {
                my $cont = %prm<contents>.Str // '';
                if $cont ~~ / <spantab> / {
                    ( $cont ~~ / ^ [ .*? <spantab> ]+ .*? $ / )
                    .chunks
                    .map({
                        $tmpl.globals.escape.( .value ) if .key eq '~';
                        .value
                    })
                    .join
                }
                else { $tmpl.globals.escape.( $cont ) }
            },
            #| renders =code blocks
            code => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                PStr.new: ('<div class="delta">' ~ $del if $del) ~
                q[<pre class="code-block">] ~
                $tmpl<escape-code> ~
                "\n</pre>\n" ~
                (</div> if $del)
            },
            #| renders =input block
            input => -> %prm, $tmpl {
                %prm<html-tags> = True;
                my $del = %prm<delta> // '';
                PStr.new: q[<pre class="input-block">] ~
                $del ~
                $tmpl<escape-code> ~
                "\n</pre>\n"
            },
            #| renders =output block
            output => -> %prm, $tmpl {
                %prm<html-tags> = True;
                my $del = %prm<delta> // '';
                PStr.new: q[<pre class="output-block">] ~
                $del ~
                $tmpl<escape-code> ~
                "\n</pre>\n"
            },
            #| renders =comment block
            comment => -> %prm, $tmpl { '' },
            #| renders =formula block
            formula => -> %prm, $tmpl {
                my $level = %prm<headlevel> // 1;
                my $head = $tmpl('head', %(:$level, :id(%prm<id>), :target(%prm<target>), :caption(%prm<caption>), :delta(%prm<delta>)));
                PStr.new: $head ~ qq[[<div class="formula">{%prm<formula>}</div>]]
            },
            #| renders =head block
            head => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                my $classes = ( %prm<classes> // "heading" ) ~ ( 'delta' if $del ) ;
                my $h = 'h' ~ (%prm<level> // '1');
                my $caption = %prm<caption>.split(/ \< ~ \> <-[>]>+? /).join.trim;
                $caption = "%prm<numeration> $caption" if %prm<numeration>;
                my $targ := %prm<target>;
                my $esc-cap = $tmpl.globals.escape.( $caption );
                $esc-cap = '' if ($caption eq $targ or $esc-cap eq $targ);
                my $id-target = %prm<id>:exists && %prm<id>
                    ?? qq[[\n<div class="id-target" id="{ $tmpl.globals.escape.(%prm<id>) }"></div>]]
                    !! '';
                PStr.new:
                    $id-target ~
                    ( $esc-cap ?? qq[[\n<div class="id-target" id="$esc-cap"></div>]] !! '') ~
                    qq[[<$h id="$targ" class="$classes {'delta' if $del}">]] ~
                    ($del if $del) ~
                    ($caption ?? (
                    qq[[<a href="#" title="go to top of document">]] ~
                    $caption ~
                    qq[[</a><a class="raku-anchor" title="direct link" href="#{$esc-cap.so ?? $esc-cap !! $targ}">§\</a>]] ~
                    qq[[</$h>\n]]
                    ) !! '')
            },
            #| renders =numhead block
            numhead => -> %prm, $tmpl { $tmpl<head> },
            #| renders the numeration part for a toc
            toc-numeration => -> %prm, $tmpl { %prm<contents> },
            #| rendering the content from the :delta option
            #| see inline variant markup-Δ
            delta => -> %prm, $tmpl {
                DEVEL-VERSION-ON ~ %prm<versions> ~
                ( %prm<note> ??
                       DEVEL-NOTE-ON ~ %prm<note> ~ DEVEL-NOTE-OFF
                    !! ''
                ) ~
                DEVEL-VERSION-OFF ~
                "\n\n"
            },#| renders =defn block
            defn => -> %prm, $tmpl {
                PStr.new: DEFN-TERM-ON ~ %prm<term> ~ DEFN-TERM-OFF ~ "\n\n" ~
                DEFN-TEXT-ON ~ %prm<contents> ~ DEFN-TEXT-OFF ~ "\n\n"
            },
            #| renders =numdefn block
            #| special template to render a defn list data structure
            defn-list => -> %prm, $tmpl { "\n" ~ [~] %prm<defn-list> },
            #| special template to render a numbered defn list data structure
            numdefn => -> %prm, $tmpl {
                PStr.new: DEFN-TERM-ON ~ %prm<numeration> ~ '&nbsp;' ~ %prm<term> ~ DEFN-TERM-OFF ~ "\n\n" ~
                DEFN-TEXT-ON ~ %prm<contents> ~ DEFN-TEXT-OFF ~ "\n\n"
            },
            #| special template to render a numbered item list data structure
            numdefn-list => -> %prm, $tmpl { "\n" ~ [~] %prm<numdefn-list> },
            #| renders =item block
            item => -> %prm, $tmpl {
                my $n = %prm<level> - 1;
                $n = @bullets.elems - 1 if $n >= @bullets.elems;
                my $bullet = %prm<bullet> // @bullets[$n];
                qq[<li class="item" data-bullet="$bullet" style="--level:$n;"> {%prm<contents>}</li>\n]
            },
            #| special template to render an item list data structure
            item-list => -> %prm, $tmpl {
                "\n<ul class=\"item-list\">" ~ ([~] %prm<item-list>) ~ "</ul>\n"
            },
            #| renders =numitem block
            numitem => -> %prm, $tmpl {
                my $n = %prm<level> - 1;
                qq[<li class="item" data-bullet="{%prm<numeration>}" style="--level:$n;"> {%prm<contents>}</li>\n]
            },
            #| special template to render a numbered item list data structure
            numitem-list => -> %prm, $tmpl {
                "\n<ol class=\"item-list\">" ~ ([~] %prm<numitem-list>) ~ "</ol>\n"
            },
            #| renders =nested block
            nested => -> %prm, $tmpl {
                PStr.new: '<div class="nested">' ~ %prm<contents> ~ "</div>\n"
            },
            #| renders =para block
            para => -> %prm, $tmpl {
                if %prm<is-in-head> {
                    PStr.new: %prm<contents>
                }
                else {
                    PStr.new: '<p' ~
                        (%prm<target> ?? ' id="' ~ %prm<target> ~ '"' !! '') ~
                    '>' ~ %prm<contents> ~ "</p>\n"
                }
            },
            #| renders =place block
            place => -> %prm, $tmpl {
                my $level = %prm<headlevel> // 1;
                my $rv = $tmpl('head', %(:$level, :id(%prm<id>), :target(%prm<target>), :caption(%prm<caption>), :delta(%prm<delta>)));
                given %prm<content-type> {
                    when .contains('text') {
                        $rv ~= %prm<contents>
                    }
                    when .contains('image') {
                        my $alt = '';
                        $alt = qq[ alt="$_" title="$_"] with %prm<alt>;
                        $rv ~= qq[<div class="rakudoc-image-placement">
                            <img src="{ %prm<uri> }"$alt><div>{ %prm<caption> }</div></img></div> ]
                    }
                    default {
                        $rv ~= qq[<div class="rakudoc-placement-error"><p>Placement of {%prm<content-type>} is not yet implemented or requires internet connection</p></div> ]
                    }
                }
                $rv ~= "\n\n";
            },
            #| renders =rakudoc block
            rakudoc => -> %prm, $tmpl { %prm<contents> ~ "\n" }, #pass through without change
            #| renders =section block
            section => -> %prm, $tmpl {
                qq[<div class="rakudoc-section { 'delta' if %prm<delta>}">] ~
                %prm<delta> ~
                %prm<contents> ~ "\n</div>\n"
            },
            #| renders =SEMANTIC block, if not otherwise given
            semantic => -> %prm, $tmpl {
                my $level = %prm<headlevel> // 1;
                my $head = $tmpl('head', %(:$level, :id(%prm<id>), :target(%prm<target>), :caption(%prm<caption>), :delta(%prm<delta>)));

                ( $head unless %prm<hidden> ) ~
                %prm<contents> ~ "\n\n"
            },
            #| renders =pod block
            pod => -> %prm, $tmpl { %prm<contents> },
            #| renders =table block
            table => -> %prm, $tmpl {
                my $classes = ( %prm<classes> // "table" );
                my $del = %prm<delta> // '';
                my $rv = PStr.new: $del;
                $rv ~= qq[<div id="{%prm<target>}"></div>\n] if %prm<target>:exists and %prm<target>;
                $rv ~= '<table class="' ~ $classes ~ '">';
                $rv ~= qq[<caption>{%prm<caption>}</caption>] if %prm<caption>;
                if %prm<procedural> {
                    $rv ~= '<tbody class="procedural">';
                    for %prm<grid>.list -> @row {
                        $rv ~= "\n<tr class=\"procedural\">";
                        for @row -> $cell {
                            next if $cell<no-cell>;
                            my $content;
                            $content ~= ' colspan="' ~ $cell<span>[0] ~'"' if $cell<span>:exists and $cell<span>[0] != 1;
                            $content ~= ' rowspan="' ~ $cell<span>[1] ~'"' if $cell<span>:exists and $cell<span>[1] != 1;
                            $content ~= ' class="';
                            with $cell<align> { for .list {
                                $content ~= "procedural-cell-$_ "
                            } }
                            $content ~= 'procedural-cell-label' if $cell<label>;
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
                    $rv ~= "\n</tbody>"
                }
                else {
                    $rv ~= "\t<thead>\n\t\t<tr><th>" ~ $_>>.trim.join( '</th><th>') ~ "</th></tr>\n\t</thead>"
                        with %prm<headers>.head;
                    $rv ~= "\t<tbody>\n\t\t";
                    $rv ~= [~] %prm<rows>.map({ '<tr><td>' ~ .map(*.trim).join('</td><td>') ~ "</td></tr>\n\t\t" });
                    $rv ~= "\t</tbody>\n";
                }
                $rv ~= "</table>\n"
            },
            #| renders any unknown block minimally
            unknown => -> %prm, $tmpl {
                my $level = %prm<headlevel> // 1;
                my $contents = qq[UNKNOWN { %prm<block-name> }];
                my $head = $tmpl('head', %(:$level, :id(%prm<id>), :target(%prm<target>), :caption("Unknown %prm<block-name>"), :$contents, :delta('')));
                PStr.new: $head ~ $tmpl.globals.escape.(%prm<contents>)
                        .subst(/ \h\h /, '&nbsp;&nbsp;', :g)
                        .subst(/ \v /, '<br>', :g) ~
                         "\n\n"
            },
            #| Version numbers should appear on the same line as the heading
            VERSION => -> %prm, $tmpl {
                my $level = %prm<headlevel> // 1;
                my $content := %prm<contents>.Str;
                my $head = $tmpl('head', %(
                    :$level, :id(%prm<id>), :target(%prm<target>),
                    :caption(%prm<caption> ~ '&nbsp' x 4 ~  $content ),
                    :delta(%prm<delta>)
                ));
                if %prm<hidden> { qq| <div class="rakudoc-version">$content\</div> | }
                else { $head }
            },
            #| renders a single item in the toc
            toc-item => -> %prm, $tmpl {
                my $n = %prm<toc-entry><level> > 3 ?? 3 !! (%prm<toc-entry><level> - 1);
                my $pref = qq[<div class="toc-item" style="--level:$n;" data-bullet="{ $n ?? @bullets[$n] !! '' }">];
                PStr.new: qq[$pref\<a href="#{ %prm<toc-entry><target> }">{%prm<toc-entry><caption>.split(/ \< ~ \> <-[>]>+? /).join}</a></div>\n]
            },
            #| special template to render the toc list
            toc => -> %prm, $tmpl {
                if %prm<toc>:exists && %prm<toc>.elems {
                    PStr.new: qq[<div class="toc">\n] ~
                    ( "<h2 class=\"toc-caption\">%prm<caption>\</h2>" if  %prm<caption> ) ~
                    ([~] %prm<toc-list>) ~
                    "</div>\n"
                }
                else {
                    PStr.new: ''
                }
            },
            #| renders a single item in the index
            index-item => -> %prm, $tmpl {
            # expecting a level, and entry name, whether its in a heading, and
            # a list (possibly empty) of hashes with information for link(s)
                my $n = %prm<level>;
                my $rv =  qq[<div class="index-section" data-index-level="$n" style="--level:$n">\n] ~
                        '<span class="index-entry">' ~ %prm<entry> ~ '</span>';
                %prm<refs>.list
#                    .grep( .<is-in-heading>.not ) # do not render if in heading
                    .map({
                        $rv ~= qq[<a class="index-ref" href="#{ .<target> }">{
                            $tmpl.globals.escape.( .<place> )
                            }</a>]
                    });
                $rv ~= "\n</div>\n";
            },
            #| special template to render the index data structure
            index => -> %prm, $tmpl {
            say "@ $?LINE  html rend", %prm<index-list>;
                my @inds = %prm<index-list>.grep({ .isa(Str) || .isa(PStr) });
                if @inds.elems {
                    PStr.new: '<div class="index">' ~ "\n" ~
                    ( "<h2 class=\"index-caption\">%prm<caption>\</h2>" if  %prm<caption> ) ~
                    ([~] @inds ) ~ "\n</div>\n"
                }
                else { 'No indexed items' }
            },
            #| special template to render the footnotes data structure
            footnotes => -> %prm, $tmpl {
                if %prm<footnotes>.elems {
                    PStr.new: qq:to/FOOTNOTES/
                        <div class="footnotes">
                        <h2 class="footnote-caption">Footnotes</h2>
                        { [~] %prm<footnotes>.map({
                            PStr.new:
                                '<div class="footnote">' ~ .<fnNumber> ~
                                '<a id="' ~ .<fnTarget> ~
                                '" href="#' ~ .<retTarget> ~
                                '"> |^| </a>' ~
                                 ~ .<contents>.Str ~
                                 ~ '</div>'
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
                        <div class="warnings">
                        <h2 class="warnings-caption">Warnings</h2>
                            <ol>
                            { [~] %prm<warnings>.map({
                                '<li>' ~ $tmpl.globals.escape.( $_ ) ~ "</li>\n"
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
                BASIS-ON ~ %prm<contents> ~ BASIS-OFF
            },
            #| C< DISPLAY-TEXT >
            #| Code (typically rendered fixed-width)
            markup-C => -> %prm, $tmpl { CODE-ON ~ $tmpl<escape-code> ~ CODE-OFF },
            #| H< DISPLAY-TEXT >
            #| High text (typically rendered superscript)
            markup-H => -> %prm, $tmpl { HIGH-ON ~ %prm<contents> ~ HIGH-OFF },
            #| I< DISPLAY-TEXT >
            #| Important (typically rendered in italics)
            markup-I => -> %prm, $tmpl { IMPORTANT-ON ~ %prm<contents> ~ IMPORTANT-OFF },
            #| J< DISPLAY-TEXT >
            #| Junior text (typically rendered subscript)
            markup-J => -> %prm, $tmpl { JUNIOR-ON ~ %prm<contents> ~ JUNIOR-OFF },
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
            markup-O => -> %prm, $tmpl { OVERSTRIKE-ON ~ %prm<contents> ~ OVERSTRIKE-OFF },
            #| R< DISPLAY-TEXT >
            #| Replaceable component or metasyntax
            markup-R => -> %prm, $tmpl { REPLACE-ON ~ %prm<contents> ~ REPLACE-OFF },
            #| S< DISPLAY-TEXT >
            #| Space characters to be preserved
            markup-S => -> %prm, $tmpl {
                $tmpl.globals.escape.(%prm<contents>)
                    .subst(/ \h\h /, '&nbsp;&nbsp;', :g)
                    .subst(/ \v /, '<br>', :g)
            },
            #| T< DISPLAY-TEXT >
            #| Terminal output (typically rendered fixed-width)
            markup-T => -> %prm, $tmpl { TERMINAL-ON ~ %prm<contents> ~ TERMINAL-OFF },
            #| U< DISPLAY-TEXT >
            #| Unusual (typically rendered with underlining)
            markup-U => -> %prm, $tmpl { UNUSUAL-ON ~ %prm<contents> ~ UNUSUAL-OFF },
            #| V< DISPLAY-TEXT >
            #| Verbatim (internal markup instructions ignored)
            markup-V => -> %prm, $tmpl {
                $tmpl<escape-code>
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
                my $target = %prm<target>.trim.subst(/ '.*' /, ".%prm<output-format>", :g);
                my $text = %prm<link-label>;
                given %prm<type> {
                    when 'local' {
                        if %prm<place>:exists {
                            qq[<a href="{$target}#%prm<place>">$text\</a>]
                        }
                        else {
                            qq[<a href="{$target}">$text\</a>]
                        }
                    }
                    when 'internal' {
                        qq[<a href="#{$target}">$text\</a>]
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
                    default {
                        given %prm<content-type> {
                            when .contains('text') {
                                %prm<contents>
                            }
                            when .contains('image') {
                                qq[<img src="{ %prm<uri> }">%prm<caption>\</img> ]
                            }
                            default {
                                qq[<p>Placement of {%prm<content-type>} is not yet implemented or requires internet connection</p> ]
                            }
                        }
                    }
                }
            },

            ##| Markup codes, mandatory display and meta data
            #| D< DISPLAY-TEXT |  METADATA = SYNONYMS >
            #| Definition inline ( D<term being defined|synonym1; synonym2> )
            markup-D => -> %prm, $tmpl {  BASIS-ON ~ %prm<contents> ~ BASIS-OFF },
            #| Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            #| Delta note ( Δ<visible text|version; Notification text> )
            markup-Δ => -> %prm, $tmpl {
                DEVEL-TEXT-ON ~ %prm<contents> ~
                DEVEL-VERSION-ON ~ %prm<versions> ~
                (%prm<note> ?? DEVEL-NOTE-ON ~ %prm<note> ~ DEVEL-NOTE-OFF !! '') ~
                DEVEL-VERSION-OFF ~ DEVEL-TEXT-OFF
            },
            #| M< DISPLAY-TEXT |  METADATA = WHATEVER >
            #| Markup extra ( M<display text|functionality;param,sub-type;...>)
            markup-M => -> %prm, $tmpl { CODE-ON ~ %prm<contents> ~ CODE-OFF },
            #| X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            #| Index entry ( X<display text|entry,subentry;...>)
            markup-X => -> %prm, $tmpl {
                my $contents = (%prm<contents> // '');
                if %prm<is-in-heading> {
#                    my $indexedheader = %prm<meta>.elems ?? %prm<meta>[0].join(';') !! $contents;
#                    '<span class="indexed-header" id="' ~ %prm<target> ~ '"' ~
#                    ( $indexedheader ?? (' data-indexedheader="' ~ $indexedheader ~ '">') !! '>' ) ~
                    $contents
#                    '</span>'
                }
                else {
                    my $index-text;
                    $index-text = %prm<meta>.map( { $_.elems ?? ( "\x2983" ~ $_.map({ "\x301a$_\x301b" }) ~ "\x2984") !! "\x301a$_\x301b" })
                        if %prm<meta>.elems;
                    '<span class="indexed" id="' ~ %prm<target> ~ '"' ~
                    ($index-text && $contents ?? (' data-index-text="' ~ $index-text ~ '">') !! '>') ~
                    $contents ~
                    '</span>'
                }
            },
            #| Unknown markup, render minimally
            markup-bad => -> %prm, $tmpl { BAD-MARK-ON ~ $tmpl.globals.escape.(%prm<contents>) ~ BAD-MARK-OFF },
            #| special template to encapsulate all the output to save to a file
            #| These sub-templates should allow sub-classes of RakuDoc::To::HTML
            #| to provide replacement templates on a more granular basis
            final => -> %prm, $tmpl {
                qq:to/PAGE/
                <!DOCTYPE html>
                <html { $tmpl<html-root> } >
                    <head>
                    <meta charset="UTF-8" />
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
            #| root section, what is placed in the html tab
            html-root => -> %prm, $tmpl {
                qq[lang="{%prm<source-data><language>}"]
            },
            #| head-block, what goes in the head tab
            head-block => -> %prm, $tmpl {
                qq:to/HEAD/
                    <title>{%prm<title>}</title>
                    {$tmpl.globals.data<css>:exists ??
                       '<style>' ~ $tmpl.globals.data<css> ~ '</style>'
                    !! ''
                    }
                HEAD
            },
            #| the first section of body, including navigation
            top-of-page => -> %prm, $tmpl {
                my $rv = '';
                if %prm<title-target>:exists and %prm<title-target> ne '' {
                    $rv ~= qq[<div id="{
                        $tmpl.globals.escape.( %prm<title-target> )
                    }"></div>]
                }
                $rv ~= '<h1 class="title">' ~ %prm<title> ~ "</h1>\n\n" ~
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
                    Rendered from<span class="footer-field">&nbsp;{%prm<source-data><path>}/{%prm<source-data><name>}</span>
                <span class="footer-field">{sprintf( "&nbsp;at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<modified>.DateTime }</span>
                <span class="footer-line">Source last modified {(sprintf( "at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<source-data><modified>.DateTime)}</span>
                { qq[<div class="warnings">%prm<warnings>\</div>] if %prm<warnings> }
                </div>
                FOOTER
            },
        ); # END OF TEMPLATES (this comment is to simplify documentation generation)
    }
}