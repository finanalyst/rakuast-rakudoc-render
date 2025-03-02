use experimental :rakuast;
use RakuDoc::Processed;
use RakuDoc::Templates;
use RakuDoc::ScopedData;
use RakuDoc::MarkupMeta;
use RakuDoc::PromiseStrings;
use RakuDoc::Numeration;
use LibCurl::Easy;
use Digest::SHA1::Native;
use PrettyDump;
use URI;

enum RDProcDebug <None All AstBlock BlockType Scoping Templates MarkUp>;

class RakuDoc::Processor {
    has %.templates is Template-directory;
    has PCellTracker $.register .= new;
    has RakuDoc::Processed $.current;
    has $.output-format;
    has RakuDoc::ScopedData $!scoped-data .= new;
    #| debug modes that are checked
    has SetHash $!debug-modes .= new;
    #| installed plugins to prevent re-installation
    has SetHash $.installed-plugins .= new;

    multi method debug(RDProcDebug $type --> Nil ) {
        given $type {
            when None {
                $!debug-modes = Nil;
                %!templates.debug = False;
                $!scoped-data.debug = False;
            }
            when All {
                $!debug-modes .= new( RDProcDebug::.values.grep( none( All, None )) );
                %!templates.debug = True;
                $!scoped-data.debug = True;
            }
            when Templates {
                %!templates.debug = True;
                proceed
            }
            when Scoping {
                $!scoped-data.debug = True;
                proceed
            }
            default {
                $!debug-modes{ $type }++
            }
        }
    }
    multi method debug( Str $type --> Nil ) {
        with RDProcDebug::{$type} {
            self.debug( $_ )
        }
        elsif $type ~~ / \s / {
            self.debug( $type.split(/ \s+ /) )
        }
        else { Nil }
    }
    multi method debug( *@types --> Nil ) {
        for @types {
            $.debug( $_ )
        }
    }
    multi method debug {
        $!debug-modes
    }
    method verbose( Str $template ){ # hook onto $!templates
        %!templates.verbose = $template
    }
    method test( $flag ){ # hook onto $!templates
        %!templates.test = $flag
    }
    method pretty( $flag ){ # hook onto $!templates
        %!templates.pretty = $flag
    }
    method add-data( $key, $object ) {
        %!templates.data{ $key } = $object;
    }

    multi submethod TWEAK(:$!output-format = 'txt',
     :$test = False,
     :$pretty = False,
     :$debug = None ) {
        %!templates.source = 'Default text templates' ;
        %!templates = self.default-text-templates;
        %!templates.test = $test;
        %!templates.pretty = $pretty;
        %!templates.helper = self.default-helpers;
        %!templates.escape = -> $s { self.escape( $s ) };
        %!templates.mangle = -> $s { self.mangle( $s ) };
        if $debug ~~ List { self.debug($debug.list) }
        else { self.debug( $debug ) }
    }

    method add-template( Pair $t, :$source ) {
        %!templates.source = $source with $source;
        %!templates{ $t.key } = $t.value
    }
    method add-templates( Hash $tt, :$source! ) {
        %!templates.source = $source with $source;
        for $tt.pairs {
            %!templates{ .key } = .value
        }
    }

    #| renders to a String by default,
    #| but returns ProcessedState object if pre-finalised = True
    multi method render( $ast, :%source-data, :pre-finalized(:$pre-finalised) = False ) {
        $!current .= new(:%source-data, :$!output-format );
        %!templates.data<source-data> := $!current.source-data;
        $!register .= new;
        $!scoped-data .= new;
        $!scoped-data.debug = $!debug-modes{ Scoping }.so;
        my ProcessedState $*prs .= new;
        if $ast ~~ RakuAST::StatementList {
            $ast.rakudoc.map( { $.handle( $_ ) } )
        }
        elsif $ast ~~ List {
            $ast.map( { $.handle( $_ ) } )
        }
        else { return 'Unknown type of AST' }
        $!current += $*prs;
        # neither of the approaches below allow for multi-threading.
        # both fail on xt/055-debug-vals, and -simple-render.
## yields error with Numeric(ProcessedState:D) cant be resolved
#        $ast.rakudoc.map( {
#            $.handle( $_ );
#            $!current += $*prs;
#        }).hyper;
## following yields a different set of errors to .hyper and is MUCH slower!
#        # to get multithreading
#        my @leaves;
#        for $ast.rakudoc {
#            @leaves.push: start { $.handle($_) };
#        }
#        await.allof( @leaves );
#        $!current += $*prs;
        # placed semantic blocks now need triggering
        for $!register.list-unexpanded('semantic').kv -> $id, $spec {
            if $!current.semantics{$spec}:exists {
                $!register.add-payload( :payload( $!current.semantics{$spec}.join ), :id("semantic_$spec") )
            }
            else {
                $!current.warnings.push: "Placement of undefined semantic block $spec"
            }
        }
        # Since the footnote order may only be known at the end
        # footnote numbers are PCells, which need triggering
        self.complete-footnotes;
        # P<toc:>, P<index:> may put PCells into body
        # so ToC and Index need to be rendered and any other PCells triggered
        # toc may contain numbered captions, so the heading-numbers need to be calculated
        self.complete-heading-numerations;
        $!current.rendered-toc = self.complete-toc( :spec( '*' ), :caption( $!current.source-data<toc-caption>));
        my @pcells = $!current.rendered-toc.has-PCells;
        if @pcells.elems {
            $!current.warnings.push( 'In ToC: ' ~ $_ ) for @pcells
        }
        $!current.rendered-toc .= Str;
        #render filtered toc, if any
        for $!register.list-unexpanded('toc').kv -> $id, $spec {
            my $payload = self.complete-toc( :$spec, :caption('')).strip.Str;
            $!register.add-payload(:$payload, :$id)
        }
        # make sure all 'place' elements in the index are strings, not PCells
        stringify-index( $!current.index );
        # render indices
        $!current.rendered-index = self.complete-index( :spec('*'), :caption( $!current.source-data<index-caption> ) );
        @pcells = $!current.rendered-index.has-PCells;
        if @pcells.elems {
            $!current.warnings.push( 'In Index: ' ~ $_ ) for @pcells
        }
        $!current.rendered-index .= Str;
        # place for rendering filtered index
        for $!register.list-unexpanded('index').kv -> $id, $spec {
                $!register.add-payload(:payload( self.complete-index(:$spec, :caption('')).strip.Str ) , :$id);
        }
        $!current.body.strip; # replace expanded PCells with Str
        # all suspended PCells should have been replaced by Str
        # Remaining PCells should trigger warnings
        @pcells = $!current.body.has-PCells;
        if @pcells.elems {
            $!current.warnings.push( $_ ) for @pcells
        }
        $pre-finalised ?? $.current !! $.finalise
    }

    method finalise( --> Str ) {
        $.post-process(
            %!templates<final>( %(
                :body($!current.body.Str),
                :source-data($!current.source-data),
                :front-matter($!current.front-matter),
                :name($!current.name),
                :title($!current.title),
                :title-target($!current.title-target),
                :subtitle($!current.subtitle),
                :modified($!current.modified),
                :rendered-toc($!current.rendered-toc),
                :rendered-index($!current.rendered-index),
                :footnotes(%!templates<footnotes>( %( :footnotes( $!current.footnotes ),) )),
                :warnings(%!templates<warnings>( %(:warnings($!current.warnings),))),
            ) ).Str
        )
    };

    #| This method is used to post process the final rendered output
    #| Use case: change targets to line numbers in a text output
    #| It should be overridden in subclasses for other outputs
    method post-process( Str:D $final --> Str ) {
        return $final unless (%*ENV<POSTPROCESSING>:exists and %*ENV<POSTPROCESSING> == 1);
        my $width = %*ENV<WIDTH> // 80; #$!current.source-data<line-width> // 80;
        my $end-zone = %*ENV<LINE-WIDTH> // 6;#$!current.source-data<line-width> // 6;
        $width = 80 if $width < $end-zone;
        my $remaining = $final;
        my @lines;
        my Bool $hyphen = False;
        my Bool $nl = False;
        while ( $remaining ~~ / ^
                  (\v)
                | ( .**{0..$width} \v )
                | ( .**{ $width - $end-zone } \S+ ) \s{ $nl = True }
                | ( .**{ $width - 1 } ) { $hyphen = $nl = True }
                / ) {
            my $l = ~$/[0];
            $remaining = ~$/.postmatch;
            $l ~= '-' and ( $hyphen = False ) if $hyphen;
            $l ~= "\n" and ( $nl = False ) if $nl;
            @lines.push: $l
        }
        @lines.push( $remaining);
        @lines.join('')
    }

    method compactify( Str:D $s ) {
        self.escape($s.subst(/ \v+ /,' ',:g )
        .subst(/ <?after \S\s> \s+ /, '', :g))
    }

    # Section dealing with plugins
    #| plugins are enabled by calling their .enable method on the processor
    #| typically the enable method will create the plugin's dataspace and add templates
    method add-plugins( @plugin-list ) {
        for @plugin-list -> $plugin {
            if $plugin (elem) $!installed-plugins {
                note "Attempted to re-install ｢$plugin｣, ignoring duplicate installation";
                next
            }
            else { $!installed-plugins{ $plugin }++ }
            require ::($plugin);
            CATCH {
                note "$plugin is not installed";
                .resume
            }
            try {
                ::($plugin).new.enable( self )
            }
            with $! {
                note "Could not enable «$plugin» in Render. Error: ", .message;
            }
        }
    }

    #| plugins attach information about assets (eg. css/js & cdn for html) as arrays of Str/order tuples
    #| This needs to be gathered from all plugins, and processed for templates
    multi method gather-flatten( @keys, :@reserved ) { $.gather-flatten( $_, :@reserved ) for @keys }
    multi method gather-flatten( $key, :@reserved = () ) {
        my %d := $.templates.data;
        my %valid = %d.pairs
            .grep({ .key ~~ none(@reserved) })
            .grep({ .value.{ $key } ~~ Positional })
            .map( { .key => .value.{ $key } });
        my @p-tuples;
        for %valid.kv -> $plugin, $tuple-list {
            if $tuple-list ~~ Positional {
                for $tuple-list.list {
                    if .[0] ~~ Str && .[1] ~~ Int {
                        @p-tuples.push: $_
                    }
                    else { note "Element ｢$_｣ of config attribute ｢$key｣ for plugin ｢$plugin｣ not a [Str, Int] tuple"}
                }
            }
            else { note "Config attribute ｢$key｣ for plugin ｢$plugin｣ must be a Positional, but got ｢$tuple-list｣"}
        }
        if %d{ $key }:exists { # this is true for css from HTML, add it with zero order.
            @p-tuples.push: [ %d{ $key }, 0]
        }
        %d{ $key } = @p-tuples.sort({ .[1], .[0] }).map( *.[0] ).list;
    }


