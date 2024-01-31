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
        Scope levels: { +@!callees }
        Scope callees: { +@!callees ?? @!callees.join(' ') !! 'original level' }
        DEBUG
    }
    #| starts a new scope
    method start-scope(:$callee ) {
        @!callees.push: $callee // 'not given';
        @!config.push: @!config[*-1].pairs.hash;
        @!aliases.push: @!aliases[*-1].pairs.hash;
        @!definitions.push: @!definitions[*-1].pairs.hash;
    }
    #| ends the current scope, forgets new data
    method end-scope {
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
    method last-callee {
        @!callees[*-1]
    }
}

enum RDProcDebug <None All AstBlock BlockType Scoping Templates>;

class RakuDoc::Processor {
    has %.templates is Template-directory;
    has Supplier::Preserving $.com-channel .= new;
    has RakuDoc::Processed $.current;
    has $.output-format;
    has ScopedData $!scoped-data .= new;
    #| debug mode
    has Set $!debug .= new ;

    method debug( +$seq ) {
        $!debug = $seq.Set;
        %!templates.debug = ?( $seq (cont) any( All, Templates ) )
    }

    multi submethod TWEAK(:$!output-format = 'txt', :$test = False, :$debug = (None, ) ) {
        %!templates.source = $test ?? 'test templates' !! 'default templates' ;
        %!templates = $test ?? self.test-text-templates !! self.default-text-templates;
        %!templates.helper = self.text-helpers;
        self.debug( $debug.list )
    }

    #| renders the $ast to a RakuDoc::Processed or String
    multi method render( $ast, :%source-data, :$final-wrap = False ) {
        $!current .= new(:%source-data, :$!output-format );
        my ProcessedState $*prs .= new;
        for $ast.rakudoc {
            $.handle($_)
        }
        $!current += $*prs;
        self.complete-footnotes;
        $!current.body.strip; # remove expanded PCells.
        # all suspended PCells should have been replaced by Str
        # so calling debug on PStr should not get a PCell waiting for
        if $!current.body.has-PCells {
            while $!current.body.debug ~~ m :c / 'PCell' .+? 'Waiting for: ' $<id> = (.+?) \s \x3019 / {
                $!current.warnings.push( 'Still waiting for ' ~ $/<id> ~ ' to be expanded.' )
            }
        }
        return $.current unless $final-wrap;
        # All of the placing of the footnotes, ToC etc, is left to source-wrap template
        %!templates<source-wrap>( %( :processed( $!current ), )).Str
    }

