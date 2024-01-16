use experimental :rakuast;

use RakuDoc::Processed;
use RakuDoc::Templates;

#| ScopedData objects contain config, aliases, and definitions data that is scope limited
#| a new scope can be created with all the data of previous scope
#| when scope ends, new data is forgotten, old is restored
class ScopedData {
    has @!config = {}, ;
    has @!aliases = {}, ;
    has @!definitions = {}, ;
    has @!callees;
    #| debug information
    method debug {
        qq:to/DEBUG/;
        Levels: { +@!callees }
        Callees: { +@!callees ?? @!callees.join(' ') !! 'original level' }
        DEBUG
    }
    #| starts a new scope
    method start-scope(:$callee) {
        @!callees.push: $callee // 'not given';
        @!config.push: @!config[*-1].pairs.hash;
        @!aliases.push: @!aliases[*-1].pairs.hash;
        @!definitions.push: @!definitions[*-1].pairs.hash;
    }
    #| ends the current scope, forgets new data
    method end-scope() {
        @!callees.pop;
        @!config.pop;
        @!aliases.pop;
        @!definitions.pop;
    }
    multi method config(%h) {
        @!config[*-1]{ .key } = .value for %h;
    }
    multi method config( --> Hash ) {
        @!config[*-1]
    }
    multi method aliases(%h) {
        @!aliases[*-1]{ .key } = .value for %h;
    }
    multi method aliases( --> Hash ) {
        @!aliases[*-1]
    }
    multi method definitions(%h) {
        @!definitions[*-1]{ .key } = .value for %h;
    }
    multi method definitions( --> Hash ) {
        @!definitions[*-1]
    }
}

class RakuDoc::Processor {
    has %.templates is Template-directory;
    has Supplier::Preserving $.com-channel .= new;
    has RakuDoc::Processed $.current;
    has $.output-format;
    has ScopedData $!scoped-data .= new;

    multi submethod TWEAK(:$!output-format = 'txt', :$test = False ) {
        %!templates = $test ?? self.test-text-templates !! self.default-text-templates;
        %!templates.helper = self.text-helpers;
    }

    #| renders the $ast to a RakuDoc::Processed or String
    multi method render( $ast, :%source-data, :$stringify = False ) {
        $!current .= new(:%source-data, :$!output-format );
        # for multithreading this does not work
#        my @prs = $ast.rakudoc.map({ start $.handle($_) });
#        $!current += $_ for await @prs;
        my ProcessedState @prs = $ast.rakudoc.map({ $.handle($_) });
        $!current += $_ for @prs;
        return $.current unless $stringify;
        %!templates<source-wrap>( %( :processed( $!current ), )).Str
    }

    #| handle methods create a local version of $*prs, which is returned
    proto method handle(|c --> ProcessedState) {
        my ProcessedState $*prs .= new;
        {*}
    }
    multi method handle(Str:D $ast) {
        $*prs.body ~= $ast.trim;
        $*prs
    }
    multi method handle(RakuAST::Node:D $ast) {
        my ProcessedState @prs = $ast.rakudoc.map({ $.handle($_) });
        $*prs += $_ for @prs;
        $*prs
    }
            # =column
            # Start a new column in a procedural table

            # =row
            # Start a new row in a procedural table

            # =input
            # Pre-formatted sample input

            # =output
            # Pre-formatted sample output

            # =headN
            # Nth-level heading

            # =numhead
            # First-level numbered heading

            # =numheadN
            # Nth-level numbered heading

            # =defn
            # Definition of a term

            # =itemN
            # Nth-level list item

            # =numitem
            # First-level numbered list item

            # =numitemN
            # Nth-level numbered list item

            # =nested
            # Nest block contents within the current context

            # =formula
            # Render content as LaTex formula


