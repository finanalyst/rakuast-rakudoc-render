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
    method start-scope(:$callee, :$debug = False ) {
        @!callees.push: $callee // 'not given';
        @!config.push: @!config[*-1].pairs.hash;
        @!aliases.push: @!aliases[*-1].pairs.hash;
        @!definitions.push: @!definitions[*-1].pairs.hash;
        self.debug if $debug
    }
    #| ends the current scope, forgets new data
    method end-scope(:$debug = False) {
        @!callees.pop;
        @!config.pop;
        @!aliases.pop;
        @!definitions.pop;
        self.debug if $debug
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

enum RDProcDebug <None AstBlock BlockType Scoping>;

class RakuDoc::Processor {
    has %.templates is Template-directory;
    has Supplier::Preserving $.com-channel .= new;
    has RakuDoc::Processed $.current;
    has $.output-format;
    has ScopedData $!scoped-data .= new;
    #| debug mode
    has Set $!debug .= new ;

    multi submethod TWEAK(:$!output-format = 'txt', :$test = False, :$debug = (None, ) ) {
        %!templates = $test ?? self.test-text-templates !! self.default-text-templates;
        %!templates.helper = self.text-helpers;
        $!debug = $debug.Set;
    }

    #| renders the $ast to a RakuDoc::Processed or String
    multi method render( $ast, :%source-data, :$final-wrap = False ) {
        $!current .= new(:%source-data, :$!output-format );
        my ProcessedState $*prs .= new;
        for $ast.rakudoc {
            $.handle($_)
        }
        $!current += $*prs;
        # all suspended PCells should have been replaced by Str
        # so calling debug on PStr should not get a PCell waiting for
        my $suspended = $*prs.body.debug ~~ / [ 'PCell' .+? 'Waiting for: ' $<id> = (.+?) \s \x3019 .*? ]+ $ /;
        if $suspended {
            $*prs.warnings.push: 'Still waiting for ' ~ $/<id> ~ ' to be expanded.' for $suspended.list;
        }
        return $.current unless $final-wrap;
        # All of the placing of the footnotes, ToC etc, is left to source-wrap template
        %!templates<source-wrap>( %( :processed( $!current ), )).Str
    }

    #| handle methods return void
    proto method handle( $ast ) {
        say "Handling: " , $ast.WHICH.Str.subst(/ \| .+ $/, '') if $!debug (cont) AstBlock;
        {*}
    }
    multi method handle(Str:D $ast) {
        $*prs.body ~= $ast;
    }
    multi method handle(RakuAST::Node:D $ast) {
        my ProcessedState @prs = $ast.rakudoc.map({ $.handle($_) });
        $*prs += $_ for @prs;
    }
            # =column
            # Start a new column in a procedural table

            # =row
            # Start a new row in a procedural table

            # =input
            # Pre-formatted sample input

            # =output
            # Pre-formatted sample output

            # =numhead
            # First-level numbered heading

            # =numheadN
            # Nth-level numbered heading

            # =defn
            # Definition of a term


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
        say "Doc::Block type: " ~ $ast.type if $!debug (cont) BlockType;
        $*prs.body ~= $.complete-item-list unless $ast.type and $ast.type eq 'item';
        $*prs.body ~= $.complete-defn-list unless $ast.type and $ast.type eq 'defn';

        # Not all Blocks create a new scope. Some change the current scope data
        given $ast.type {
            # =alias
            # Define a Pod macro
#            when 'alias' { $.gen-alias($ast) }
            # =code
            # Verbatim pre-formatted sample source code
#            when 'code' { $.gen-code($ast) }
            # =comment
            # Content to be ignored by all renderers
            when 'comment' { '' }
            # =config
            # Block scope modifications to a block or markup instruction
            when 'config' { $.manage-config($ast); }
            # =head
            # First-level heading
            # =headN
            # Nth-level heading
            when 'head' {
                $!scoped-data.start-scope( :debug( $!debug (cont) Scoping), :callee($_));
                $.gen-head($ast);
                $!scoped-data.end-scope( :debug( $!debug (cont) Scoping) ) 
            }
#            when 'implicit-code' { $.gen-code($ast) }
            # =item
            # First-level list item
            # =itemN
            # Nth-level list item
            when 'item' {
                $.gen-item($ast)
            }
            # =para block, as opposed to unmarked paragraphs in a block
            when 'para' {

            }
            # =rakudoc
            # No "ambient" blocks inside
            when 'rakudoc' | 'pod' {
                $!scoped-data.start-scope(:callee($_));
                $.gen-rakudoc($ast);
                $!scoped-data.end-scope( :debug( $!debug (cont) Scoping) ) 
            }
            # =pod
            # Legacy version of rakudoc
#           when 'pod' { '' } # when rakudoc differs from pod
            # =section
            # Defines a section
            when 'section' {
                $!scoped-data.start-scope( :debug( $!debug (cont) Scoping), :callee($_));
                $.gen-section($ast);
                $!scoped-data.end-scope( :debug( $!debug (cont) Scoping) ) 
            }
            # =table
            # Visual or procedural table
#            when 'table' { $.gen-table($ast) }
            # RESERVED
            # Semantic blocks (SYNOPSIS, TITLE, etc.)
            when all($_.uniprops) ~~ / Lu / {
                # in RakuDoc v2 a Semantic block must have all uppercase letters
                $!scoped-data.start-scope( :debug( $!debug (cont) Scoping), :callee($_));
                $.gen-semantics($ast);
                $!scoped-data.end-scope( :debug( $!debug (cont) Scoping) ) 
            }
            # CustomName
            # User-defined block
            when any($_.uniprops) ~~ / Lu / and any($_.uniprops) ~~ / Ll / {
                # in RakuDoc v2 a Semantic block must have mix of uppercase and lowercase letters
                $!scoped-data.start-scope( :debug( $!debug (cont) Scoping), :callee($_));
                $.gen-custom($ast);
                $!scoped-data.end-scope( :debug( $!debug (cont) Scoping) ) 
            }
            default { $.gen-unknown-builtin($ast) }
        }
    }
    # =data
    # Raku data section
    multi method handle(RakuAST::Doc::DeclaratorTarget:D $ast) {
        #ignore declarator block
    }
    multi method handle(RakuAST::Doc::Markup:D $ast) {
        given $ast.letter {
            ## Markup codes with only display (format codes), no meta data allowed
            ## meta data via Config is allowed
            when any( <B C H I J K R S T U V N O> ) {
                my $letter = $ast.letter;
                my %config;
                my $contents = self.markup-contents($ast);
                my %scoped-head = $!scoped-data.config;
                %config{ .key } = .value for %scoped-head{$letter}.pairs;
                $*prs.body ~= %!templates{"markup-$letter"}(
                    %( :$contents, %config )
                );
            }
            ## Markup codes, optional display and meta data

            # A< DISPLAY-TEXT |  METADATA = ALIAS-NAME >
            # Alias to be replaced by contents of specified V<=alias> directive
            when 'A' {

            }
            # E< DISPLAY-TEXT |  METADATA = HTML/UNICODE-ENTITIES >
            # Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> )
            when 'E' {

            }
            # F< DISPLAY-TEXT |  METADATA = LATEX-FORM >
            # Formula inline content ( F<ALT|LaTex notation> )
            when 'F' {

            }
            # L< DISPLAY-TEXT |  METADATA = TARGET-URI >
            # Link ( L<display text|destination URI> )
            when 'L' {

            }
            # P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            # Placement link
            when 'P' {

            }

            ## Markup codes, mandatory display and meta data
            # D< DISPLAY-TEXT |  METADATA = SYNONYMS >
            # Definition inline ( D<term being defined|synonym1; synonym2> )
            when 'D' {

            }
            # Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            # Delta note ( Δ<visible text|version; Notification text> )
            when 'Δ' {

            }
            # M< DISPLAY-TEXT |  METADATA = WHATEVER >
            # Markup extra ( M<display text|functionality;param,sub-type;...>)
            when 'M' {

            }
            # X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            # Index entry ( X<display text|entry,subentry;...>)
            when 'X' {

            }

            ## Technically only meta data, but just contents

            # Z< METADATA = COMMENT >
            # Comment zero-width  (contents never rendered)
            when 'Z' {
                $*prs.body ~= '';
            }
        
            ## Undefined and reserved, so generate warnings
            # do not go through templates as these cannot be redefined
            when any(<G Q W Y>) {
                $*prs.body ~= ~$ast;
                $*prs.warnings.push: '｢' ~ $ast.letter ~ '｣' ~ ' is not yet defined, but is reserved for future use.'
            }
            default {
                my $letter = $ast.letter;
                my %config;
                my $contents;
                my %scoped-head = $!scoped-data.config;
                %config{ .key } = .value for %scoped-head{$letter}.pairs;
                $*prs.body ~= %!templates<unknown>(
                    %( :$contents, %config)
                );
                $*prs.warnings.push: '｢' ~ $ast.letter ~ '｣' ~ 'is not yet defined, but could be a custom code'
            }
        }
    }
    # Ordinary paragraph
    multi method handle(RakuAST::Doc::Paragraph:D $ast) {
        my %config;
        my %scoped-head = $!scoped-data.config;
        %config{ .key } = .value for %scoped-head<para>.pairs;
        my ProcessedState $*prs .= new;
        for $ast.atoms { $.handle($_) }
        my PStr $contents = $*prs.body;
        $*prs.body .= new;
        $*prs.body ~= %!templates<para>(
            %( :$contents, %config)
        );
        CALLERS::<$*prs> += $*prs;
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
        my %config = $ast.resolved-config;
        my %scoped-head = $!scoped-data.config;
        %config{ .key } = .value for %scoped-head{"head$level"}.pairs;
        $*prs.body ~= %!templates<head>(
            %( :state($*prs), :$level, :$target, :$contents, %config)
        )
    }
    method gen-item($ast) {
        my $level = $ast.level > 1 ?? $ast.level !! 1;
        my $contents = $.contents($ast);
        my %config = $ast.resolved-config;
        my %scoped = $!scoped-data.config;
        %config{ .key } = .value for %scoped{"item$level"}.pairs;
        $*prs.items.push: %!templates<item>(
            %( :$level, :$contents, %config)
        )
    }
    method gen-rakudoc($ast) {
        my %config = $ast.resolved-config;
        $!current.source-data<rakudoc-config> = %config;
        my $contents = $.contents($ast);
        # render any tailing lists
        $contents ~= $.complete-item-list;
        $contents ~= $.complete-defn-list;
        $*prs.body ~= %!templates<rakudoc>( %( :$contents, %config ) )
    }
    method gen-section($ast) {
        my %config = $ast.resolved-config;
        my $contents = $.contents($ast);
        # render any tailing lists
        $contents ~= $.complete-item-list;
        $contents ~= $.complete-defn-list;
        $*prs.body ~= %!templates<section>( %( :$contents, %config ) )
    }
    method gen-table($ast) {
        ''
    }
    method gen-unknown-builtin($ast) {
        my %config = $ast.resolved-config;
        my $contents = $.contents($ast);
        if $ast.type ~~ any(< 
                cell code input output comment head numhead defn item numitem nested para
                rakudoc section pod table formula
            >) { # a known built-in, but to get here the block is unimplemented
            $*prs.warnings.push: '｢' ~ $ast.type ~ '｣' ~ 'is a valid, but unimplemented builtin block'
        }
        else { # not known so create another warning
            $*prs.warnings.push: '｢' ~ $ast.type ~ '｣' ~ 'is not a valid builtin block, is it a mispelt Custom block?'
        }
        $*prs.body ~= %!templates<unknown>( %( :block-type($ast.type), :$contents, %config ) )
    }
    method gen-semantics($ast) {
        ''
    }
    method gen-custom($ast) {
        ''
    }
    # directive type methods
    method manage-config($ast) {
        my %options = $ast.resolved-config;
        my $name = $ast.paragraphs[0].Str;
        $name = $name ~ '1' if $name ~~ / ^ 'item' $ | ^ 'head' $ /;
        $!scoped-data.config( { $name => %options } );
    }
    method manage-aliases($ast) {
        my %options = $ast.resolved-config;
        my $name = $ast.paragraphs[0].Str;
        $!scoped-data.aliases( %options );
    }
    method manage-definitions() { ''
    }
    # completion methods
    #| finalises rendering of the item list in $*prs
    method complete-item-list() {
        return '' unless $*prs.items; # do nothing of no accumulated items
        my $rv = %!templates<item-list>(
            %( :item-list($*prs.items), )
        );
        $*prs.items = ();
        $rv
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
    #| The 'contents' method that $ast.paragraphs is a sequence.
    #| The $*prs for a set of paragraphs is new to collect all the
    #| associated data. The body of the contents must then be
    #| incorporated using the template of the block calling content
    method contents($ast) {
        my ProcessedState $*prs .= new;
        for $ast.paragraphs {
           $.handle($_)
        };
        my PStr $text = $*prs.body;
        $*prs.body .= new;
        CALLERS::<$*prs> += $*prs;
        $text
    }
    method markup-contents($ast) {
        my ProcessedState $*prs .= new;
        for $ast.atoms { $.handle($_) }
        my PStr $text = $*prs.body;
        $*prs.body .= new;
        CALLERS::<$*prs> += $*prs;
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
                'new test text templates'
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
            #| renders any unknown block minimally
            unknown => -> %prm, $tmpl {
                "<unknown>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</unknown>\n"
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
                ~ "\n" ~ '=' x 50 ~ "\n"
                ~ $tmpl('warnings', {
                    warnings => %prm<processed>.warnings,
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
            #| special template to render an item list data structure
            item-list => -> %prm, $tmpl {
                "<item-list>\n" ~ %prm<item-list>.join ~ "</item-list>\n"
            },
            #| special template to render the warnings data structure
            warnings => -> %prm, $tmpl {
                if %prm<warnings>.elems {
                    my $n = 1;
                    "<warning-list>\n"
                    ~ [~] %prm<warnings>.map({
                        "<warning>{ $n++ }: $_\</warning>\n"
                    })
                    ~ "</warning-list>\n"
                }
                else {
                    ''
                }
            },
            ## Markup codes with only display (format codes), no meta data allowed
            ## meta data via Config is allowed
            #| B< DISPLAY-TEXT >
            #| Basis/focus of sentence (typically rendered bold)
			markup-B => -> %prm, $tmpl {
				'<basis>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</basis>'
			},
            #| C< DISPLAY-TEXT >
            #| Code (typically rendered fixed-width)
			markup-C => -> %prm, $tmpl {
				'<code>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</code>'
			},
            #| H< DISPLAY-TEXT >
            #| High text (typically rendered superscript)
			markup-H => -> %prm, $tmpl {
				'<high>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</high>'
			},
            #| I< DISPLAY-TEXT >
            #| Important (typically rendered in italics)
			markup-I => -> %prm, $tmpl {
				'<important>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</important>'
			},
            #| J< DISPLAY-TEXT >
            #| Junior text (typically rendered subscript)
			markup-J => -> %prm, $tmpl {
				'<junior>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</junior>'
			},
            #| K< DISPLAY-TEXT >
            #| Keyboard input (typically rendered fixed-width)
			markup-K => -> %prm, $tmpl {
				'<keyboard>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</keyboard>'
			},
            #| N< DISPLAY-TEXT >
            #| Note (not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.))
			markup-N => -> %prm, $tmpl {
				'<note>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</note>'
			},
            #| O< DISPLAY-TEXT >
            #| Overstrike or strikethrough
			markup-O => -> %prm, $tmpl {
				'<overstrike>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</overstrike>'
			},
            #| R< DISPLAY-TEXT >
            #| Replaceable component or metasyntax
			markup-R => -> %prm, $tmpl {
				'<replaceable>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</replaceable>'
			},
            #| S< DISPLAY-TEXT >
            #| Space characters to be preserved
			markup-S => -> %prm, $tmpl {
				'<space>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</space>'
			},
            #| T< DISPLAY-TEXT >
            #| Terminal output (typically rendered fixed-width)
			markup-T => -> %prm, $tmpl {
				'<terminal>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</terminal>'
			},
            #| U< DISPLAY-TEXT >
            #| Unusual (typically rendered with underlining)
			markup-U => -> %prm, $tmpl {
				'<unusual>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</unusual>'
			},
            #| V< DISPLAY-TEXT >
            #| Verbatim (internal markup instructions ignored)
			markup-V => -> %prm, $tmpl {
				'<verbatim>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</verbatim>'
			},

            ##| Markup codes, optional display and meta data

            #| A< DISPLAY-TEXT |  METADATA = ALIAS-NAME >
            #| Alias to be replaced by contents of specified V<=alias> directive
			markup-A => -> %prm, $tmpl {
				'<alias>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</alias>'
			},
            #| E< DISPLAY-TEXT |  METADATA = HTML/UNICODE-ENTITIES >
            #| Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> )
			markup-E => -> %prm, $tmpl {
				'<entity>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</entity>'
			},
            #| F< DISPLAY-TEXT |  METADATA = LATEX-FORM >
            #| Formula inline content ( F<ALT|LaTex notation> )
			markup-F => -> %prm, $tmpl {
				'<formula>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</formula>'
			},
            #| L< DISPLAY-TEXT |  METADATA = TARGET-URI >
            #| Link ( L<display text|destination URI> )
			markup-L => -> %prm, $tmpl {
				'<link>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</link>'
			},
            #| P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            #| Placement link
			markup-P => -> %prm, $tmpl {
				'<placement>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</placement>'
			},

            ##| Markup codes, mandatory display and meta data
            #| D< DISPLAY-TEXT |  METADATA = SYNONYMS >
            #| Definition inline ( D<term being defined|synonym1; synonym2> )
			markup-D => -> %prm, $tmpl {
				'<definition>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</definition>'
			},
            #| Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            #| Delta note ( Δ<visible text|version; Notification text> )
            markup-Δ => -> %prm, $tmpl {
				'<delta>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</delta>'
			},
            #| M< DISPLAY-TEXT |  METADATA = WHATEVER >
            #| Markup extra ( M<display text|functionality;param,sub-type;...>)
			markup-M => -> %prm, $tmpl {
				'<markup>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</markup>'
			},
            #| X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            #| Index entry ( X<display text|entry,subentry;...>)
			markup-X => -> %prm, $tmpl {
				'<index>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</index>'
			},
            #| Unknown markup, render minimally
            markup-unknown => -> %prm, $tmpl {
				'<unknown>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</unknown>'
			},
        ); # END OF TEMPLATES (this comment is to simplify documentation generation)
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
    #| returns a set of text templates
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
            #| renders any unknown block minimally
            unknown => -> %prm, $tmpl {
                "<unknown>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</unknown>\n"
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
            #| special template to render an item list data structure
            item-list => -> %prm, $tmpl {
                '<item-list> ' ~ %prm<item-list>.join ~ ' </item-list>'
            },
            #| special template to render the footnotes data structure
            footnotes => -> %prm, $tmpl {
                "<footnotes>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</footnotes>\n"
            },
            #| special template to render the warnings data structure
            warnings => -> %prm, $tmpl {
                ''
            },
            ## Markup codes with only display (format codes), no meta data allowed
            ## meta data via Config is allowed
            #| B< DISPLAY-TEXT >
            #| Basis/focus of sentence (typically rendered bold)
			markup-B => -> %prm, $tmpl {
				'<basis>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</basis>'
			},
            #| C< DISPLAY-TEXT >
            #| Code (typically rendered fixed-width)
			markup-C => -> %prm, $tmpl {
				'<code>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</code>'
			},
            #| H< DISPLAY-TEXT >
            #| High text (typically rendered superscript)
			markup-H => -> %prm, $tmpl {
				'<high>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</high>'
			},
            #| I< DISPLAY-TEXT >
            #| Important (typically rendered in italics)
			markup-I => -> %prm, $tmpl {
				'<important>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</important>'
			},
            #| J< DISPLAY-TEXT >
            #| Junior text (typically rendered subscript)
			markup-J => -> %prm, $tmpl {
				'<junior>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</junior>'
			},
            #| K< DISPLAY-TEXT >
            #| Keyboard input (typically rendered fixed-width)
			markup-K => -> %prm, $tmpl {
				'<keyboard>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</keyboard>'
			},
            #| N< DISPLAY-TEXT >
            #| Note (not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.))
			markup-N => -> %prm, $tmpl {
				'<note>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</note>'
			},
            #| O< DISPLAY-TEXT >
            #| Overstrike or strikethrough
			markup-O => -> %prm, $tmpl {
				'<overstrike>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</overstrike>'
			},
            #| R< DISPLAY-TEXT >
            #| Replaceable component or metasyntax
			markup-R => -> %prm, $tmpl {
				'<replaceable>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</replaceable>'
			},
            #| S< DISPLAY-TEXT >
            #| Space characters to be preserved
			markup-S => -> %prm, $tmpl {
				'<space>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</space>'
			},
            #| T< DISPLAY-TEXT >
            #| Terminal output (typically rendered fixed-width)
			markup-T => -> %prm, $tmpl {
				'<terminal>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</terminal>'
			},
            #| U< DISPLAY-TEXT >
            #| Unusual (typically rendered with underlining)
			markup-U => -> %prm, $tmpl {
				'<unusual>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</unusual>'
			},
            #| V< DISPLAY-TEXT >
            #| Verbatim (internal markup instructions ignored)
			markup-V => -> %prm, $tmpl {
				'<verbatim>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</verbatim>'
			},

            ##| Markup codes, optional display and meta data

            #| A< DISPLAY-TEXT |  METADATA = ALIAS-NAME >
            #| Alias to be replaced by contents of specified V<=alias> directive
			markup-A => -> %prm, $tmpl {
				'<alias>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</alias>'
			},
            #| E< DISPLAY-TEXT |  METADATA = HTML/UNICODE-ENTITIES >
            #| Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> )
			markup-E => -> %prm, $tmpl {
				'<entity>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</entity>'
			},
            #| F< DISPLAY-TEXT |  METADATA = LATEX-FORM >
            #| Formula inline content ( F<ALT|LaTex notation> )
			markup-F => -> %prm, $tmpl {
				'<formula>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</formula>'
			},
            #| L< DISPLAY-TEXT |  METADATA = TARGET-URI >
            #| Link ( L<display text|destination URI> )
			markup-L => -> %prm, $tmpl {
				'<link>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</link>'
			},
            #| P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            #| Placement link
			markup-P => -> %prm, $tmpl {
				'<placement>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</placement>'
			},

            ##| Markup codes, mandatory display and meta data
            #| D< DISPLAY-TEXT |  METADATA = SYNONYMS >
            #| Definition inline ( D<term being defined|synonym1; synonym2> )
			markup-D => -> %prm, $tmpl {
				'<definition>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</definition>'
			},
            #| Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            #| Delta note ( Δ<visible text|version; Notification text> )
            markup-Δ => -> %prm, $tmpl {
				'<delta>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</delta>'
			},
            #| M< DISPLAY-TEXT |  METADATA = WHATEVER >
            #| Markup extra ( M<display text|functionality;param,sub-type;...>)
			markup-M => -> %prm, $tmpl {
				'<markup>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</markup>'
			},
            #| X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            #| Index entry ( X<display text|entry,subentry;...>)
			markup-X => -> %prm, $tmpl {
				'<index>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</index>'
			},
            #| Unknown markup, render minimally
            markup-unknown => -> %prm, $tmpl {
				'<unknown>' ~ %prm.sort>>.fmt("%s: ｢%s｣") ~ '</unknown>'
			},
        ); # END OF TEMPLATES (this comment is to simplify documentation generation)
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