    #| All handle methods may generate debug reports
    proto method handle( $ast ) {
        say "Handling: { $ast.WHICH.Str.subst(/ \| .+ $/, '') }"
            if $.debug (cont) AstBlock;
        {*}
    }
    multi method handle(Str:D $ast) {
        $*prs.body ~=
            $!scoped-data.verbatim
            ?? ~$ast !! $.compactify( $ast )
    }
    multi method handle(RakuAST::Node:D $ast) {
        $ast.rakudoc.map({ $.handle($_) })
    }
    multi method handle(RakuAST::Doc::Block:D $ast) {
        my $prs := $*prs;
        if $!scoped-data.verbatim {
            $prs.body ~= $ast.set-paragraphs( $ast.paragraphs.map({ $.handle($_) }) ).DEPARSE;
            return
        }
        # When a block is extended, then bare Str should be considered paragraphs
        my Bool $parify = ! ($ast.for or $ast.abbreviated);
        my $type = $ast.type;
        say "Doc::Block type: $type"
            ~ ( ' [for]' if $ast.for )
            ~ ( ' [abbreviated]' if $ast.abbreviated )
            ~ ( ' [extended]' if $parify )
            if $.debug (cont) BlockType;
        # When any block, other than =item or =defn, is started,
        # there may be a list of preceding items or defns, which need to be
        # completed and rendered
        $prs.body ~= $.complete-item-list unless $type eq 'item';
        $prs.body ~= $.complete-defn-list unless $type eq 'defn';
        $prs.body ~= $.complete-numitem-list unless $type eq 'numitem';
        $prs.body ~= $.complete-numdefn-list unless $type eq 'numdefn';

        # Not all Blocks create a new scope. Some change the current scope data
        given $ast.type {
            # =alias
            # Define a RakuDoc macro, scoped to the current block
            when 'alias' { $.manage-alias( $ast ) }
            # =implicit code created by indenting, but by specification is treated as code
            when 'implicit-code' { $.gen-paraish( $ast, 'code', $parify ) }
            # =code
            # =para block, as opposed to unmarked paragraphs in a block
            # not the same as a logical Doc::Paragraph, which has atoms, not paragraphs
            # =nested
            # Nest block contents within the current context
            # unlike =section, does not create block scope
            # =input
            # Pre-formatted sample input
            # =output
            # Pre-formatted sample output
            when any(<code para nested input output>) {
                $.gen-paraish( $ast, $ast.type, $parify )
            }
            # =comment
            # Content to be ignored by all renderers
            when 'comment' { '' }
            # =config
            # Block scope modifications to a block or markup instruction
            when 'config' { $.manage-config($ast); }
            # =formula
            # Render content as LaTex formula
            when 'formula' { $.gen-formula($ast) }
            # =head
            # First-level heading
            # =headN
            # Nth-level heading
            when 'head' { $.gen-headish($ast, $parify) }
            # =numhead
            # First-level numbered heading
            # =numheadN
            # Nth-level numbered heading
            # heading numeration is fixed when TOC is generated and all headers are known
            when 'numhead' { $.gen-headish( $ast, $parify, :template<numhead>, :numerate) }
            # =item
            # First-level list item
            # =itemN
            # Nth-level list item
            when 'item' { $.gen-item($ast, $parify) }
            # =defn
            # Definition of a term
            when 'defn' { $.gen-defn($ast) }
            # =numitem
            # First-level numbered list item
            # =numitemN
            # Nth-level numbered list item
            when 'numitem' { $.gen-numitem($ast, $parify) }
            # =numdefn
            when 'numdefn' { $.gen-defn($ast, :numerate) }
            # =place block, mostly mimics P<>, but allows for TOC and caption
            when 'place' { $.gen-place($ast) }
            # =rakudoc
            # No "ambient" blocks inside
            # could be called if P<> embeds a RakuDoc file
            when 'rakudoc' | 'pod' {
                my $rak-level := $!current.source-data<rakudoc-level>;
                if $!scoped-data.last-starter eq 'original level' {
                    $!scoped-data.start-scope(:starter($_), :title( $!current.source-data<rakudoc-title> ));
                     $rak-level = 1;
                }
                else {
                    $!scoped-data.start-scope(:starter($_), :title( 'embed RakuDoc' ));
                    if ++$rak-level > 5 {
                        $*prs.warnings.push: 'Attempting to embed more than five levels of rakudoc sources. Contents of deeper rakudoc blocks ignored.';
                    }
                }
                $.gen-rakudoc($ast, $parify) unless $rak-level > 5;
                $!scoped-data.end-scope;
                $rak-level -= 1;
            }
            # =pod
            # Legacy version of rakudoc
#           when 'pod' { '' } # when rakudoc differs from pod
            # =section
            # Defines a section
            when 'section' {
                $!scoped-data.start-scope( :starter($_) ); # title will be a Block number
                $.gen-section($ast, $parify);
                $!scoped-data.end-scope;
            }
            # =table
            # Visual or procedural table
            when 'table' { #toc
                $!scoped-data.start-scope( :starter($_) ); # title will be a Block number
                $.gen-table($ast);
                $!scoped-data.end-scope;
            }
            # =cell
            # Contains data in a procedural table
            # =column
            # Start a new column in a procedural table
            # =row
            # Start a new row in a procedural table
            when any(<cell column row>) {
                $prs.warnings.push: qq:to/WARN/;
                The text ｢{ $ast.DEPARSE }｣ may not exist outside a 'table' block.
                WARN
            }
            # RESERVED
            # Semantic blocks (SYNOPSIS, TITLE, etc.)
            when all($_.uniprops) ~~ / Lu / {  #toc
                # in RakuDoc v2 a Semantic block must have all uppercase letters
                $!scoped-data.start-scope( :starter($_) );
                $.gen-semantics($ast, $parify);
                $!scoped-data.end-scope;
            }
            # CustomName
            # User-defined block
            when any($_.uniprops) ~~ / Lu / and any($_.uniprops) ~~ / Ll / { #toc
                # in RakuDoc v2 a Semantic block must have mix of uppercase and lowercase letters
                $!scoped-data.start-scope( :starter($_) );
                $!scoped-data.last-title( $_ );
                $.gen-custom($ast, $parify);
                $!scoped-data.end-scope;
            }
            default { $.gen-unknown-builtin($ast) }
        }
    }
    # RakuDoc declarator block
    multi method handle(RakuAST::Doc::DeclaratorTarget:D $ast) {
        $*prs.warnings.push: qq:to/WARN/;
            ｢{ $ast.DEPARSE }｣ is a declarator block and not rendered for text-based output formats.
            WARN
    }
    my @format-codes = <B H I J K R T U O>;
    multi method handle(RakuAST::Doc::Markup:D $ast) {
        my $letter = $ast.letter;
        my $prs := $*prs;
        say "Doc::Markup letter: $letter" if $.debug (cont) MarkUp;
        my %config = $.merged-config( $, $letter );
        %config<in-code> = $!scoped-data.verbatim;
        if (
            $!scoped-data.verbatim(:called-by) eq <code markup-C markup-V>.any
            )
            && %*ALLOW.defined && !%*ALLOW{ $letter }
            {
            given $letter {
                when 'A' | 'D' | 'F' | 'L' | 'M' | 'P' | 'X' | 'Δ'  {
                    $prs.body ~= $letter ~ self.escape($ast.opener) ~ self.markup-contents($ast);
                    if $ast.meta -> $_ { $prs.body ~= '|' ~ self.markup-contents( $ast, :meta ) }
                    $prs.body ~= self.escape($ast.closer)
                }
                when 'E' {
                    $prs.body ~= $letter ~ self.escape($ast.opener) ~ self.markup-contents($ast);
                    if $ast.meta -> $_ { $prs.body ~= '|' ~ .map(*.key).join('; ') }
                    $prs.body ~= self.escape($ast.closer)
                }
                default { $prs.body ~= self.escape($ast.DEPARSE) }
            }
            return
        }
        # for X<> and to help with warnings
        my $place = $!scoped-data.last-title;
        my $context = $!scoped-data.last-starter;
        given $letter {
            ## Markup codes with only display (format codes), no meta data allowed
            ## meta data via Config is allowed
            when @format-codes {
                my $contents = self.markup-contents($ast);
                $prs.body ~= %!templates{"markup-$letter"}(
                    %( :$contents, %config )
                );
            }
            # Do not eat space inside markup
            when 'S' {
                $prs.body ~= %!templates{"markup-$letter"}(
                    %( :contents( $ast.atoms.join ), %config )
                );
            }
            # Make verbatim, but compactify space
            when any( <C V> ) {
                my %*ALLOW = %( CALLERS::<%*ALLOW> );
                # replace contents of %*ALLOW if so configured
                if %config<allow>:exists {
                    %*ALLOW = Empty;
                    %*ALLOW = %config<allow>
                    .grep({ any(@format-codes) })
                    .map({ $_ => True }).hash;
                }
                $!scoped-data.start-scope(:starter("markup-$letter"), :verbatim);
                my $contents = $.markup-contents($ast);
                $prs.body ~= %!templates{"markup-$letter"}(
                    %( :$contents, %config )
                );
                $!scoped-data.end-scope
            }
            ## Display only, but has side-effects
            #| Footnotes (from N<> markup)
            #| Ordered Array of :$text, :$retTarget, :$fnNumber, :$fnTarget
            #| text is content of footnote, fnNumber is footNote number
            #| fnTarget is link to rendered footnote
            #| retTarget is link to where footnote is defined to link back form footnote
            when 'N' {
                my $id = self.name-id(textify-markup($ast));
                my $contents = self.markup-contents($ast);
                my $retTarget = $id;
                my $fnNumber = PCell.new( :id("fn_num_$id"), :$!register);
                my $fnTarget = "fn_target_$id";
                # fnNumber is changed by complete-footnotes at end of rendering
                $prs.footnotes.push: %( :$contents, :$retTarget, :0fnNumber, :$fnTarget );
                my $rv = %!templates<markup-N>(
                    %( %config, :$retTarget, :$fnNumber, :$fnTarget )
                );
                $prs.body ~= $rv;
            }

            ## Markup codes, optional display and meta data

            # A< DISPLAY-TEXT |  METADATA = ALIAS-NAME >
            # Alias to be replaced by contents of specified V<=alias> directive
            when 'A' {
                my $term = self.markup-contents($ast).Str;
                my $alt = '';
                # check to see if there is a text to over-ride automatic failure message
                if $ast.meta {
                    $alt = $term;
                    $term = $ast.meta.Str
                }
                elsif $term ~~ / ^ (<-[ | ]>+) \| (.+) $ / {
                    $alt = ~$0.trim;
                    $term = ~$1.trim
                }
                my $contents;
                if $!scoped-data.aliases{ $term }:exists {
                    $contents = $!scoped-data.aliases{ $term }
                }
                else {
                    $contents = $term;
                    $contents = $alt if $alt;
                    $prs.warnings.push(
                        "Unknown or as yet undeclared alias ｢$term｣"
                        ~ " in block ｢$context｣ with heading ｢$place｣"
                        ~ ( $alt ?? " over-riden by ｢$alt｣" !! ''  ))
                        if %config<error>
                }
                $prs.body ~ %!templates<markup-A>( %( :$contents, %config ) )
            }
            # E< DISPLAY-TEXT |  METADATA = HTML/UNICODE-ENTITIES >
            # Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> )
            # included with format codes
            when 'E' {
                my $contents = $ast.meta.map(*.values).join;
                $prs.body ~= %!templates<markup-E>(
                    %( :$contents, %config )
                );
            }
            # F< DISPLAY-TEXT |  METADATA = LATEX-FORM >
            # Formula inline content ( F<ALT|LaTex notation> )
            # At a minimum, only the ALT text should be rendered. But the metadata is passed to the
            # template, so the template can be adapted to render the LATEX formula.
            when 'F' {
                my $formula = $.markup-contents($ast).Str;
                my $contents = $formula;
                $formula = $ast.meta if $ast.meta;
                $prs.body ~= %!templates<markup-F>( %( :$contents, :$formula, %config ) )
            }
            # L< DISPLAY-TEXT |  METADATA = TARGET-URI >
            # Link ( L<display text|destination URI> )
            when 'L' {
                my $link-label = self.markup-contents($ast).Str;
                my $entry = $ast.meta;
                with $entry[0] {
                    $entry = $entry[0].Str
                }
                else {
                    $entry = $link-label
                }
                my $target;
                my $extra = '';
                my $type;
                if $!current.links{$entry}:exists {
                    ($target, $type, $extra) = $!current.links{$entry}<target type extra>
                }
                else {
                    given $entry {
                        # remote links first, if # in link, that will be handled by destination
                        when / ^ 'http://' | ^ 'https://' / {
                            $target = $_;
                            $type = 'external';
                        }
                        # next deal with internal links
                        when / ^ '#' $<tgt> = (.+) $ / {
                            $target = $.local-heading( ~$<tgt>);
                            $type = 'internal';
                        }
                        when / ^ (.+?) '#' (.+) $ / {
                            $extra = ~$1;
                            $target = ~$0.subst(/'::'/, '/', :g); # only subst :: in file part
                            $type = 'local';
                        }
                        when / ^ 'defn:' $<term> = (.+) $ / {
                            $type = 'defn';
                            $link-label = ~$<term>;
                            # get definition from Processed state, or make a PCell
                            my %definitions = $prs.definitions;
                            if %definitions{ $link-label }:exists {
                                $extra = %definitions{ $link-label }[0];
                                $target = %definitions{ $link-label }[1]
                            }
                            else {
                                $extra = PCell.new( :$!register, :id($link-label));
                                $target = PCell.new( :$!register, :id($link-label ~ '_target' ))
                            }
                        }
                        when '' { # this is an error condition
                            $target = '';
                            $type = 'internal';
                            $extra = '';
                        }
                        default {
                            $target = $entry;
                            $type = 'local';
                            $extra = '';
                        }
                    }
                }
                $!current.links{$_} = %(:$target, :$link-label, :$type, :$extra);
                my $rv = %!templates{"markup-$letter"}(
                    %( :$target, :$link-label, :$type, :$extra, :$!output-format, %config)
                );
                $prs.body ~= $rv;
            }
            # P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            # Placement link
            when 'P' {
                # The contents of P<> markup must be a Str.
                my $uri = self.markup-contents($ast).Str;
                # check to see if there is a text to over-ride automatic failure message
                if $ast.meta {
                    %config<fallback> = $uri;
                    $uri = $ast.meta.Str
                }
                elsif $uri ~~ / ^ (<-[ | ]>+) \| (.+) $ / {
                    %config<fallback> = ~$0;
                    $uri = ~$1
                }
                $.make-placement(:$uri, :%config, :template<markup-P>);
            }

            ## Markup codes, mandatory display and meta data
            # D< DISPLAY-TEXT |  METADATA = SYNONYMS >
            # Definition inline ( D<term being defined|synonym1; synonym2> )
            when 'D' {
                my $contents = self.markup-contents($ast).Str; # is the term, may not have embedded markup
                my $meta = RakuDoc::MarkupMeta.parse( ~$ast.meta.trim, actions => RMActions.new );
                my @terms = $contents, ;
                if $meta.so {
                    given $meta.made<type> {
                        when 'plain-string' or 'plain-string-array' { # treat as verbatim
                            @terms.push: ~$/
                        }
                        when 'array-of-ps-arrays' { # add back ,
                            @terms.append: $meta.made<value>>>.join(', ')
                        }
                   }
                }
                else {
                    $prs.warnings.push("Ignored unparsable definition synonyms ｢{ ~$ast.meta }｣"
                        ~ " in block ｢$context｣ with heading ｢$place｣.")
                        if %config<error>
                }
                my $rv = %!templates{"markup-$letter"}(
                    %( :$contents, %config )
                );
                $prs.inline-defns.append: @terms;
                $prs.body ~= $rv
            }
            # Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            # Delta note ( Δ<visible text|version; Notification text> )
            when 'Δ' {
                my $contents = self.markup-contents($ast);
                my $meta = '';
                my $note = '';
                my $versions = '';
                if $ast.meta {
                    $meta = $ast.meta.Str
                }
                elsif $contents ~~ / ^ (<-[|]>+) \| (.+) $ / {
                    $contents = ~$0;
                    $meta = ~$1
                }
                if $meta {
                    if $meta ~~ / ^ (<-[;]>+) ';' (.+) $ / {
                        $versions = ~$0;
                        $note = ~$1
                    }
                    else { $versions = $meta }
                    $prs.body ~=  %!templates{"markup-Δ"}(
                        %( :$contents, :$versions, :$note, %config)
                    )
                }
                else {
                    $prs.warnings.push("Δ<> markup ignored because it has no version/note content ｢{ ~$ast.DEPARSE }｣"
                        ~ " in block ｢$context｣ with heading ｢$place｣.")
                        if %config<error>;
                    # treat as verbatim text
                    $prs.body ~= %!templates<markup-V>( %( :$contents, %config ))
                }
            }
            # M< DISPLAY-TEXT |  METADATA = WHATEVER >
            # Markup extra ( M<display text|functionality;param,sub-type;...>)
            when 'M' {
                my $contents = self.markup-contents($ast);
                unless $ast.meta {
                    $prs.body ~= %!templates<markup-M>( %(:$contents ) );
                    $prs.warnings.push("Markup-M failed: no meta information. Got ｢{ $ast.DEPARSE }｣")
                        if %config<error>;
                    return
                }
                my $meta = RakuDoc::MarkupMeta.parse( $ast.meta, actions => RMActions.new ).made<value>;
                my $target = self.index-id(:$contents);
                my $template = $meta[0].Str;
                if any($template.uniprops) ~~ / Lu / and any($template.uniprops) ~~ / Ll / {
                    # template has an acceptable custom template spelling
                    if %!templates{ $template }:exists {
                        $prs.body ~= %!templates{ $template }( %(:$contents, :$meta ) );
                    }
                    else {
                        $prs.body ~= %!templates<markup-M>( %(:$contents, :$target ) );
                        $prs.warnings.push("Markup-M failed: template ｢$template｣ does not exist. Got ｢{ $ast.DEPARSE }｣")
                        if %config<error>
                    }
                }
                else {
                    # template is spelt like a SEMANTIC or builtin
                    $prs.body ~= %!templates<markup-M>( %(:$contents ) );
                    $prs.warnings.push("Markup-M failed: first meta string must conform to Custom template spelling. Got ｢{ $ast.DEPARSE }｣")
                        if %config<error>
                }
            }
            # X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            # Index entry ( X<display text|entry,subentry;...>)
            #| Index (from X<> markup)
            #| Hash entry => Hash of :refs, :sub-index
            #| :sub-index (maybe empty) is Hash of sub-entry => :refs, :sub-index
            #| :refs is Array of (Hash :target, :place, :is-header)
            #| :target is for link, :place is section name
            #| :is-header because X<> in headings treated differently to ordinary text
            when 'X' {
                my $contents = self.markup-contents($ast);
                #| if not in a head, then in-head is '', which has a False truth value
                my Bool $is-in-heading = $!scoped-data.in-head.so;
                # stringify contents without processing for targets
                my $meta = RakuDoc::MarkupMeta.parse( $ast.meta.trim, actions => RMActions.new );
                # if in a heading, then the scoped is-head attribute is a target for that title
                my $target = $is-in-heading ?? $!scoped-data.in-head
                    !! self.index-id(:contents(textify-markup($ast)));
                my %ref = %( :$target, :$is-in-heading, :$place );
                %ref<place> = PCell.new(:id($target),:$.register )
                    if $is-in-heading; # the title of the header is not known until later
                if $ast.meta and $meta { # this will be true if the MarkupMeta grammar parsed
                    if $meta.made<type> eq 'plain-string' {
                        $.merge-index( $prs.index, $.add-index( $meta.made<value>, %ref ))
                    }
                    else {
                        $.merge-index( $prs.index, $.add-index( $_, %ref )) for $meta.made<value>.list
                    }
                }
                elsif $ast.meta { # this is true if MarkupMeta grammar failed on an existing $ast.meta
                    $prs.index{$contents} = %( :refs( [] ), :sub-index( {} ) ) unless $prs.index{$contents}:exists;
                    $prs.index{$contents}<refs>.push: %ref;
                    $prs.warnings.push('Ignoring content of X<> after | ｢'
                        ~ $ast.meta.Str ~ '｣'
                        ~ " in block ｢$context｣ with heading ｢$place｣.")
                        if %config<error>
                }
                else { # no meta
                    $prs.index{$contents} = %( :refs( [] ), :sub-index( {} ) ) unless $prs.index{$contents}:exists;
                    $prs.index{$contents}<refs>.push: %ref
                }
                my $rv = %!templates{"markup-$letter"}(
                    %( :$contents, :$meta, :$target, :$place, :$is-in-heading, %config )
                ).Str;
                $prs.body ~= $rv;
            }

            ## Technically only meta data, but just contents

            # Z< METADATA = COMMENT >
            # Comment zero-width  (contents never rendered)
            when 'Z' {
                $prs.body ~= '';
            }

            ## Undefined and reserved, so generate warnings
            # do not go through templates as these cannot be redefined
            when any(<G Q W Y>) {
                $prs.body ~= %!templates{"markup-bad"}( %( :contents($ast.DEPARSE), ) );
                $prs.warnings.push(
                    "｢$letter｣ is not defined, but is reserved for future use"
                        ~ " in block ｢$context｣ with heading ｢$place｣.")
                    if %config<error>
            }
            when (.uniprop ~~ / Lu / and %!templates{ "markup-$letter" }:exists) {
                my $contents = self.markup-contents($ast);
                $prs.body ~= %!templates{ "markup-$letter" }(
                    %( :$contents, %config )
                );
            }
            when (.uniprop ~~ / Lu /) {
                $prs.body ~= %!templates{"markup-bad"}( %( :contents($ast.DEPARSE), ) );
                $prs.warnings.push(
                    "｢$letter｣ does not have a template, but could be a custom code"
                        ~ " in block ｢$context｣ with heading ｢$place｣.")
                    if %config<error>
            }
            default {
                $prs.body ~= %!templates{"markup-bad"}( %( :contents($ast.DEPARSE), ) );
                $prs.warnings.push("｢$letter｣ may not be a markup code"
                        ~ " in block ｢$context｣ with heading ｢$place｣.")
                    if %config<error>
            }
        }
    }
    #| This block is created by the parser when a text has embedded markup
    #| Also ordinary strings in an extended block are coerced into one
    #| Sometimes, eg for a table cell, the paragraph should not be
    #| ended with a newline.
    multi method handle(RakuAST::Doc::Paragraph:D $ast ) {
        if $!scoped-data.verbatim {
            $ast.atoms.map({ $.handle($_) });
            return
        }
        my $inline = $!scoped-data.last-starter eq 'table';
        my %config = $.merged-config($, 'para' );
        my $rem = $.complete-item-list ~ $.complete-defn-list
        ~ $.complete-numitem-list ~ $.complete-numdefn-list;
        do {
            my ProcessedState $*prs .= new;
            for $ast.atoms { $.handle($_) }
            my $prs := $*prs;
            my PStr $contents = $prs.body;
            # each para should have a target, generate a SHA if no id given
            my $target = %config<id> // $.para-target($contents);
            my $is-in-head = $!scoped-data.in-head.so;
            $prs.body .= new( $rem );
            my $rv = %!templates<para>(
                %( :$contents, :$target, :$inline, :$is-in-head, %config)
            );
            # deal with possible inline definitions
            if $prs.inline-defns.elems {
                for $prs.inline-defns.list -> $term {
                    $prs.warnings.push(
                        "Definition ｢$term｣ has been redefined as an inline"
                        ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.")
                        if $prs.definitions{ $term }:exists && %config<error>;
                    $prs.definitions{ $term } = $rv, $target;
                    $!register.add-payload(:payload($rv), :id($term));
                    $!register.add-payload(:payload($target), :id($term ~ '_target'))
                }
                $prs.inline-defns = ()
            }
            $prs.body ~= $rv;
            CALLERS::<$*prs> += $prs;
       }
    }
    multi method handle(RakuAST::Doc::LegacyRow:D $ast) {
        $*prs.warnings.push: qq:to/WARN/;
            The line ｢{ $ast.Str }｣ should not appear outside the scope of a =table
            WARN
    }
    multi method handle(Cool:D $ast) {
        self.handle($ast.WHICH.Str)
    }

    # helper methods for markup
    #| similar to merge-index in Processed, but simpler because less generic
    multi method merge-index( %p, %q ) {
        for %q.keys -> $k {
            if %p{$k}:exists {
                %p{$k}<refs>.append: %q{$k}<refs>.Slip;
                $.merge-index( %p{$k}<sub-index>, %q{$k}<sub-index> )
            }
            else {
                %p{$k} = %q{$k};
            }
        }
    }
    multi method add-index( Str:D $r, $ref ) {
        my @refs;
        @refs.push: $ref;
        %( $r => %( :@refs, sub-index => %( ) ) )
    }
    #| adding in a string means only the last element in the string has the reference
    #| the earlier ones only have references if given by other calls to index
    multi method add-index( @r, $ref --> Hash ) {
        return $.add-index( @r[0].Str, $ref ) if @r.elems == 1;
        my @refs;
        my %h = %( :@refs, sub-index => %( ) );
        $.merge-index( %h<sub-index>, $.add-index( @r[ 1 .. *-1 ] , $ref ) ) if @r[1 .. *-1].elems.so;
        %( @r[0] => %h.clone )
    }

    # gen-XX methods take an $ast, process the contents, based on a template,
    # and add the string to a structure, typically, not always, to $*prs.body

    #| generic code for next, para, code, input, output blocks
    #| No ToC content is added unless overridden by toc/caption/headlevel
    method gen-paraish( $ast, $template, $parify ) {
        my %config = $.merged-config( $ast, $template);
        if %config<toc> {
            my $caption = %config<caption> // $template.tc;
            my $level = %config<headlevel> // 1;
            $level = 1 if $level < 1;
            my $numeration = '';
            my $target = %config<id> // $.name-id($caption);
            $*prs.toc.push: %( :$caption, :$level, :$numeration, :$target );
            %config<target> = $target;
        }
        my PStr $contents .= new;
        $!scoped-data.start-scope(:starter($template), :verbatim )
            if $template ~~ any(<code implicit-code input output>);
        if $template eq 'code' {
            if %config<allow>:exists {
                %config<in_code_context> = True;
                my %*ALLOW = %config<allow>
                    .grep({ any(@format-codes) })
                    .map({ $_ => True }).hash;
                $contents ~= $.contents($ast, $parify);
            }
            else {
                $contents ~= $ast.paragraphs.map( *.Str ).join
            }
        }
        else {
            $contents ~= $.contents($ast, $parify);
        }
        my Bool $is-in-heading = $!scoped-data.in-head.so;
        $contents ~= $.complete-item-list;
        $contents ~= $.complete-defn-list;
        $contents ~= $.complete-numitem-list;
        $contents ~= $.complete-numdefn-list;
        $*prs.body ~= %!templates{ $template }(
            %( :$contents, :$is-in-heading, %config)
        );
        $!scoped-data.end-scope if $template ~~ any( <code implicit-code input output> )
    }
    #| A header adds contents at given level to ToC, unless overridden by toc/headlevel/caption
    #| These can be set by a config directive
    #| The id option may be used to create a target
    #| An automatic target is also created from the contents
    method gen-headish($ast, $parify, :$template = 'head', :$numerate = False ) {
        # stringify ast for internal use
        # set up data for embedded markup in header, eg., X
        my $title = textify-head($ast);
        my $target = $.name-id($title);
        $!scoped-data.start-scope(:starter('head'), :$title ) if $parify;
        # must set in-head in case of other inner scopes.
        $!scoped-data.in-head = $target;
        my $contents = $.contents($ast, $parify).strip.trim.Str;
        my $prs := $*prs;
        my $level = $ast.level > 1 ?? $ast.level !! 1;
        my %config = $.merged-config($ast,($template ~ $level) );
        my $caption = %config<caption>:delete;
        $caption = $contents without $caption;
        # allow internal X<> to have the final rendered title
        $!register.add-payload(:payload($caption), :id( $target ) );
        # set the last title for paragraphs following the title
        $!scoped-data.last-title( $caption );
        my $id = %config<id>:delete ;
        with $id {
            if self.is-target-unique( $_ ) {
                $id = self.register-target( $_ );
            }
            else {
                $prs.warnings.push("Attempt to register already existing id ｢$_｣ as new target in heading ｢$contents｣")
                if %config<error>
            }
        }
        else { $id = '' }
        # level is over-ridden if headlevel is set, eg =for head2 :headlevel(3)
        $level = %config<headlevel> if %config<headlevel>:exists;
        $level = 1 if $level < 1;
        # numeration is attached to contents first
        my $numeration = '';
        if $numerate {
            $numeration ~= PCell.new( :$!register, :id('heading_' ~ $target ) );
            $prs.head-numbering.push: ['heading_' ~ $target, $level ];
        }
        my $toc = %config<toc>:delete // True;
        # attach numeration to caption and contents separately, allowing template
        # developer to add numeration to caption if wanted by changing the template
        $prs.toc.push(
            { :$caption, :$target, :$level, :$numeration }
        ) if $toc;
        $prs.body ~= %!templates{ $template }(
            %( :$numeration, :$level, :$target, :$contents, :$toc, :$caption, :$id, %config )
        );
        $!scoped-data.in-head = '';
        $!scoped-data.end-scope if $parify;
    }
    #| Formula at level 1 is added to ToC unless overriden by toc/headlevel/caption
    #| Content is passed verbatim to template as formula
    #| An alt text is also generated
    method gen-formula($ast) {
        my %config = $.merged-config( $ast, 'formula' );
        my $formula = $.contents( $ast, False ); # do not treat strings paragraphs
        my $raw = $ast.paragraphs.Str.join; # also create a raw version for other renderers
        my $prs := $*prs;
        my $alt = %config<alt>:delete // 'Formula cannot be rendered';
        my $caption = %config<caption>:delete // 'Formula';
        my $target = $.name-id($alt);
        my $id = %config<id>:delete;
        my $numeration = ''; # TODO allow for TABLE and FORMULA numeration
        with $id {
            if self.is-target-unique( $_ ) {
                $id = self.register-target( $_ );
            }
            else {
                $prs.warnings.push("Attempt to register already existing id ｢$_｣ as new target in heading ｢$alt｣")
                if %config<error>
            }
        }
        # level is over-ridden if headlevel is set, eg =for head2 :headlevel(3)
        my $level = %config<headlevel> // 1;
        $level = 1 if $level < 1;
        my $toc = %config<toc>:delete // True;
        # attach numeration to caption and contents separately, allowing template
        # developer to add numeration to caption if wanted by changing the template
        $prs.toc.push(
            { :$caption, :$target, :$level, :$numeration }
        ) if $toc;
        $prs.body ~= %!templates<formula>(%(:$raw, :$formula, :$alt, :$target, :$caption, :$level, :$numeration, :$id, %config ) )
    }
    #| generates a single item and adds it to the item structure
    #| nothing is added to the .body string
    #| bullet strategy can be left to template, with bullet in %config
    method gen-item($ast, $parify) {
        my $level = $ast.level > 1 ?? $ast.level !! 1;
        my $contents = $.contents($ast, $parify);
        my %config = $.merged-config($ast, 'item' ~ $level );
        $*prs.items.push: %!templates<item>(
            %( :$level, :$contents, %config )
        )
    }
    #| generates a single numitem and adds it to the numitem structure
    #| nothing is added to the .body string
    method gen-numitem($ast, $parify) {
        my $level = $ast.level > 1 ?? $ast.level !! 1;
        my $contents = $.contents($ast, $parify);
        my %config = $.merged-config($ast, 'numitem' ~ $level );
        $!scoped-data.item-reset unless ($*prs.numitems.elems or %config<continued>);
        my $numeration = $!scoped-data.item-inc($level);
        $*prs.numitems.push: %!templates<numitem>(
            %( :$level, :$contents, :$numeration, %config )
        )
    }
    #| generates a single definition and adds it to the defn structure
    #| unlike item, a defn:
    #| - list has a flat hierarchy
    #| - can be created by a markup code
    #| - needs a target for links, and text for popup
    #| - is PCell-stored allowing for defn to be redefined
    #| like items nothing is added to the .body string until next non-defn
    method gen-defn($ast, :$numerate = False) {
        my $term;
        my $defn-expansion;
        my %config = $.merged-config($ast, $numerate ?? 'numdefn' !! 'defn');
        if $ast.paragraphs.elems == 2 {
            $term = $ast.paragraphs[0].Str.trim; # the term may not contain embedded code
            $defn-expansion = $ast.paragraphs[1];
        }
        else {
            my $string = $ast.Str;
            $*prs.body ~= $string;
            $*prs.warnings.push(
                "Invalid definition: ｢$string｣"
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.")
                if %config<error>;
            return
        }
        my $target = $.name-id("defn_$term");
        my $contents;
        # generate contents from second str/paragraph
        do {
            my ProcessedState $*prs .= new;
            $.handle( $defn-expansion );
            my $prs := $*prs;
            $contents = $prs.body;
            # keep most of state, initialise body
            $prs.body .= new;
            CALLERS::<$*prs> += $prs;
        }
        my $prs := $*prs;
        if $numerate {
            $!scoped-data.defn-reset unless ($prs.numdefns.elems or %config<continued>);
            my $numeration = $!scoped-data.defn-inc;
            $defn-expansion = %!templates<numdefn>(
                %( :$term, :$target, :$contents, :$numeration, %config )
            );
            $prs.numdefns.push: $defn-expansion
        }
        else {
            $defn-expansion = %!templates<defn>(
                %( :$term, :$target, :$contents, %config )
            );
            $prs.defns.push: $defn-expansion; # for the defn list to be render
        }
        $prs.warnings.push(
            "Definition ｢$term｣ has been redefined"
            ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.")
            if $prs.definitions{ $term }:exists and %config<error>;
        $prs.definitions{ $term } = $defn-expansion, $target;
        # define for previously referenced
        $!register.add-payload(:payload($defn-expansion), :id($term));
        $!register.add-payload(:payload($target), :id($term ~ '_target'))
    }
    #| A place block adds Place at level 1 to ToC unless toc/headlevel/caption set
    #| The contents of Place is a URI that is generated and then rendered with place template
    method gen-place($ast) {
        my %config = $.merged-config( $ast, 'place');
        my $uri = %config<uri>:delete;
        unless %config<caption>:exists {
            if $uri ~~ / 'semantic:' (.+) / {
                %config<caption> = ~$0
            }
            else { %config<caption> = 'Placement' }
        }
        my $caption = %config<caption>;
        my $level = %config<headlevel> // 1;
        $!scoped-data.last-title($caption);
        my $target = %config<target> = $.name-id($caption);
        with %config<id> {
            if self.is-target-unique( $_ ) {
                %config<id> = self.register-target( $_ )
            }
            else {
                $*prs.warnings.push("Attempt to register already existing id ｢$_｣ as new target in heading ｢$caption｣")
                if %config<error>
            }
        }
        my $toc = %config<toc> // True;
        $*prs.toc.push(
            { :$caption, :$target, :$level }
        ) if $toc;
        $.make-placement(:$uri, :%config, :template<place>);
    }
    method make-placement( :$uri, :%config, :$template ) {
        my Bool $keep-format = False;
        # defaults when no schema is explicit
        my $schema = 'file';
        my $uri-body = $uri;
        my $contents;
        #defaults to text type of contents, could be blob from https
        %config<content-type> = 'text';
        my $prs := $*prs;
        if $uri ~~ / ^ $<sch> = (\w+) ':' $<body> = (.+) $ / {
            $schema = $/<sch>.Str;
            $uri-body = $/<body>.Str
        }
        given $schema {
            when 'toc' {
                $contents = PCell.new( :$!register, :id("toc_$uri-body"), :spec($uri-body) );
                $keep-format = True;
            }
            when 'index' {
                $contents = PCell.new( :$!register, :id("index_$uri-body"), :spec($uri-body) );
                $keep-format = True;
            }
            when 'semantic' {
                $keep-format = True;
                $contents =  PCell.new( :$!register, :id( "semantic_$uri-body" ), :spec($uri-body) );
            }
            when 'http' | 'https' {
                my LibCurl::Easy $curl .= new(:URL($uri), :followlocation, :failonerror );
                try {
                    $curl.perform;
                    %config<content-type> = $curl.Content-Type;
                    if %config<content-type>.contains('text') {
                        $contents = $curl.perform.content;
                        %config<html> = so $contents ~~ / '<html' .+ '</html>'/;
                        $contents = ~$/ if %config<html>; # strip off any chars before & after the <html> container if it exists
                    }
                    else {
                        $contents = $curl.perform.buf;
                    }
                    CATCH {
                        default {
                            my $error = "Link ｢$uri｣ caused LibCurl Exception, response code ｢{ $curl.response-code }｣ with error ｢{ $curl.error }｣";
                            $contents = %config<fallback> // $error;
                            $prs.warnings.push($error) if %config<error>
                        }
                    }
                }
            }
            when 'file' {
                my URI $f-uri .= new($uri);
                if $f-uri.path.Str.IO ~~ :e & :f {
                    $contents = $f-uri.path.Str.IO.slurp;
                }
                else {
                    my $error = "No file found at ｢$f-uri｣";
                    $contents = %config<fallback> // $error;
                    $prs.warnings.push($error) if %config<error>
                }
            }
            when 'defn' {
                # get definition from Processed state, or make a PCell
                my %definitions = $prs.definitions;
                $contents = $uri-body;
                if %definitions{ $uri-body }:exists {
                    %config<defn-expansion> = %definitions{ $uri-body }[0];
                    %config<defn-target> = %definitions{ $uri-body }[1]
                }
                else {
                    %config<defn-expansion> = PCell.new( :$!register, :id( $uri-body ));
                    %config<defn-target> = PCell.new( :$!register, :id( $uri-body ~ '_target' ));
                }
            }
            default {
                    $contents = %config<fallback> // "See $uri";
                    $prs.warnings.push(
                        "The schema ｢$schema｣ is not implemented. Full link was ｢$uri｣"
                        ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.") if %config<error>
            }
        }
        # trap contents that have RakuDoc, could be from https, or file and attempt to process it.
        if %config<content-type>.contains('text') && $contents ~~ /^ '=begin rakudoc' / {
             do {
                my ProcessedState $*prs .= new;
                $contents.AST.rakudoc.map( { $.handle( $_ ) } );
                my $prs := $*prs;
                $contents = $prs.body.trim-trailing;
                $prs.body .= new;
                CALLERS::<$*prs> += $prs;
             }
        }
        $prs.body ~= %!templates{ $template }(
            %( :$contents, :$keep-format, :$schema, :$uri-body, :$uri, %config )
        )
    }
    #| The rakudoc block should encompass the output
    #| Config data associated with block is provided to overall process state
    #| If a rakudoc file is embedded via place, then another rakudoc block
    #| will be called. Only allow embedding to three levels to avoid circularity.
    method gen-rakudoc($ast, $parify) {
        my %config = $ast.resolved-config;
        $!current.source-data<rakudoc-config> = %config;
        my $contents = self.contents($ast, $parify);
        # render any tailing lists
        $contents ~= $.complete-item-list ~ $.complete-defn-list
        ~ $.complete-numitem-list ~ $.complete-numdefn-list;
        $*prs.body ~= %!templates<rakudoc>( %( :$contents, %config ) );
    }
    #| A section is invisible to ToC, but is used by scoping
    #| Some output formats may want to handle section, so
    #| embedded RakuDoc are rendered and contents rendered by section template
    method gen-section($ast, $parify) {
        my %config = $.merged-config($ast, 'section');
        my $contents = $.contents($ast, $parify);
        # render any tailing lists
        $contents ~= $.complete-item-list ~ $.complete-defn-list
        ~ $.complete-numitem-list ~ $.complete-numdefn-list;
        my $id = '';
        with %config<id> {
            if self.is-target-unique( $_ ) {
                self.register-target( $_ );
                $id = $_
            }
            else {
                $*prs.warnings.push(
                    "Attempt to register already existing id ｢$_｣ as new target in ｢section｣"
                    ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.") if %config<error>
            }
        }
        $*prs.body ~= %!templates<section>( %( :$contents, :$id, %config ) )
    }
    #| Table is a captionless paragraph and not added to ToC
    #| unless overriden by toc/headlevel/caption
    #| contents is processed and rendered using table template
    multi method gen-table($ast) {
        my %config = $.merged-config($ast, 'table');
        my $caption = %config<caption>:delete // '';
        my $prs := $*prs;
        my $target = $.name-id($caption) if $caption;
        $!scoped-data.last-title( $target );
        my $id = %config<id>:delete;
        with $id {
            if self.is-target-unique( $_ ) {
                $id = self.register-target( $_ );
            }
            else {
                $prs.warnings.push("Attempt to register already existing id ｢$_｣ as new target in heading ｢$caption｣") if %config<error>
            }
        }
        my $level = %config<headlevel> // 1 ;
        $level = 1 if $level < 1;
        # numeration is attached to contents first
        my $numeration = '';
        if %config<numerate> {
            $numeration ~= PCell.new( :$!register, :id('table_' ~ $target ) );
            $prs.head-numbering.push: ['table_' ~ $target, $level ];
        }
        my $toc = %config<toc>:delete // False;
        # attach numeration to caption and contents separately, allowing template
        # developer to add numeration to caption if wanted by changing the template
        $prs.toc.push(
            { :$caption, :$target, :$level, :$numeration }
        ) if $toc;
        my Bool $procedural = $ast.visual-table.not;
        my @grid;
        my @headers;
        my @rows;
        my $header-rows;
        if $procedural {
            # grid traversing algorithm due to Damian Conway
            # Initially empty grid...
            # How to locate the next empty cell...
            my \find_next_empty = {
                ACROSS => sub (:%at is copy) {
                    # Search leftwards for first empty cell...
                    repeat { %at<col>++ } until !defined @grid[%at<row>][%at<col>];
                    return %at;
                },
                DOWN => sub (:%at is copy) {
                    # Search downwards for first empty cell...
                    repeat { %at<row>++ } until !defined @grid[%at<row>][%at<col>];
                    return %at;
                },
                ROW => sub (:%at is copy) {
                    # Search downwards for first row with an empty cell to the right...
                    # (Note: starts by searching current row before moving down)
                    for %at<row> ..* -> $row {
                        for 0 ..^ %at<col> -> $col {
                            return { :$row, :$col } if !defined @grid[$row][$col];
                        }
                    }
                },
                COLUMN => sub (:%at is copy) {
                    # Search rightwards for first column with an empty cell above...
                    # (Note: starts by searching current column before moving left)
                    for %at<col> ..* -> $col {
                        for 0 ..^ %at<row> -> $row {
                            return { :$row, :$col } if !defined @grid[$row][$col];
                        }
                    }
                },
            }
            # parse row and column directive contents, should be in node.config
            my %POS = :row(0), :col(0);
            my $DIR = 'ACROSS';
            # Track previous action at each step...
            my $prev-was-cell = False; # because we are in grid
            my @cell-context = ( %(), ); # cell context can be set at grid, row, column, or cell level
            # span type only set at cell level
            for <label header align> -> $k {
                @cell-context[*-1]{ $k } = $_ with %config{ $k };
            }
            for $ast.paragraphs -> $grid-instruction {
                unless $grid-instruction.^can('type') {
                    $prs.body ~= $ast.Str;
                    $prs.warnings.push("｢{$grid-instruction.Str}｣ is illegal as an immediate child of a =table")
                    if %config<error>;
                    return
                }
                next if $grid-instruction.type eq 'comment';
                given $grid-instruction.type {
                    when 'cell' {
                        my %cell-config = $grid-instruction.resolved-config;
                        my %payload = %( |@cell-context[*-1], %cell-config );
                        # to be expanded to get-contents
                        %payload<data> = $.contents( $grid-instruction, False );
                        my $span;
                        $span = $_ with %cell-config<span>;
                        with %cell-config<column-span> {
                            $span[0] = $_;
                            $span[1] //= 1
                        }
                        with %cell-config<row-span> {
                            $span[0] //= 1;
                            $span[1] = $_
                        }
                        %payload<span> = $span if $span;
                        # Fill current cell with payload...
                        @grid[%POS<row>][%POS<col>] = %payload;
                        # Reserve the full span of cells specified...
                        if $span {
                            for 0 ..^ $span[0] -> $extra-col {
                                for 0 ..^ $span[1] -> $extra-row {
                                    @grid[%POS<row> + $extra-row][%POS<col> + $extra-col]
                                            //= %( :no-cell, );
                                }
                            }
                        }
                        # Find next empty cell in the fill direction...
                        %POS = find_next_empty{$DIR}(at => %POS);
                    }
                    when 'row' {
                        @cell-context.pop if @cell-context.elems > 1;  # this is only false if the first row/column after =table
                        # Check the contents for metadata
                        @cell-context.push: %( |@cell-context[0], |$grid-instruction.resolved-config );
                        # Start filling across the new row...
                        $DIR = 'ACROSS';
                        # Find the new fill position...
                        if $prev-was-cell {
                            %POS = find_next_empty<ROW>(at => %POS);
                        }
                    }
                    when 'column' {
                        @cell-context.pop if @cell-context.elems > 1;  # this is only false if the first row/column after =table
                        # Check the contents for metadata
                        @cell-context.push: %( |@cell-context[0], |$grid-instruction.resolved-config );

                        # Start filling down the new column...
                        $DIR = 'DOWN';
                        # Find the new fill position...
                        if $prev-was-cell {
                            %POS = find_next_empty<COLUMN>(at => %POS);
                        }
                    }
                    default { # only =cell =row =column allowed after a =grid
                        $prs.body ~= $ast.Str;
                        $prs.warnings.push("｢{$grid-instruction.DEPARSE}｣ is illegal as an immediate child of a =table")
                        if %config<error>;
                        return
                    }
                }
                # Update previous action...
                $prev-was-cell = $grid-instruction.type eq 'cell';
            }
            $header-rows = @grid.grep( *.[0]<header> ).elems;
        }
        else {
            for $ast.paragraphs -> $row {
                next if $row ~~ Str; # rows as strings are row/header separators
                unless $row ~~ RakuAST::Doc::LegacyRow {
                    $prs.body ~= $ast.DEPARSE;
                    $prs.warnings.push("｢{$row.Str}｣ is illegal as an immediate child of a =table")
                    if %config<error>;
                    return
                }
                my @this-row;
                for $row.cells {
                    my ProcessedState $*prs .= new;
                    $.handle( $_ );
                    my $prs := $*prs;
                    @this-row.push: $prs.body;
                    $prs.body .= new;
                    CALLERS::<$*prs> += $prs;
                }
                @rows.push: @this-row
            }
            with %config<header-row> {
                @headers = @rows.shift for ^($_+1);
            }
        }
        $prs.body ~= %!templates<table>.( %(
            :$procedural, :$caption, :$id, :$target, :$level,
            :$header-rows, :@headers, :@rows, :@grid,
            %config ) );
    }
    #| A lower case block generates a warning
    #| DEPARSED Str is rendered with 'unknown' template
    #| Nothing added to ToC
    method gen-unknown-builtin($ast) {
        my %config = $.merged-config( $ast, '*' );
        my $contents = $ast.DEPARSE;
        my $prs := $*prs;
        if $ast.type ~~ any(<
                cell code input output comment head numhead defn item numitem nested para
                rakudoc section pod table formula
            >) { # a known built-in, but to get here the block is unimplemented
            $prs.warnings.push(
                '｢' ~ $ast.type ~ '｣'
                ~ 'is a valid, but unimplemented builtin block'
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.")
                if %config<error>
        }
        else { # not known so create another warning
            $prs.warnings.push(
                '｢' ~ $ast.type ~ '｣' ~ ' is not a valid builtin block, is it a misspelt Custom block?'
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
                ) if %config<error>
        }
        my $target = $.name-id($ast.type);
        $prs.body ~= %!templates<unknown>( %( :$contents, :block-name($ast.type), :$target ) )
    }
    #| Semantic blocks defined by spelling
    #| embedded content is rendered and passed to template as contents
    #| rendered contents is added to the semantic structure
    #| If :hidden is True, then the string is not added to .body
    #| Unless :hidden, Block name is added to ToC at level 1, unless overriden by toc/caption/headlevel
    #| TITLE & SUBTITLE by default :hidden is True and added to $*prs separately
    #| All other SEMANTIC blocks are :!hidden by default
    method gen-semantics($ast, $parify) {
        my $block-name = $ast.type;
        my %config = $.merged-config($ast, $block-name);
        $!scoped-data.last-title( $block-name );
        # treat all semantic blocks as a heading level 1 unless otherwise specified
        my $caption = %config<caption> // $block-name;
        my $level = %config<headlevel> // 1;
        my $hidden;
        my $contents = $.contents($ast, $parify).trim;
        $contents ~= $.complete-item-list ~ $.complete-defn-list
            ~ $.complete-numitem-list ~ $.complete-numdefn-list;
        my $prs := $*prs;
        my $rv;
        given $ast.type {
            when 'TITLE' {
                $hidden = True; # hide by default
                $hidden = $_ with %config<hidden>;
                $!current.title = $contents.Str;
                my $target = $!current.title-target = $.name-id( $contents.Str);
                # allows for TITLE to have its own template
                if %!templates<TITLE>:exists {
                    $rv = %!templates<TITLE>( %( :$level, :$contents, :$caption, :$target, %config ) )
                }
                else {
                    $rv = %!templates<semantic>( %( :$level, :$contents, :$caption, :$target, :$hidden, %config ) )
                }
            }
            when 'SUBTITLE' {
                $hidden = True; # hide by default
                $hidden = $_ with %config<hidden>;
                $!current.subtitle = $contents.Str;
                my $target = $.name-id($contents.Str);
                if %!templates<SUBTITLE>:exists {
                    $rv = %!templates<SUBTITLE>( %( :$level, :$contents, :$caption, :$target, :$hidden, %config ) )
                }
                else {
                    $rv = %!templates<semantic>( %( :$level, :$contents, :$caption, :$target, :$hidden, %config ) )
                }
            }
            default {
                $hidden = %config<hidden>.so // False;
                # other SEMANTIC by default rendered in place
                # allows for a plugin to add a SEMANTIC blockname to templates
                my $template = %!templates{ $block-name }:exists ?? $block-name !! 'semantic';
                my $target = $.name-id($block-name);
                my $id = '';
                with %config<id> {
                    if self.is-target-unique( $_ ) {
                        self.register-target( $_ );
                        $id = $_
                    }
                    else {
                        $prs.warnings.push(
                            "Attempt to register already existing id ｢$_｣ as new target in ｢$block-name｣"
                            ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
                            ) if %config<error>
                    }
                }
                $rv = %!templates{$template}(
                    %( :$level, :$caption, :$hidden, :$target, :$contents, :$id, %config )
                );
                $prs.toc.push(  %( :$caption, :$target, :$level ) ) unless $hidden;
            }
        }
        $prs.semantics{ $block-name } = [] unless $prs.semantics{ $block-name }:exists;
        $prs.semantics{ $block-name }.push: $rv;
        $prs.body ~= $rv unless $hidden;
    }
    method gen-custom($ast, $parify) {
        # Custom blocks are defined by their spelling
        # - the block name is added to ToC at level 1 unless changed by toc/caption/headlevel
        # If a template exists with the block name
        # - provides content verbatim to template as raw
        # - provides content rendered to template as contents
        # If NOT,
        # - the block content is rendered as verbatim text
        # - the content is rendered with 'unknown' template
        # - a warning is issued
        my $block-name = $ast.type;
        my %config = $.merged-config( $ast, $block-name);
        my $prs := $*prs;
        my $caption = %config<caption>:delete // $block-name;
        my $level = %config<headlevel>:delete // 1;
        $level = 1 unless $level >= 1;
        my $numeration = '';
        my $id = '';
        with %config<id> {
            if self.is-target-unique( $_ ) {
                self.register-target( $_ );
                $id = $_
            }
            else {
                $prs.warnings.push(
                    "Attempt to register already existing id ｢$_｣ as new target in ｢$block-name｣"
                    ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
                ) if %config<error>
            }
        }
        my $target = %config<id>:delete // $.name-id($caption);
        my $toc = %config<toc>:delete // True;
        # attach numeration to caption and contents separately, allowing template
        # developer to add numeration to caption if wanted by changing the template
        $prs.toc.push(
            { :$caption, :$target, :$level, :$numeration }
        ) if $toc;
        if %!templates{ $block-name }:exists {
            my $contents = $.contents( $ast, $parify );
            my $raw = $ast.paragraphs.Str.join;
            $prs.body ~= %!templates{ $block-name }( %( :$contents, :$raw, :$level, :$target, :$caption, :$id, :$toc, %config ) )
        }
        else {
            # by spec, the name of an unrecognised Custom is treated like =head1
            # the contents are treated like =code
            my $contents = $ast.DEPARSE;
            $contents = %config<alt> if %config<alt>:exists;
            $prs.warnings.push(
            "No template exists for custom block ｢$block-name｣. It has been rendered as unknown"
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
            ) if %config<error>;
            $prs.body ~= %!templates<unknown>( %( :$contents, :$block-name, :$target, :$caption) )
        }
    }
    # directive type methods
    method manage-config($ast) {
        my %options = $ast.resolved-config;
        my $name = $ast.paragraphs[0].Str;
        $name = $name ~ '1' if $name eq <item head numitem numhead>.any;
        $!scoped-data.config( { $name => %options } );
    }
    method manage-alias($ast) {
        my %config = $ast.resolved-config;
        my $prs := $*prs;
        if $ast.paragraphs.elems >= 2 {
            my $term = $ast.paragraphs[0].Str; # it should be a string without embedded codes
            my ProcessedState $*prs .= new;
            $ast.paragraphs[1 .. *-1 ].map({ $.handle( $_ ) });
            my $prs := $*prs;
            my $expansion = $prs.body.trim-trailing;
            $expansion ~= $.complete-item-list;
            $expansion ~= $.complete-defn-list;
            $expansion ~= $.complete-numitem-list;
            $expansion ~= $.complete-numdefn-list;
            $!scoped-data.aliases{ $term } = $expansion;
            $prs.body .= new;
            CALLERS::<$*prs> += $prs;
        }
        else {
            $prs.warnings.push("Invalid alias ｢{ $ast.Str }｣") if %config<error>
        }
    }
    ## completion methods

    #| finalise the rendering of footnotes
    #| the numbering only happens when all footnotes are collected
    #| completes the PCell in the body
    method complete-footnotes {
        for $!current.footnotes.kv -> $n, %data {
            %data<fnNumber> = $n + 1;
            $!register.add-payload( :payload($n + 1), :id( 'fn_num_' ~ %data<retTarget> ) );
        }
    }
    #| takes the index structure and returns an ordered list of items to be rendered
    sub serialise-index( %h, $n, $max ) {
        return unless (%h.elems and $n <= $max);
        my @rv;
        for %h.sort( *.key )>>.kv -> ( $label, %indexed) {
            my @inner = $n, $label, %indexed<refs>;
            @rv.push: @inner;
            if serialise-index( %indexed<sub-index>, $n + 1, $max ) -> $_ { @rv.append($_.list) }
        }
        @rv
    }
    sub stringify-index( %h ) {
        for %h.pairs {
            for .value<refs>.list {
                .<place> .= Str
            }
            stringify-index( .value<sub-index>.hash ) if .value<sub-index>.elems.so
        }
    }
    method complete-index( :$spec, :$caption --> PStr ) {
        my $max; # the maximum number of index levels. Shouldn't be more than around 5
        if $spec eq '*' { $max = 100 }
        else { $max = $spec.EVAL.list.max }
        my @index-list;
        if serialise-index( $!current.index , 1, $max ) -> $_ {
            @index-list = .map({
                %!templates<index-item>( %( :level( .[0] ), :entry( .[1] ), :refs( .[2] ) ) )
            })
        }
        PStr.new( @index-list.elems ?? %!templates<index>( %(:@index-list, :$caption ))
                                    !! '')
    }
    #| renders the complete toc
    method complete-toc( :$spec, :$caption --> PStr ) {
        my Set $levels;
        if $spec eq '*' { $levels .=new: (^10).list }
        else { $levels .= new: $spec.EVAL.list }
        my @toc-list = gather for $!current.toc -> $toc-entry {
            take %!templates<toc-item>( %( :$toc-entry , ) ) if $levels{ +$toc-entry<level> }
        }
        PStr.new( @toc-list.elems ?? %!templates<toc>( %(:@toc-list, :toc( $!current.toc), :$caption ) )
                                  !! '' )
    }
    #| finalises all the heading numerations
    method complete-heading-numerations() {
        return unless $*prs.head-numbering.elems;
        my Numeration $heads .= new;
        for $*prs.head-numbering -> ( $id, $level  ) {
            my $payload;
            $payload = $heads.inc( $level ).Str if $id.starts-with('heading');
            $!register.add-payload( :$payload, :$id )
        }
    }
    #| finalises rendering of the item list in $*prs
    method complete-item-list() {
        return '' unless $*prs.items.elems; # do nothing if no accumulated items
        my $rv = %!templates<item-list>(
            %( :item-list($*prs.items), )
        );
        $*prs.items = ();
        $rv
    }
    #| finalises rendering of a defn list in $*prs
    method complete-defn-list() {
        return '' unless $*prs.defns.elems;
        my $rv = %!templates<defn-list>(
            %( :defn-list($*prs.defns), )
        );
        $*prs.defns = ();
        $rv
    }
    #| finalises rendering of the item list in $*prs
    method complete-numitem-list() {
        return '' unless $*prs.numitems.elems;
        my $rv = %!templates<numitem-list>(
            %( :numitem-list($*prs.numitems), )
        );
        $*prs.numitems = ();
        $rv
    }
    #| finalises rendering of a defn list in $*prs
    method complete-numdefn-list() {
        return '' unless $*prs.numdefns.elems;
        my $rv = %!templates<numdefn-list>(
            %( :numdefn-list($*prs.numdefns), )
        );
        $*prs.numdefns = ();
        $rv
    }
    # helper methods
    method is-target-unique($targ --> Bool) {
        $!current.targets{$targ}.not
    }
    method register-target($targ) {
        $!current.targets{$targ}++;
        $targ
    }
    #| The 'contents' method is called when $ast.paragraphs is a sequence.
    #| The $*prs for a set of paragraphs is new to collect all the
    #| associated data. The body of the contents must then be
    #| incorporated using the template of the block calling content
    #| when parify, strings are considered paragraphs
    method contents($ast, Bool $parify ) {
        my ProcessedState $*prs .= new;
        if $parify {
            $.handle( $_ ~~ Str ?? RakuAST::Doc::Paragraph.new($_ ) !! $_ )
                for $ast.paragraphs
        }
        else {
            $.handle( $_ ) for $ast.paragraphs
        }
        my $prs := $*prs;
        my $text = $prs.body.trim-trailing;
        $prs.body .= new;
        CALLERS::<$*prs> += $prs;
        $text
    }
    #| similar to contents but expects atoms structure
    method markup-contents($ast, :$meta = False) {
        my ProcessedState $*prs .= new;
        if $meta { for $ast.meta { $.handle($_) } }
        else { for $ast.atoms { $.handle($_) } }
        my $prs := $*prs;
        my $text = $prs.body;
        $prs.body .= new;
        CALLERS::<$*prs> += $prs;
        $text
    }
    #| get config merged from the ast and scoped data
    #| handle generic metadata options such as delta
    method merged-config( $ast, $block-name --> Hash ) {
        my %config;
        if $ast.defined && $ast.config {
            %config = .resolved-config with $ast;
            for ($ast.config.keys (-) %config.keys).keys -> $k { %config{$k} = $ast.config{$k}.Str }
        }
        my %scoped = $!scoped-data.config;
        %scoped{ $block-name }.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        %scoped{ '*' }.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        %config<error> = True unless %config<error>:exists;
        if %config<delta>:exists {
            my $contents = %config<delta>:delete;
            if $contents.join(' ') ~~ / (<-[;]>+) ';'? ( .* ) $ / {
                %config<delta> = %!templates<delta>(%( :note( ~$1.trim), :versions(~$0.trim) ));
            }
            else {
                $*prs.warnings.push("The delta option is ignored because it must have the form / 'v' \\S+ \\s* (['|'] .+)? \$ / ｢{ ~$ast.DEPARSE }｣")
                if %config<error>
            }
        }
        else { %config<delta> = '' }
        %config
    }

    ## A set of methods to generate anchors / targets
    ## Output formats, eg. MarkDown and HTML, have different
    ## criteria. HTML rendering of Raku documentation has its
    ## own legacy algorithms
    ## So, different methods are used for
    ## - names (blocks) to be included in ToC, which needs to target the block
    ## - footnotes
    ## - indexed text, where Raku HTML has anchors that depend on context and meta
    ## - external links to other documents, which do not have to be unique

    #| Escape characters in a string, needs to be over-ridden
    multi method escape( Str:D $s ) { $s }
    #| Stringify if not string
    multi method escape( $s ) { self.escape( $s.Str ) }
    #| mangle an id to make sure it will be a valid id in the output
    method mangle( $s ) { self.escape( $s ).subst(/ \s /, '_', :g) }

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
    method index-id(:$contents) {
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
        self.mangle($ast.Str.trim);
    }

    method para-target( $contents ) {
        my $n = $!current.source-data<paragraph-id-length>;
        sha1-hex($contents.Str).substr(* - $n)
    }

    # text helpers adapted from Liz's RakuDoc::To::Text
    # colorless ANSI constants
    my constant RESET = "\e[0m";
    my constant BOLD-ON = "\e[1m";
    my constant BOLD-OFF = "\e[22m";
    my constant ITALIC-ON = "\e[3m";
    my constant ITALIC-OFF = "\e[23m";
    my constant UNDERLINE-ON = "\e[4m";
    my constant UNDERLINE-OFF = "\e[24m";
    my constant HEADING-ON = "\e[21m";
    my constant HEADING-OFF = "\e[24m";
    my constant TITLE-ON = "\e[4:3m";
    my constant TITLE-OFF = "\e[4:0m";
    my constant REPLACE-ON = "\e[5m";
    my constant REPLACE-OFF = "\e[25m";
    my constant INDEXED-ON = "\e[7m";
    my constant INDEXED-OFF = "\e[27m";
    my constant CODE-ON = "\e[7m";
    my constant CODE-OFF = "\e[27m";
    my constant STRIKE-ON = "\e[9m";
    my constant STRIKE-OFF = "\e[29m";
    my constant SUPERSCR-ON = "\e[48;5;78m\e[73m";
    my constant SUBSCR-ON = "\e[48;5;80m\e[74m";
    my constant SUBSCR-OFF = "\e[75m\e[39;49m";
    my constant SUPERSCR-OFF = "\e[75m\e[39;49m";
    my constant INDEX-ENTRY-ON = "\e[48;5;2m";
    my constant INDEX-ENTRY-OFF = "\e[39;49m";
    my constant KEYBOARD-ON = "\e[48;5;5m";
    my constant KEYBOARD-OFF = "\e[39;49m";
    my constant TERMINAL-ON = "\e[48;5;6m";
    my constant TERMINAL-OFF = "\e[39;49m";
    my constant FOOTNOTE-ON = "\e[48;5;214m\e[38;5;0m";
    my constant FOOTNOTE-OFF = "\e[39;49m";
    my constant LINK-TEXT-ON = "\e[48;5;227m\e[38;5;0m";
    my constant LINK-TEXT-OFF = "\e[39;49m";
    my constant LINK-ON = "\e[38;5;227m\e[48;5;0m";
    my constant LINK-OFF = "\e[39;49m";
    my constant DEVEL-TEXT-ON = "\e[48;5;216m\e[38;5;0m";
    my constant DEVEL-TEXT-OFF = "\e[39;49m";
    my constant DEVEL-VERSION-ON = "\e[38;5;196m\e[48;5;17m";
    my constant DEVEL-VERSION-OFF = "\e[39;49m";
    my constant DEVEL-NOTE-ON = "\e[38;5;161m\e[48;5;17m";
    my constant DEVEL-NOTE-OFF = "\e[39;49m";
    my constant DEFN-TERM-ON = "\e[1m";
    my constant DEFN-TERM-OFF = "\e[22m";
    my constant DEFN-TEXT-ON = "  \e[48;5;243m";
    my constant DEFN-TEXT-OFF = "\e[39;49m";
    my constant BAD-MARK-ON = "\e[38;5;117m\e[48;5;0m";
    my constant BAD-MARK-OFF = "\e[39;49m";
    my constant @bullets = <<\x2022 \x25b9 \x2023 \x2043 \x2219>> ;

    #| returns a set of text templates
    multi method default-text-templates {
        %(
            #| special key to name template set
            _name => -> %, $ { 'default text templates' },
            #| renders =code blocks
            code => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                PStr.new: $del ~ "\n  --- code --- \n"
                ~ %prm<contents>
                ~ "\n  --- ----- ---\n"
            },
            #| renders =input block
            input => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                PStr.new: $del ~ "\n  --- input --- \n"
                ~ %prm<contents>
                ~ "\n  --- ------ ---\n"
            },
            #| renders =output block
            output => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                PStr.new: $del ~ "\n  --- output --- \n"
                ~ %prm<contents>
                ~ "\n  --- ------ ---\n"
             },
            #| renders =comment block
            comment => -> %prm, $tmpl { '' },
            #| renders =formula block
            formula => -> %prm, $tmpl {
                my $indent = %prm<level> > 5 ?? 4 !! (%prm<level> - 1) * 2;
                my $del = %prm<delta> // '';
                "\n" ~ ' ' x $indent  ~ HEADING-ON ~ %prm<caption> ~  HEADING-OFF ~ "\n\n" ~
                $del ~ %prm<formula> ~ "\n\n"
            },
            #| renders =head block
            head => -> %prm, $tmpl {
                my $indent = %prm<level> > 5 ?? 4 !! (%prm<level> - 1) * 2;
                my $del = %prm<delta> // '';
                "\n" ~ ' ' x $indent  ~ HEADING-ON ~ BOLD-ON ~ %prm<contents> ~ BOLD-OFF ~ HEADING-OFF ~
                "\n" ~ $del
            },
            #| renders =numhead block
            numhead => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                my $indent = %prm<level> > 5 ?? 4 !! (%prm<level> - 1) * 2;
                my $title = %prm<numeration> ~ ' ' ~ %prm<contents>;
                "\n" ~ ' ' x $indent ~ HEADING-ON ~ BOLD-ON ~ $title ~ BOLD-OFF ~  HEADING-OFF ~
                "\n" ~ $del
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
            },
            #| renders =defn block
            defn => -> %prm, $tmpl {
                DEFN-TERM-ON ~ %prm<term> ~ DEFN-TERM-OFF ~ "\n" ~
                DEFN-TEXT-ON ~ %prm<contents> ~ DEFN-TEXT-OFF ~ "\n"
            },
            #| renders =numdefn block
            #| special template to render a defn list data structure
            defn-list => -> %prm, $tmpl { [~] %prm<defn-list> },
            #| special template to render a numbered defn list data structure
            numdefn => -> %prm, $tmpl {
                DEFN-TERM-ON ~ %prm<numeration> ~ ' ' ~ %prm<term> ~ DEFN-TERM-OFF ~ "\n" ~
                DEFN-TEXT-ON ~ %prm<contents> ~ DEFN-TEXT-OFF ~ "\n"
            },
            #| special template to render a numbered item list data structure
            numdefn-list => -> %prm, $tmpl { [~] %prm<numdefn-list> },
            #| renders =item block
            item => -> %prm, $tmpl {
                my $num = %prm<level> - 1;
                my $indent = ' ' x %prm<level>;
                $num = @bullets.elems - 1 if $num >= @bullets.elems;
                my $bullet = %prm<bullet> // @bullets[ $num ];
                $indent ~ $bullet ~ ' ' ~ %prm<contents> ~ "\n"
            },
            #| special template to render an item list data structure
            item-list => -> %prm, $tmpl {
                [~] %prm<item-list>
            },
            #| renders =numitem block
            numitem => -> %prm, $tmpl {
                %prm<numeration> ~ ' ' ~ %prm<contents> ~ "\n"
            },
            #| special template to render a numbered item list data structure
            numitem-list => -> %prm, $tmpl {
                [~] %prm<numitem-list>
            },
            #| renders =nested block
            nested => -> %prm, $tmpl {
                PStr.new: "\t" ~ %prm<contents> ~ "\n\n"
            },
            #| renders =para block
            para => -> %prm, $tmpl {
                PStr.new: %prm<contents> ~ "\n\n"
            },
            #| renders =place block
            place => -> %prm, $tmpl {
                my $level = %prm<headlevel> // 1;
                my $rv = $tmpl('head', %(:$level, :contents(%prm<caption>), :delta(%prm<delta>)));
                if %prm<content-type>.contains('text') {
                    $rv ~= %prm<contents>
                }
                else {
                    $rv ~= "Link returned {%prm<content-type>}, which cannot be rendered"
                }
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
                my $indent = %prm<level> > 5 ?? 4 !! (%prm<level> - 1) * 2;
                my $del = %prm<delta> // '';
                my $head = "\n" ~ ' ' x $indent  ~ HEADING-ON ~ BOLD-ON ~ %prm<caption> ~ BOLD-OFF ~ HEADING-OFF ~ "\n";
                ( $head unless %prm<hidden> ) ~
                $del ~
                %prm<contents> ~ "\n"
            },
            #| renders =pod block
            pod => -> %prm, $tmpl { %prm<contents> },
            #| renders =table block
            table => -> %prm, $tmpl {
                use Text::MiscUtils::Layout;
                my $del = %prm<delta> // '';
                my $caption = HEADING-ON ~ %prm<caption> ~ HEADING-OFF;
                my $cap-width = duospace-width($caption);
                if %prm<procedural> {
                    # calculate column widths naively, will include possible markup, and
                    # will fail if embedded tables
                    # TODO comply with justification, now right-justify col-head, top-justify row labels.
                    my @col-wids;
                    my $wid;
                    for %prm<grid>.list -> @row {
                        for @row.kv -> $n, %cell {
                            next if %cell<no-cell>;
                            $wid = duospace-width(%cell<data>.Str) + 2;
                            @col-wids[$n] = $wid if $wid > (@col-wids[$n] // 0)
                        }
                    }
                    my $table-wid = (+@col-wids * 3) + 4 + [+] @col-wids;
                    my @rendered-grid;
                    my $col-count;
                    for %prm<grid>.kv -> $r, @row {
                        $col-count = 0;
                        for @row.kv -> $n, %cell {
                            next if %cell<no-cell>;
                            my $data = %cell<data>.Str.trim;
                            my $chars = duospace-width($data);
                            my $col-wid = @col-wids[$n];
                            if %cell<span>:exists {
                                #for the col-span
                                if %cell<span>[0] > 1 {
                                    for ^( %cell<span>[0] - 1) {
                                        $col-wid += @col-wids[ $n + $_ + 1] + 2
                                    }
                                }
                                #for the row-span
                                if %cell<span>[1] > 1 {
                                    for ^ (%cell<span>[1] - 1 ) {
                                        @rendered-grid[$r + $_ + 1][$n] ~= ' ' x $col-wid ~ ' |'
                                    }
                                }
                            }
                            my $pref = ( $col-wid - $chars ) div 2;
                            my $post = $col-wid - $pref - $chars;
                            @rendered-grid[ $r ][ $n ] ~=
                                ' ' x $pref ~
                                (%cell<header> || %cell<label> ?? BOLD-ON !! '') ~
                                $data ~
                                (%cell<header> || %cell<label> ?? BOLD-OFF !! '')
                                ~ ' ' x $post ~ ' |';
                        }
                    }
                    my $cap-shift = ( $table-wid - $cap-width ) div 2;
                    my $row-shift = $cap-shift <= 0 ?? - $cap-shift !! 0;
                    $cap-shift = 0 if $cap-shift <= 0;
                    PStr.new: $del ~
                        "\n" ~ ' ' x $cap-shift ~ $caption ~"\n" ~
                        @rendered-grid.map({
                        ' ' x $row-shift ~ '| ' ~ $_.grep( *.isa(Str) ).join('') ~ "\n"
                        }).join('') ~ "\n\n"
                   ;
                }
                else {
                    my $headers = '';
                    my $cap-shift = 0;
                    if %prm<headers>:exists && %prm<headers>[0] {
                        my @headers := %prm<headers>[0];
                        $cap-shift = (([+] @headers>>.Str>>.chars) + (3 * +@headers) + 4 - $cap-width ) div 2;
                        $headers = '| ' ~ BOLD-ON ~ %prm<headers>[0].join( BOLD-OFF ~ ' | ' ~ BOLD-ON ) ~ BOLD-OFF ~ " |\n"
                    }
                    my $row-shift = $cap-shift <= 0 ?? - $cap-shift !! 0;
                    $headers = ' ' x $row-shift ~ $headers if $headers;
                    $cap-shift = 0 if $cap-shift <= 0;
                    PStr.new: $del ~
                        ' ' x $cap-shift ~
                        $caption ~ "\n" ~
                        $headers ~
                        %prm<rows>.map({
                            ' ' x $row-shift ~
                            '| ' ~ $_.join(' | ') ~ " |\n"
                        }).join('') ~ "\n\n"
                }
            },
            #| renders any unknown block minimally
            unknown => -> %prm, $tmpl {
                PStr.new: HEADING-ON ~ %prm<block-name> ~
                ' UNKNOWN' ~ HEADING-OFF ~ "\n" ~
                %prm<contents> ~ "\n\n"
            },
            #| special template to encapsulate all the output to save to a file
            final => -> %prm, $tmpl {
                ( %prm<rendered-toc> ??
                    ( %prm<rendered-toc> ~ "\n" ~ '=' x (%*ENV<WIDTH> // 80) ~ "\n")
                    !! ''
                ) ~
                "\n" ~ TITLE-ON ~ %prm<title> ~ TITLE-OFF ~ "\n\n" ~
                (%prm<subtitle> ?? ( %prm<subtitle> ~ "\n\n" ) !! '') ~
                %prm<body>.Str ~ "\n" ~
                %prm<footnotes>.Str ~ "\n" ~
                ( %prm<rendered-index>
                    ?? ( "\n\n" ~ '=' x (%*ENV<WIDTH> // 80) ~ "\n" ~ %prm<rendered-index> ~ "\n" )
                    !! ''
                ) ~
                "\x203b" x ( %*ENV<WIDTH> // 80 ) ~
                "\nRendered from " ~ %prm<source-data><path> ~ '/' ~ %prm<source-data><name> ~
                (sprintf( " at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<modified>.DateTime) ~
                "\nSource last modified " ~ (sprintf( "at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<source-data><modified>.DateTime) ~
                "\n\n" ~
                (( "\x203b" x ( %*ENV<WIDTH> // 80 ) ~ "\n" ~ %prm<warnings> ) if %prm<warnings>)
            },
            #| renders a single item in the toc
            toc-item => -> %prm, $tmpl {
                my $pref = ' ' x ( %prm<toc-entry><level> > 4 ?? 4 !! (%prm<toc-entry><level> - 1) * 2 )
                    ~ (%prm<toc-entry><level> > 1 ?? '- ' !! '');
                PStr.new: $pref ~ %prm<toc-entry><caption> ~ "\n"
            },
            #| special template to render the toc list
            toc => -> %prm, $tmpl {
                my $cap = %prm<caption>:exists ?? (HEADING-ON ~ %prm<caption> ~ HEADING-OFF ~ "\n") !! '';
                PStr.new:  $cap ~ ([~] %prm<toc-list>) ~ "\n\n"
            },
            #| renders a single item in the index
            index-item => -> %prm, $tmpl {
                my $n := %prm<level>;
                PStr.new: ($n == 1 ?? INDEX-ENTRY-ON !! "\t" x $n ) ~ %prm<entry> ~ (INDEX-ENTRY-OFF if $n == 1) ~ ': see in'
                    ~ %prm<refs>.grep( *.isa(Hash) ).map({ ' § ' ~ .<place> }).join(',')
                    ~ "\n"
            },
            #| special template to render the index data structure
            index => -> %prm, $tmpl {
                my $cap = %prm<caption>:exists ?? (HEADING-ON ~ %prm<caption> ~ HEADING-OFF ~ "\n") !! '';
                PStr.new: $cap ~ "\n" ~
                ([~] %prm<index-list>) ~ "\n\n"
            },
            #| special template to render the footnotes data structure
            footnotes => -> %prm, $tmpl {
                if %prm<footnotes>.elems {
                PStr.new: "\n" ~ HEADING-ON ~ 'Footnotes' ~ HEADING-OFF ~ "\n" ~
                    %prm<footnotes>.map({
                        FOOTNOTE-ON ~ $_.<fnNumber> ~ FOOTNOTE-OFF ~ '. ' ~ $_.<contents>.Str
                    }).join("\n") ~ "\n\n"
                }
                else { '' }
            },
            #| special template to render the warnings data structure
            warnings => -> %prm, $tmpl {
                if %prm<warnings>.elems {
                    PStr.new: HEADING-ON ~ 'WARNINGS' ~ HEADING-OFF ~ "\n" ~
                    %prm<warnings>.kv.map({ $^a + 1 ~ ": $^b" }).join("\n") ~ "\n\n"
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
			    PStr.new: FOOTNOTE-ON ~ '[' ~ %prm<fnNumber> ~ ']' ~ FOOTNOTE-OFF
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
			    my $target = %prm<target>.subst(/ '.*' /, ".%prm<output-format>", :g);
			    LINK-TEXT-ON ~ %prm<link-label> ~ LINK-TEXT-OFF ~
			    '[' ~
			    ( given %prm<type> {
			        when 'internal' { 'this page: ' }
			        when 'external' { 'internet location: ' }
			        when 'local' { 'this location (site): ' }
                } ) ~
			    LINK-ON ~ $target ~ LINK-OFF ~
			    ']'
			 },
            #| P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            #| Placement link
			markup-P => -> %prm, $tmpl {
			    given %prm<schema> {
			        when 'defn' {
			            DEFN-TERM-ON ~ %prm<contents> ~ DEFN-TERM-OFF ~ "\n\x2997" ~
			            %prm<defn-expansion> ~
			            "\n\x2998"
			        }
			        default { %prm<contents> }
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
			markup-M => -> %prm, $tmpl { CODE-ON ~ %prm<contents> ~ CODE-OFF },
            #| X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            #| Index entry ( X<display text|entry,subentry;...>)
			markup-X => -> %prm, $tmpl { INDEXED-ON ~ %prm<contents> ~ INDEXED-OFF },
            #| Unknown markup, render minimally
            markup-bad => -> %prm, $tmpl { BAD-MARK-ON ~ %prm<contents> ~ BAD-MARK-OFF },
        ); # END OF TEMPLATES (this comment is to simplify documentation generation)
    }
    #| returns hash of test helper callables
    multi method default-helpers {
        %(
            add-to-toc => -> %h {
                $*prs.toc.push:
                    { :caption(%h<caption>.Str), :target(%h<target>), :level(%h<level>) },
            },
            add-to-index => -> %h {
                $*prs.index.push:
                    { :contents(%h<contents>.Str), :target(%h<target>), :place(%h<place>) },
            },
            add-to-footnotes => -> %h {
                $*prs.footnotes.push:
                    { :retTarget(%h<retTarget>), :fnTarget(%h<fnTarget>), :fnNumber(%h<fnNumber>) },
            },
            add-to-warnings => -> $warn {
                $*prs.warnings.push: $warn
            }
        )
    }
}

RakuDoc::Processor.^set_ver( $?DISTRIBUTION.meta<version> );

# Subs to return a string of an ast that may contain embedded RakuDoc
# The naive Str method of ast does not recursively stringify embedded RakuDoc

#| returns string value of head ast, expanding all embedded RakuDoc
#| block level RakuDoc are not recogised inside a head block
sub textify-head($ast) is export {
    return 'Not a head block' unless $ast.isa(RakuAST::Doc::Block) && $ast.type eq <head numhead>.any;
    $ast.paragraphs.map(&rakudoc2text).join
}
#| returns string value of Markup with only contents of embedded Rakudoc
sub textify-markup($ast) {
    return 'Not valid markup' unless $ast.isa(RakuAST::Doc::Markup);
    rakudoc2text($ast).join
}
# adapted from @lizmat's RakuDoc-to-Text
# basically make sure Cool stuff that crept in doesn't bomb
my multi sub rakudoc2text(Str:D $string --> Str:D) { $string   }
my multi sub rakudoc2text(Cool:D $cool  --> Str:D) { $cool.Str }
# make sure we only look at interesting ::Doc objects
my multi sub rakudoc2text(RakuAST::Node:D $ast --> Str:D) {
    $ast.rakudoc.map(&rakudoc2text).join
}
# blocks in headers are not defined
my multi sub rakudoc2text(RakuAST::Doc::Block:D $ast --> Str:D) { '' }
# declarator targets ignored
my multi sub rakudoc2text(RakuAST::Doc::DeclaratorTarget:D $ast --> Str:D) { '' }
# handle simple paragraphs (that will be word-wrapped)
my multi sub rakudoc2text(RakuAST::Doc::Paragraph:D $ast --> Str:D) {
    $ast.atoms.map(&rakudoc2text).join.naive-word-wrapper ~ "\n"
}
# handle markup by returning only contents
my multi sub rakudoc2text(RakuAST::Doc::Markup:D $ast --> Str:D) {
    my str $letter = $ast.letter;
    # ignore some markup
    if $letter eq <Z Δ P D>.any { '' }
    elsif $letter eq 'A' {
        rakudoc2text $ast.meta.head
    }
    elsif $letter eq <C V>.any {
        rakudoc2text $ast.atoms.join
    }
    else {
        $ast.atoms.map(&rakudoc2text).join
    }
}