    multi method handle(RakuAST::Doc::Block:D $ast) {
        # When a built in block, other than =item, is started,
        # there may be a list of items or defns, which need to be
        # completed and rendered
        $*prs.body ~= $.complete-item-list() unless $ast.type and $ast.type eq 'item';
        $*prs.body ~= $.complete-defn-list() unless $ast.type and $ast.type eq 'defn';

        # Not all Blocks create a new scope. Some change the current scope data
        given $ast.type {
            # =alias
            # Define a Pod macro
            when 'alias' { $.gen-alias($ast) }
            # =code
            # Verbatim pre-formatted sample source code
            when 'code' { $.gen-code($ast) }
            # =comment
            # Content to be ignored by all renderers
            when 'comment' { '' }
            # =config
            # Block scope modifications to a block or markup instruction
            when 'config' { $.manage-config($ast); }
            # =head
            # First-level heading
            when 'head' {
                $!scoped-data.start-scope(:callee($_));
                $.gen-head($ast);
                $!scoped-data.end-scope
            }
            when 'implicit-code' { $.gen-code($ast) }
            # =item
            # First-level list item
            when 'item' { $.gen-item($ast) }
            # =rakudoc
            # No "ambient" blocks inside
            when 'rakudoc' | 'pod' {
                $!scoped-data.start-scope(:callee($_));
                $.gen-rakudoc($ast);
                $!scoped-data.end-scope}
            # =pod
            # Legacy version of rakudoc
#           when 'pod' { '' } # when rakudoc differs from pod
            # =section
            # Defines a section
            when 'section' {
                $!scoped-data.start-scope(:callee($_));
                $.gen-section($ast);
                $!scoped-data.end-scope
            }
            # =table
            # Visual or procedural table
            when 'table' { $.gen-table($ast) }
            # RESERVED
            # Semantic blocks (SYNOPSIS, TITLE, etc.)
            when all($_.uniprops) ~~ / Lu / {
                # in RakuDoc v2 a Semantic block must have all uppercase letters
                $!scoped-data.start-scope(:callee($_));
                $.gen-semantics($ast);
                $!scoped-data.end-scope
            }
            # CustomName
            # User-defined block
            when any($_.uniprops) ~~ / Lu / and any($_.uniprops) ~~ / Ll / {
                # in RakuDoc v2 a Semantic block must have mix of uppercase and lowercase letters
                $!scoped-data.start-scope(:callee($_));
                $.gen-custom($ast);
                $!scoped-data.end-scope
            }
            default { $.gen-unknown-builtin($ast) }
        }
        $*prs
    }
    # =data
    # Raku data section
    multi method handle(RakuAST::Doc::DeclaratorTarget:D $ast) {
        #ignore declarator block
        $*prs
    }
    multi method handle(RakuAST::Doc::Markup:D $ast) {
        given $ast.letter {
            
            # A<...|...>
            # Alias to be replaced by contents of specified V<=alias> directive
            when 'A' {

            }

            # B<...>
            # Basis/focus of sentence (typically rendered bold)
            when 'B' {

            }

            # C<...>
            # Code (typically rendered fixed-width)
            when 'C' {

            }

            # D<...>
            # Definition inline (V<D<term being defined|synonym1; synonym2>>)
            when 'D' {

            }

            # Δ<...|...;...>>
            # Delta note (V<Δ<visible text|version; Notification text>>)
            when 'Δ' {

            }
            # E<...|...;...>
            # Entity (HTML or Unicode) description (V<E<entity1;entity2; multi,glyph;...>>)
            when 'E' {

            }

            # F<...|...>
            # Inline content for a formula (V<F<ALT|LaTex notation>>)
            when 'F' {

            }

            # G<...>
            # (This markup code is not yet defined, but is reserved for future use)
            when 'G' {

            }

            # H<...>
            # High text (typically rendered superscript)
            when 'H' {

            }

            # I<...>
            # Important (typically rendered in italics)
            when 'I' {

            }

            # J<...>
            # Junior text (typically rendered subscript)
            when 'J' {

            }

            # K<...>
            # Keyboard input (typically rendered fixed-width)
            when 'K' {

            }

            # L<...|...>
            # Link (V<L<display text|destination URI>>)
            when 'L' {

            }

            # M<...|..,..;...>
            # Markup extra (V<M<display text|functionality;param,sub-type;...>>)
            when 'M' {

            }

            # N<...>
            # Note (not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.))
            when 'N' {

            }

            # O<...>
            # Overstrike or strikethrough
            when 'O' {

            }

            # P<...|...>
            # Placement link
            when 'P' {

            }

            # Q<...>
            # (This markup code is not yet defined, but is reserved for future use)
            when 'Q' {

            }

            # R<...>
            # Replaceable component or metasyntax
            when 'R' {

            }

            # S<...>
            # Space characters to be preserved
            when 'S' {

            }

            # T<...>
            # Terminal output (typically rendered fixed-width)
            when 'T' {

            }

            # U<...>
            # Unusual (typically rendered with underlining)
            when 'U' {

            }

            # V<...>
            # Verbatim (internal markup instructions ignored)
            when 'V' {

            }

            # W<...>
            # (This markup code is not yet defined, but is reserved for future use)
#            when 'W' {
#
#            }

            # X<...|..,..;...>
            # Index entry (V<X<display text|entry,subentry;...>>)
            when 'X' {

            }

            # Y<...>
            # (This markup code is not yet defined, but is reserved for future use)
#            when 'Y' {
#
#            }

            # Z<...>
            # Zero-width comment (contents never rendered)
            when 'Z' {
                ''
            }
        }
        $*prs
    }
    # =para
    # Ordinary paragraph
    multi method handle(RakuAST::Doc::Paragraph:D $ast) {
        my ProcessedState @prs = $ast.atoms.map({ $.handle($_) });
        $*prs += $_ for @prs;
        $*prs
    }
    multi method handle(RakuAST::Doc::Row:D $ast) {
        self.handle($ast.WHICH.Str)
    }
    multi method handle(Cool:D $ast) {
        self.handle($ast.WHICH.Str)
    }
    #| gen-XX methods take an $ast and adds a string to $*prs.body
    #| based on a template
    method gen-alias($ast) {
        ''
    }
    method gen-code($ast) {
        ''
    }
    method gen-head($ast) {
        my $level = $ast.level > 1 ?? $ast.level !! 1;
        my $target = $.name-id($ast, :make-unique);
        $.register-target($target);
        my $contents = $.contents($ast);
        my %config = $.get-meta($ast);
        my %scoped-head = $!scoped-data.config;
        %config{ .key } = .value for %scoped-head{"head$level"}.pairs;
        $*prs.body ~= %!templates<head>(
            %( :state($*prs), :$level, :$target, :$contents, %config)
        )
    }
    method gen-item($ast) {
        ''
    }
    method gen-rakudoc($ast) {
        my %config = $.get-meta($ast);
        $!current.source-data<rakudoc-config> = %config;
        my $contents = $.contents($ast);
        $*prs.body ~= %!templates<rakudoc>( %( :$contents, %config ) )
    }
    method gen-section($ast) {
        my %config = $.get-meta($ast);
        my $contents = $.contents($ast);
        $*prs.body ~= %!templates<section>( %( :$contents, %config ) )
    }
    method gen-table($ast) {
        ''
    }
    method gen-unknown-built-in($ast) {
        ''
    }
    method gen-semantics($ast) {
        ''
    }
    method gen-custom($ast) {
        ''
    }
    # directive type methods
    method manage-config($ast) {
        my %options = $.get-meta($ast);
        my $name = $ast.paragraphs[0].Str;
        $name = $name ~ '1' if $name ~~ / ^ 'item' $ | ^ 'head' $ /;
        $!scoped-data.config( { $name => %options } );
    }
    method manage-aliases($ast) {
        my %options = $.get-meta($ast);
        my $name = $ast.paragraphs[0].Str;
        $!scoped-data.aliases( %options );
    }
    method manage-definitions($ast) {
        my %options = $.get-meta($ast);
        my $name = $ast.paragraphs[0].Str;
        $!scoped-data.definitions( %options );
    }
    # completion methods
    #| finalises rendering of the item list in $*prs
    method complete-item-list() {
        ''
    }
    #| finalises rendering of a defn list in $*prs
    method complete-defn-list() {
        ''
    }
    # helper methods
    method is-target-unique($targ --> Bool) {
        !$!current.targets{$targ}
    }
    method register-target($targ) {
        $!current.targets{$targ}++
    }
    #| The 'contents' method assumes
    #|   $*prs is defined and that $ast.paragraphs is sequence.
    #|   These are true inside a handle for a RakuDoc::Block
    method contents($ast) {
        my ProcessedState @prs = $ast.paragraphs.map({ $.handle($_) });
        # if the Block has embedded RakuDoc, then there may be links
        # and index markup, which need to be added to the main $*prs
        # but the content text as Pstr should not be added to the $*prs
        # until it has been rendered in the template
        my ProcessedState $rv .= new;
        $rv += $_ for @prs;
        my PStr $text = $rv.body;
        $rv.body .= new;
        $*prs += $rv;
        $text
    }
    # the following are methods that may be called from within a template
    # templates have a data