    #| handle methods return void
    proto method handle( $ast ) {
        say "Handling: " , $ast.WHICH.Str.subst(/ \| .+ $/, '') if $!debug (cont) any( All, AstBlock );
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
        say "Doc::Block type: " ~ $ast.type if $!debug (cont) any( All, BlockType );
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
                $!scoped-data.start-scope(:callee($_));
                say $!scoped-data.debug if $!debug (cont) any( All, Scoping ) ;
                $.gen-head($ast);
                $!scoped-data.end-scope;
                say $!scoped-data.debug if $!debug (cont) any( All, Scoping ) ;
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

        say "@ $?LINE debug " ,$*prs.body.debug;
            }
            # =rakudoc
            # No "ambient" blocks inside
            when 'rakudoc' | 'pod' {
                $!scoped-data.start-scope(:callee($_));
                say $!scoped-data.debug if $!debug (cont) any( All, Scoping );
                $.gen-rakudoc($ast);
                $!scoped-data.end-scope;
                say $!scoped-data.debug if $!debug (cont) any( All, Scoping ) ;
            }
            # =pod
            # Legacy version of rakudoc
#           when 'pod' { '' } # when rakudoc differs from pod
            # =section
            # Defines a section
            when 'section' {
                $!scoped-data.start-scope( :callee($_) );
                say $!scoped-data.debug if $!debug (cont) any( All, Scoping ) ;
                $.gen-section($ast);
                $!scoped-data.end-scope;
                say $!scoped-data.debug if $!debug (cont) any( All, Scoping ) ;
            }
            # =table
            # Visual or procedural table
#            when 'table' { $.gen-table($ast) }
            # RESERVED
            # Semantic blocks (SYNOPSIS, TITLE, etc.)
            when all($_.uniprops) ~~ / Lu / {
                # in RakuDoc v2 a Semantic block must have all uppercase letters
                $!scoped-data.start-scope( :callee($_) );
                say $!scoped-data.debug if $!debug (cont) any( All, Scoping ) ;
                $.gen-semantics($ast);
                $!scoped-data.end-scope;
                say $!scoped-data.debug if $!debug (cont) any( All, Scoping ) ;
            }
            # CustomName
            # User-defined block
            when any($_.uniprops) ~~ / Lu / and any($_.uniprops) ~~ / Ll / {
                # in RakuDoc v2 a Semantic block must have mix of uppercase and lowercase letters
                $!scoped-data.start-scope( :callee($_) );
                say $!scoped-data.debug if $!debug (cont) any( All, Scoping ) ;
                $.gen-custom($ast);
                $!scoped-data.end-scope;
                say $!scoped-data.debug if $!debug (cont) any( All, Scoping ) ;
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
            when any( <B C H I J K R S T U V O> ) {
                my $letter = $ast.letter;
                my %config;
                my $contents = self.markup-contents($ast);
                my %scoped-head = $!scoped-data.config;
                %config{ .key } = .value for %scoped-head{$letter}.pairs;
                $*prs.body ~= %!templates{"markup-$letter"}(
                    %( :$contents, %config )
                );
            }
            ## Display only, but has side-effects
            #| Footnotes (from N<> markup)
            #| Ordered Array of :$text, :$retTarget, :$fnNumber, :$fnTarget
            #| text is content of footnote, fnNumber is footNote number
            #| fnTarget is link to rendered footnote
            #| retTarget is link to where footnote is defined to link back form footnote
            when 'N' {
                my $letter = $ast.letter;
                my $id = self.name-id($ast.Str);
                my $contents = self.markup-contents($ast);
                my $retTarget = $id;
                my $fnNumber = PCell.new( :id("fn_num_$id"), :$!com-channel);
                my $fnTarget = "fn_target_$id";
                my %config;
                my %scoped-head = $!scoped-data.config;
                %config{ .key } = .value for %scoped-head{$letter}.pairs;
                $*prs.footnotes.push: %( :$contents, :$retTarget, :0fnNumber, :$fnTarget );
                my $rv = %!templates<markup-N>(
                    %( %config, :$retTarget, :$fnNumber, :$fnTarget )
                );
                $*prs.body ~= $rv;
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
        my $contents = $.contents($ast).trim;
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
            %( :$level, :$contents, %config )
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
    ## completion methods
    #| finalise the rendering of footnotes
    #| the numbering only happens when all footnotes are collected
    #| completes the PCell in the body
    method complete-footnotes {
        for $!current.footnotes.kv -> $n, %data {
            %data<fnNumber> = $n + 1;
            $!com-channel.emit(%(:payload($n + 1), :id( 'fn_num_' ~ %data<retTarget> ) ) );
        }
    }

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
                my PStr $rv .= new("<code>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</code>\n"
            },
            #| renders =input block
            input => -> %prm, $tmpl {
                my PStr $rv .= new("<input>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</input>\n"
            },
            #| renders =output block
            output => -> %prm, $tmpl {
                my PStr $rv .= new("<output>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</output>\n"
            },
            #| renders =comment block
            comment => -> %prm, $tmpl {
                my PStr $rv .= new("<comment>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</comment>\n"
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
                my PStr $rv .= new("<head>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</head>\n"
            },
            #| renders =numhead block
            numhead => -> %prm, $tmpl {
                my PStr $rv .= new("<numhead>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</numhead>\n"
            },
            #| renders =defn block
            defn => -> %prm, $tmpl {
                my PStr $rv .= new("<defn>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</defn>\n"
            },
            #| renders =item block
            item => -> %prm, $tmpl {
                my PStr $rv .= new("<item>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</item>\n"
            },
            #| renders =numitem block
            numitem => -> %prm, $tmpl {
                my PStr $rv .= new("<numitem>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</numitem>\n"
            },
            #| renders =nested block
            nested => -> %prm, $tmpl {
                my PStr $rv .= new("<nested>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</nested>\n"
            },
            #| renders =para block
            para => -> %prm, $tmpl {
                my PStr $rv .= new("<para>\n");
                for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
                $rv ~= "</para>\n"
            },
            #| renders =rakudoc block
            rakudoc => -> %prm, $tmpl {
                my PStr $rv .= new("<rakudoc>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</rakudoc>\n"
            },
            #| renders =section block
            section => -> %prm, $tmpl {
                my PStr $rv .= new("<section>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</section>\n"
            },
            #| renders =pod block
            pod => -> %prm, $tmpl {
                my PStr $rv .= new("<pod>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</pod>\n"
            },
            #| renders =table block
            table => -> %prm, $tmpl {
                my PStr $rv .= new("<table>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</table>\n"
            },
            #| renders =semantic block
            semantic => -> %prm, $tmpl {
                my PStr $rv .= new("<semantic>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</semantic>\n"
            },
            #| renders =custom block
            custom => -> %prm, $tmpl {
                my PStr $rv .= new("<custom>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</custom>\n"
            },
            #| renders any unknown block minimally
            unknown => -> %prm, $tmpl {
                my PStr $rv .= new("<unknown>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</unknown>\n"
            },
            #| special template to encapsulate all the output to save to a file
            source-wrap => -> %prm, $tmpl {
                %prm<processed>.title ~ "\n" ~ '=' x 50 ~ "\n"
                ~ $tmpl('toc', {
                    toc => %prm<processed>.toc,
                    caption => %prm<processed>.source-data<toc-caption>
                } )
                ~ $tmpl('index', {
                    index => %prm<processed>.index,
                    caption => %prm<processed>.source-data<index-caption>
                })
                ~ %prm<processed>.body.Str
                ~ "\n" ~ '=' x 50 ~ "\n"
                ~ $tmpl('footnotes', {
                    footnotes => %prm<processed>.footnotes,
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
                "<footnotes>\n" ~ %prm<footnote-list>.join ~ "</footnotes>\n"
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
				my PStr $rv .= new('<basis>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</basis>'
			},
            #| C< DISPLAY-TEXT >
            #| Code (typically rendered fixed-width)
			markup-C => -> %prm, $tmpl {
				my PStr $rv .= new('<code>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</code>'
			},
            #| H< DISPLAY-TEXT >
            #| High text (typically rendered superscript)
			markup-H => -> %prm, $tmpl {
				my PStr $rv .= new('<high>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</high>'
			},
            #| I< DISPLAY-TEXT >
            #| Important (typically rendered in italics)
			markup-I => -> %prm, $tmpl {
				my PStr $rv .= new('<important>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</important>'
			},
            #| J< DISPLAY-TEXT >
            #| Junior text (typically rendered subscript)
			markup-J => -> %prm, $tmpl {
				my PStr $rv .= new('<junior>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</junior>'
			},
            #| K< DISPLAY-TEXT >
            #| Keyboard input (typically rendered fixed-width)
			markup-K => -> %prm, $tmpl {
				my PStr $rv .= new('<keyboard>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</keyboard>'
			},
            #| N< DISPLAY-TEXT >
            #| Note (not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.))
            #| This is the template for the in-text part, which should have a Number, link, and return anchor
			markup-N => -> %prm, $tmpl {
                my PStr $rv .= new(  '<note>' );
                for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
                $rv ~= '</note>'
			},
            #| O< DISPLAY-TEXT >
            #| Overstrike or strikethrough
			markup-O => -> %prm, $tmpl {
				my PStr $rv .= new('<overstrike>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</overstrike>'
			},
            #| R< DISPLAY-TEXT >
            #| Replaceable component or metasyntax
			markup-R => -> %prm, $tmpl {
				my PStr $rv .= new('<replaceable>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</replaceable>'
			},
            #| S< DISPLAY-TEXT >
            #| Space characters to be preserved
			markup-S => -> %prm, $tmpl {
				my PStr $rv .= new('<space>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</space>'
			},
            #| T< DISPLAY-TEXT >
            #| Terminal output (typically rendered fixed-width)
			markup-T => -> %prm, $tmpl {
				my PStr $rv .= new('<terminal>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</terminal>'
			},
            #| U< DISPLAY-TEXT >
            #| Unusual (typically rendered with underlining)
			markup-U => -> %prm, $tmpl {
				my PStr $rv .= new('<unusual>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</unusual>'
			},
            #| V< DISPLAY-TEXT >
            #| Verbatim (internal markup instructions ignored)
			markup-V => -> %prm, $tmpl {
				my PStr $rv .= new('<verbatim>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</verbatim>'
			},

            ##| Markup codes, optional display and meta data

            #| A< DISPLAY-TEXT |  METADATA = ALIAS-NAME >
            #| Alias to be replaced by contents of specified V<=alias> directive
			markup-A => -> %prm, $tmpl {
				my PStr $rv .= new('<alias>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</alias>'
			},
            #| E< DISPLAY-TEXT |  METADATA = HTML/UNICODE-ENTITIES >
            #| Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> )
			markup-E => -> %prm, $tmpl {
				my PStr $rv .= new('<entity>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</entity>'
			},
            #| F< DISPLAY-TEXT |  METADATA = LATEX-FORM >
            #| Formula inline content ( F<ALT|LaTex notation> )
			markup-F => -> %prm, $tmpl {
				my PStr $rv .= new('<formula>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</formula>'
			},
            #| L< DISPLAY-TEXT |  METADATA = TARGET-URI >
            #| Link ( L<display text|destination URI> )
			markup-L => -> %prm, $tmpl {
				my PStr $rv .= new('<link>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</link>'
			},
            #| P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            #| Placement link
			markup-P => -> %prm, $tmpl {
				my PStr $rv .= new('<placement>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</placement>'
			},

            ##| Markup codes, mandatory display and meta data
            #| D< DISPLAY-TEXT |  METADATA = SYNONYMS >
            #| Definition inline ( D<term being defined|synonym1; synonym2> )
			markup-D => -> %prm, $tmpl {
				my PStr $rv .= new('<definition>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</definition>'
			},
            #| Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            #| Delta note ( Δ<visible text|version; Notification text> )
            markup-Δ => -> %prm, $tmpl {
				my PStr $rv .= new('<delta>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</delta>'
			},
            #| M< DISPLAY-TEXT |  METADATA = WHATEVER >
            #| Markup extra ( M<display text|functionality;param,sub-type;...>)
			markup-M => -> %prm, $tmpl {
				my PStr $rv .= new('<markup>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</markup>'
			},
            #| X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            #| Index entry ( X<display text|entry,subentry;...>)
			markup-X => -> %prm, $tmpl {
				my PStr $rv .= new('<index>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</index>'
			},
            #| Unknown markup, render minimally
            markup-unknown => -> %prm, $tmpl {
				my PStr $rv .= new('<unknown>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</unknown>'
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
                my PStr $rv .= new("<code>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</code>\n"
            },
            #| renders =input block
            input => -> %prm, $tmpl {
                my PStr $rv .= new("<input>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</input>\n"
            },
            #| renders =output block
            output => -> %prm, $tmpl {
                my PStr $rv .= new("<output>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</output>\n"
            },
            #| renders =comment block
            comment => -> %prm, $tmpl {
                my PStr $rv .= new("<comment>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</comment>\n"
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
                my PStr $rv .= new("<numhead>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</numhead>\n"
            },
            #| renders =defn block
            defn => -> %prm, $tmpl {
                my PStr $rv .= new("<defn>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</defn>\n"
            },
            #| renders =item block
            item => -> %prm, $tmpl {
                my PStr $rv .= new("<item>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</item>\n"
            },
            #| renders =numitem block
            numitem => -> %prm, $tmpl {
                my PStr $rv .= new("<numitem>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</numitem>\n"
            },
            #| renders =nested block
            nested => -> %prm, $tmpl {
                my PStr $rv .= new("<nested>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</nested>\n"
            },
            #| renders =para block
            para => -> %prm, $tmpl {
                my PStr $rv .= new("<para>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</para>\n"
            },
            #| renders =rakudoc block
            rakudoc => -> %prm, $tmpl {
                my PStr $rv .= new("<rakudoc>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</rakudoc>\n"
            },
            #| renders =section block
            section => -> %prm, $tmpl {
                my PStr $rv .= new("<section>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</section>\n"
            },
            #| renders =pod block
            pod => -> %prm, $tmpl {
                my PStr $rv .= new("<pod>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</pod>\n"
            },
            #| renders =table block
            table => -> %prm, $tmpl {
                my PStr $rv .= new("<table>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</table>\n"
            },
            #| renders =semantic block
            semantic => -> %prm, $tmpl {
                my PStr $rv .= new("<semantic>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</semantic>\n"
            },
            #| renders =custom block
            custom => -> %prm, $tmpl {
                my PStr $rv .= new("<custom>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</custom>\n"
            },
            #| renders any unknown block minimally
            unknown => -> %prm, $tmpl {
                my PStr $rv .= new("<unknown>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</unknown>\n"
            },
            #| special template to encapsulate all the output to save to a file
            source-wrap => -> %prm, $tmpl {
                my PStr $rv .= new("<source-wrap>\n");
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ "｣\n" }
				$rv ~= "</source-wrap>\n"
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
                "<footnotes>\n" ~ %prm<footnote-list>.join ~ "</footnotes>\n"
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
				my PStr $rv .= new('<basis>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</basis>'
			},
            #| C< DISPLAY-TEXT >
            #| Code (typically rendered fixed-width)
			markup-C => -> %prm, $tmpl {
				my PStr $rv .= new('<code>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</code>'
			},
            #| H< DISPLAY-TEXT >
            #| High text (typically rendered superscript)
			markup-H => -> %prm, $tmpl {
				my PStr $rv .= new('<high>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</high>'
			},
            #| I< DISPLAY-TEXT >
            #| Important (typically rendered in italics)
			markup-I => -> %prm, $tmpl {
				my PStr $rv .= new('<important>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</important>'
			},
            #| J< DISPLAY-TEXT >
            #| Junior text (typically rendered subscript)
			markup-J => -> %prm, $tmpl {
				my PStr $rv .= new('<junior>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</junior>'
			},
            #| K< DISPLAY-TEXT >
            #| Keyboard input (typically rendered fixed-width)
			markup-K => -> %prm, $tmpl {
				my PStr $rv .= new('<keyboard>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</keyboard>'
			},
            #| N< DISPLAY-TEXT >
            #| Note (not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.))
			markup-N => -> %prm, $tmpl {
				my PStr $rv .= new('<note>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</note>'
			},
            #| O< DISPLAY-TEXT >
            #| Overstrike or strikethrough
			markup-O => -> %prm, $tmpl {
				my PStr $rv .= new('<overstrike>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</overstrike>'
			},
            #| R< DISPLAY-TEXT >
            #| Replaceable component or metasyntax
			markup-R => -> %prm, $tmpl {
				my PStr $rv .= new('<replaceable>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</replaceable>'
			},
            #| S< DISPLAY-TEXT >
            #| Space characters to be preserved
			markup-S => -> %prm, $tmpl {
				my PStr $rv .= new('<space>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</space>'
			},
            #| T< DISPLAY-TEXT >
            #| Terminal output (typically rendered fixed-width)
			markup-T => -> %prm, $tmpl {
				my PStr $rv .= new('<terminal>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</terminal>'
			},
            #| U< DISPLAY-TEXT >
            #| Unusual (typically rendered with underlining)
			markup-U => -> %prm, $tmpl {
				my PStr $rv .= new('<unusual>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</unusual>'
			},
            #| V< DISPLAY-TEXT >
            #| Verbatim (internal markup instructions ignored)
			markup-V => -> %prm, $tmpl {
				my PStr $rv .= new('<verbatim>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</verbatim>'
			},

            ##| Markup codes, optional display and meta data

            #| A< DISPLAY-TEXT |  METADATA = ALIAS-NAME >
            #| Alias to be replaced by contents of specified V<=alias> directive
			markup-A => -> %prm, $tmpl {
				my PStr $rv .= new('<alias>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</alias>'
			},
            #| E< DISPLAY-TEXT |  METADATA = HTML/UNICODE-ENTITIES >
            #| Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> )
			markup-E => -> %prm, $tmpl {
				my PStr $rv .= new('<entity>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</entity>'
			},
            #| F< DISPLAY-TEXT |  METADATA = LATEX-FORM >
            #| Formula inline content ( F<ALT|LaTex notation> )
			markup-F => -> %prm, $tmpl {
				my PStr $rv .= new('<formula>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</formula>'
			},
            #| L< DISPLAY-TEXT |  METADATA = TARGET-URI >
            #| Link ( L<display text|destination URI> )
			markup-L => -> %prm, $tmpl {
				my PStr $rv .= new('<link>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</link>'
			},
            #| P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            #| Placement link
			markup-P => -> %prm, $tmpl {
				my PStr $rv .= new('<placement>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</placement>'
			},

            ##| Markup codes, mandatory display and meta data
            #| D< DISPLAY-TEXT |  METADATA = SYNONYMS >
            #| Definition inline ( D<term being defined|synonym1; synonym2> )
			markup-D => -> %prm, $tmpl {
				my PStr $rv .= new('<definition>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</definition>'
			},
            #| Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            #| Delta note ( Δ<visible text|version; Notification text> )
            markup-Δ => -> %prm, $tmpl {
				my PStr $rv .= new('<delta>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</delta>'
			},
            #| M< DISPLAY-TEXT |  METADATA = WHATEVER >
            #| Markup extra ( M<display text|functionality;param,sub-type;...>)
			markup-M => -> %prm, $tmpl {
				my PStr $rv .= new('<markup>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</markup>'
			},
            #| X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            #| Index entry ( X<display text|entry,subentry;...>)
			markup-X => -> %prm, $tmpl {
				my PStr $rv .= new('<index>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</index>'
			},
            #| Unknown markup, render minimally
            markup-unknown => -> %prm, $tmpl {
				my PStr $rv .= new('<unknown>');
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ $v ~ '｣' }
				$rv ~= '</unknown>'
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