    #| name-id takes an ast and an optional :make-unique
    #| returns a Str target to be used as an internal target
    #| renderers should ensure target is unique if :make-unique True
    #| renderers should sub-class name-id
    #| renderers can use method is-target-unique to test for uniqueness
    method name-id($ast, :$make-unique = False  --> Str) {
        my $target = recurse-until-str($ast).join.trim.subst(/ \s /, '_', :g);
        return $target unless $make-unique;
        return $target if $.is-target-unique($target);
        my @rejects = $target, ;
        # if plain target is rejected, then start adding a suffix
        $target ~= '_0';
        $target += 1 while $target ~~ any(@rejects);
        $target
    }
    #| gets the meta data from a block
    method get-meta($ast --> Hash) {
        $ast.config.pairs.map(
            { .key => .value.literalize }
        ).hash
    }

    #| returns hash of test templates
    multi method test-text-templates {
        %(
            #| special key to name template set
            _name => -> %, $ {
                'test text templates'
            },
            #| renders =code block
            code => -> %prm, $tmpl {
                "<code>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</code>\n"
            },
            #| renders =input block
            input => -> %prm, $tmpl {
                "<input>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</input>\n"
            },
            #| renders =output block
            output => -> %prm, $tmpl {
                "<output>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</output>\n"
            },
            #| renders =comment block
            comment => -> %prm, $tmpl {
                "<comment>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</comment>\n"
            },
            #| renders =head block
            head => -> %prm, $tmpl {
                my $caption = %prm<caption> // %prm<contents>;
                my $target = %prm<id> // %prm<target>;
                my $toc = %prm<toc> // True;
                my $state = %prm<state>:delete;
                $tmpl.globals.helper<add-to-toc>(
                    {:$caption, :$target, :level(%prm<level>), :$state }
                ) if $toc;

                "<head>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</head>\n"
            },
            #| renders =numhead block
            numhead => -> %prm, $tmpl {
                "<numhead>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</numhead>\n"
            },
            #| renders =defn block
            defn => -> %prm, $tmpl {
                "<defn>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</defn>\n"
            },
            #| renders =item block
            item => -> %prm, $tmpl {
                "<item>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</item>\n"
            },
            #| renders =numitem block
            numitem => -> %prm, $tmpl {
                "<numitem>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</numitem>\n"
            },
            #| renders =nested block
            nested => -> %prm, $tmpl {
                "<nested>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</nested>\n"
            },
            #| renders =para block
            para => -> %prm, $tmpl {
                "<para>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</para>\n"
            },
            #| renders =rakudoc block
            rakudoc => -> %prm, $tmpl {
                "<rakudoc>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</rakudoc>\n"
            },
            #| renders =section block
            section => -> %prm, $tmpl {
                "<section>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</section>\n"
            },
            #| renders =pod block
            pod => -> %prm, $tmpl {
                "<pod>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</pod>\n"
            },
            #| renders =table block
            table => -> %prm, $tmpl {
                "<table>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</table>\n"
            },
            #| renders =semantic block
            semantic => -> %prm, $tmpl {
                "<semantic>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</semantic>\n"
            },
            #| renders =custom block
            custom => -> %prm, $tmpl {
                "<custom>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</custom>\n"
            },
            #| special template to encapsulate all the output to save to a file
            source-wrap => -> %prm, $tmpl {
                my @toc = %prm<processed>.toc;
                %prm<processed>.title ~ "\n" ~ '=' x 50 ~ "\n"
                ~ $tmpl('toc', {
                    :@toc,
                    caption => %prm<processed>.source-data<toc-caption>
                } )
                ~ $tmpl('index', {
                    index => %prm<processed>.index,
                    caption => %prm<processed>.source-data<index-caption>
                })
                ~ %prm<processed>.body.Str
                ~ "\n" ~ '=' x 50 ~ "\n"
                ~ $tmpl('footnotes', {
                    index => %prm<processed>.index,
                })
                ~ 'Rendered from ｢' ~ %prm<processed>.source-data<name>
                ~ '｣ at ' ~ %prm<processed>.modified
                ~ "\n" ~ '=' x 50 ~ "\n"
            },
            #| special template to render the toc data structure
            toc => -> %prm, $tmpl {
               %prm<caption> ~ "\n"
               ~ %prm<toc>.map({
                    ' ' x .<level> ~ .<level>
                    ~ ': caption ｢'
                    ~ .<caption>
                    ~ '｣ target ｢'
                    ~ .<target>
                    ~ "｣\n" }).join()
                ~ '-' x 50 ~ "\n"
            },
            #| special template to render the index data structure
            index => -> %prm, $tmpl {
                ''
            },
            #| special template to render the footnotes data structure
            footnotes => -> %prm, $tmpl {
                ''
            },
            #| special template to render the warnings data structure
            warnings => -> %prm, $tmpl {
                ''
            }
        );
    }
    # text helpers adapted from Liz's RakuDoc::To::Text
    # colorless ANSI constants
    my constant RESET = "\e[0m";
    my constant BOLD-ON = "\e[1m";
    my constant ITALIC-ON = "\e[3m";
    my constant UNDERLINE-ON = "\e[4m";
    my constant INVERSE-ON = "\e[7m";
    my constant BOLD-OFF = "\e[22m";
    my constant ITALIC-OFF = "\e[23m";
    my constant UNDERLINE-OFF = "\e[24m";
    my constant INVERSE-OFF = "\e[27m";

    my sub bold(str $text) {
        BOLD-ON ~ $text ~ BOLD-OFF
    }
    my sub italic(str $text) {
        ITALIC-ON ~ $text ~ ITALIC-OFF
    }
    my sub underline(str $text) {
        UNDERLINE-ON ~ $text ~ UNDERLINE-OFF
    }
    my sub inverse(str $text) {
        INVERSE-ON ~ $text ~ INVERSE-OFF
    }

    # ANSI formatting allowed
    my constant %formats =
    B => &bold,
    C => &bold,
    L => &underline,
    D => &underline,
    R => &inverse,
    I => &italic,
    ;
    #| returns a set of default text templates $test must be False
    multi method default-text-templates {
        %(
            #| special key to name template set
            _name => -> %, $ {
                'default text templates'
            },
            #| renders =code blocks
            code => -> %prm, $tmpl {
                "<code>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</code>\n"
            },
            #| renders =input block
            input => -> %prm, $tmpl {
                "<input>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</input>\n"
            },
            #| renders =output block
            output => -> %prm, $tmpl {
                "<output>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</output>\n"
            },
            #| renders =comment block
            comment => -> %prm, $tmpl {
                "<comment>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</comment>\n"
            },
            #| renders =head block
            head => -> %prm, $tmpl {
                my $indent = %prm<level> > 2 ?? 4 !! (%prm<level> - 1) * 2;
                qq:to/HEAD/
                { %prm<contents>.Str.indent($indent) }
                { ('-' x %prm<contents>.Str.chars).indent($indent) }
                HEAD
            },
            #| renders =numhead block
            numhead => -> %prm, $tmpl {
                "<numhead>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</numhead>\n"
            },
            #| renders =defn block
            defn => -> %prm, $tmpl {
                "<defn>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</defn>\n"
            },
            #| renders =item block
            item => -> %prm, $tmpl {
                "<item>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</item>\n"
            },
            #| renders =numitem block
            numitem => -> %prm, $tmpl {
                "<numitem>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</numitem>\n"
            },
            #| renders =nested block
            nested => -> %prm, $tmpl {
                "<nested>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</nested>\n"
            },
            #| renders =para block
            para => -> %prm, $tmpl {
                "<para>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</para>\n"
            },
            #| renders =rakudoc block
            rakudoc => -> %prm, $tmpl {
                "<rakudoc>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</rakudoc>\n"
            },
            #| renders =section block
            section => -> %prm, $tmpl {
                "<section>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</section>\n"
            },
            #| renders =pod block
            pod => -> %prm, $tmpl {
                "<pod>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</pod>\n"
            },
            #| renders =table block
            table => -> %prm, $tmpl {
                "<table>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</table>\n"
            },
            #| renders =semantic block
            semantic => -> %prm, $tmpl {
                "<semantic>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</semantic>\n"
            },
            #| renders =custom block
            custom => -> %prm, $tmpl {
                "<custom>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</custom>\n"
            },
            #| special template to encapsulate all the output to save to a file
            source-wrap => -> %prm, $tmpl {
                "<source-wrap>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</source-wrap>\n"
            },
            #| special template to render the toc data structure
            toc => -> %prm, $tmpl {
               %prm<caption> ~ "\n"
               ~ %prm<toc>.map({
                    ' ' x .<level> ~ .<level>
                    ~ ': caption ｢'
                    ~ .<caption>
                    ~ '｣ target ｢'
                    ~ .<target>
                    ~ "｣\n" }).join()
                ~ '-' x 50 ~ "\n"
            },
            #| special template to render the index data structure
            index => -> %prm, $tmpl {
                ''
            },
            #| special template to render the footnotes data structure
            footnotes => -> %prm, $tmpl {
                "<footnotes>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</footnotes>\n"
            },
            #| special template to render the warnings data structure
            warnings => -> %prm, $tmpl {
                ''
            }
        );
    }
    #| returns hash of test helper callables
    multi method text-helpers {
        %(
            add-to-toc => -> %h {
                %h<state>.toc.push:
                    { :caption(%h<caption>.Str), :target(%h<target>), :level(%h<level>) },
            }
        )
    }
}

#| Strip out formatting code and links from a Title or Link
multi sub recurse-until-str(Str:D $s) is export {
    $s
}
multi sub recurse-until-str(RakuAST::Doc::Block $n) is export {
    $n.paragraphs>>.&recurse-until-str().join
}