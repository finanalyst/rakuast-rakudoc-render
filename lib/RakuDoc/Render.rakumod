use experimental :rakuast;
use RakuDoc::Processed;
use RakuDoc::Templates;
use RakuDoc::ScopedData;
use RakuDoc::MarkupMeta;
use RakuDoc::PromiseStrings;
use RakuDoc::Numeration;
use RakuDoc::Citations;
use LibCurl::Easy;
use Digest::SHA1::Native;
use URI;
use YAMLish;
#no precompilation; note 'Render debug: no precompilation';
#use Data::Dump::Tree; note 'Render debug: using DDD';
#use REPL; note 'Render debug: using REPL module';

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
    constant @built-in = <
        cell code input output comment head defn item nested para
        rakudoc section pod table formula citation
    >;
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
        $!scoped-data.start-scope( :starter('document') );
        $!scoped-data.last-title( $!current.document-options<FrontMatter> );

        # the following maps cannot be hyperised because the order of
        # blocks in the document is important for the numeration counters and Toc
        my ProcessedState $*prs .= new;
        if $ast ~~ RakuAST::StatementList {
            $ast.rakudoc.map( { $.handle( $_ ) } )
        }
        elsif $ast ~~ List {
            $ast.map( { $.handle( $_ ) } )
        }
        else { return 'Unknown type of AST' }
        $!current += $*prs;
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
        # The pattern for ToC, Index, and Citations is:
        # check if structure is populated, otherwise do not render
        # check if a =place is specifed, otherwise generate
        # an auto-placement that covers all items in structure
        #Valid specs would be:
        #=item C<*> (all levels of the default ToC)
        #=item C<1..4> (levels 1-4 of the default ToC)
        #=item C<Diagrams> (meaning all levels of the Diagrams ToC)
        #=item C<Diagrams,*> (all levels of the Diagrams ToC)
        #=item C<table,1..4> (levels 1..4 of the table ToC)
        my %doc-options := $!current.document-options;
        # check auto-citations for caption or to remove default Bibliography
        my $caption = %doc-options<auto-citations> // False;
        # check to see if there are Q<> markup, and if so, expand them
        # also render the cited bibliography with links - if output format allows it
        my $got-qs = $!current.q-codes.elems.so;
        self.expand-qcodes if $got-qs;
        # check whether any citation list is placed
        my @place-citations = $!register.list-unexpanded('citation');
        if @place-citations.elems {
            # manage filtered citations
            for @place-citations -> (:key($id), :value($spec)) {
                $!register.add-payload(:payload( self.make-bibliography($spec)), :$id);
            }
            $!current.rendered-citations = ''; # remove the default
        }
        elsif $caption and $got-qs {
            # when there are no placed bibliographies,
            # and there are q-codes
            # use the default created for cited references
            my $target = $.name-id(textify-head($caption));
            # add a heading to the cited bibligraphy and place in ToC
            $!current.rendered-citations = %!templates<head>( %( :contents($caption), :$target, :1level) ).Str
                ~ $!current.rendered-citations;
            # add directly to ToC in current processed object, not $*prs, which is no longer used
            $!current.toc.push: %( :toc-type<head>, :$caption, :$target, :1level, :numeration(''))
        }
        my $make-summary = %doc-options<auto-toc> // False;
        if $make-summary and $!current.toc.elems {
            my @place-toc = $!register.list-unexpanded('toc');
            if @place-toc {
                #render filtered toc, if any
                for @place-toc -> (:key($id), :value($spec)) {
                    my $payload = self.complete-toc( :$spec, :caption('')).strip.Str;
                    $!register.add-payload(:$payload, :$id)
                }
            }
            unless @place-toc.grep({ .value ~~ / ^ \d | ^ '*' | ^ 'head' / }) {
                # auto generate unless place has done this
                $!current.rendered-toc = self.complete-toc( :spec( '*'), :caption( %doc-options<auto-toc>));
                for $!current.rendered-toc.has-PCells {
                    $!current.warnings.push( 'In ToC: ' ~ $_ )
                }
                $!current.rendered-toc .= Str;
            }
        }
        # render indices
        $make-summary = %doc-options<auto-index> // False;
        if $make-summary and $!current.index.elems {
            my @place-index = $!register.list-unexpanded('index');
            if @place-index {
                #render filtered toc, if any
                for @place-index -> (:key($id), :value($spec)) {
                    my $payload = self.complete-index( :$spec, :caption('')).strip.Str;
                    $!register.add-payload(:$payload, :$id)
                }
            }
            else {
                $!current.rendered-index = self.complete-index( :spec( '*'), :caption( %doc-options<auto-index>));
                for $!current.rendered-index.has-PCells {
                    $!current.warnings.push( 'In Index: ' ~ $_ )
                }
                $!current.rendered-index .= Str;
            }
        }
         $!current.body.strip; # replace expanded PCells with Str
        # all suspended PCells should have been replaced by Str
        # Remaining PCells should trigger warnings
        my @pcells = $!current.body.has-PCells;
        if @pcells.elems {
            $!current.warnings.push( $_ ) for @pcells
        }
        # add any possible numeration warnings
        $!current.warnings.append: $!scoped-data.numeration-warnings;
        $!current.warnings = () unless %doc-options<error>;
        $pre-finalised ?? $.current !! $.finalise
    }

    method finalise( --> Str ) {
        $.post-process(
            %!templates<final>( %(
                :body($!current.body.Str),
                :source-data($!current.source-data),
                :document-options($!current.document-options),
                :name($!current.name),
                :title($!current.title),
                :title-target($!current.title-target),
                :subtitle($!current.subtitle),
                :modified($!current.modified),
                :rendered-toc($!current.rendered-toc),
                :rendered-index($!current.rendered-index),
                :rendered-citations($!current.rendered-citations),
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
            next if $plugin.starts-with('#');
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
            ?? ~$ast !! $.compactify( $ast );
    }
    multi method handle(RakuAST::Node:D $ast) {
        $ast.rakudoc.map({ $.handle($_) })
    }
    multi method handle(RakuAST::Doc::Block:D $ast) {
        my $prs := $*prs;
        my $type = $ast.type;
        if $!scoped-data.verbatim {
            $prs.body ~= $ast.set-paragraphs( $ast.paragraphs.map({ $.handle($_) }) ).DEPARSE;
            return
        }
        my $level = $ast.level || 1;
        say "Doc::Block type: $type (level $level)"
            ~ ( ' [for]' if $ast.for )
            ~ ( ' [abbreviated]' if $ast.abbreviated and ! $ast.directive )
            ~ ( ' [directive]' if $ast.directive )
            ~ ( ' [extended]' unless $ast.for or $ast.abbreviated or $ast.directive )
            if $.debug (cont) BlockType;
        # create config
        my %config = $.merged-config( $ast, "$type$level" );

        # All blocks have contents and may have TOC related metadata
        # handle enumerated blocks
        my $numerate = False;
        if $type ~~ / 'num' (.+) $ / {
            $type = ~ $0;
            # by default numitem & numdefn appearing after the same type are continued
            # unless explicitly continued or not continued
            if $type ~~ <alias begin end for place config finish row column counter document>.any {
                $prs.warnings.push: qq:to/WARN/;
                'num' may not be prefixed to directive ｢$type｣.
                WARN
            }
            else {
                $numerate = True
            }
        }
        # When any block, other than =item or =defn, is started,
        # there may be a list of preceding items or defns, which need to be
        # completed and rendered
        $prs.body ~= $.complete-item-list unless $type eq 'item';
        $prs.body ~= $.complete-defn-list unless $type eq 'defn';

        # Not all Blocks create a new scope. Some change the current scope data
        given $type {
            # First deal with directives. These are treated like blocks in AST

            # =alias
            # Define a RakuDoc macro, scoped to the current block
            when 'alias' { $.manage-alias( $ast ) }
            # =config
            # Block scope modifications to a block or markup instruction
            when 'config' { $.manage-config($ast) }
            when 'counter' {
                $!scoped-data.counter-tracker
                        .manage-counter( self.contents($ast, 'counter' ), %config )
            }
            # =document
            when 'document' { $.manage-document($ast) }
            # =cell
            # Contains data in a procedural table
            # =column
            # Start a new column in a procedural table
            # =row
            # Start a new row in a procedural table
            # In this renderer they are handled inside the Table routine, and are illegal outside it
            when <cell column row>.any {
                $prs.warnings.push: qq:to/WARN/;
                The directive ｢{ $ast.DEPARSE }｣ may not exist outside a 'table' block.
                WARN
            }
            # =implicit code created by indenting, and is not generated as a block with begin / end
            # but by specification is treated as code
            when 'implicit-code' {
                $!scoped-data.counter-tracker.process-counter( 'code', 1, :%config );
                $.gen-codeish( $ast, %config, 'code', 1, False )
            }
            # All blocks that are not directive or rakudoc pod nested or section need to manage counters
            when <alias begin end for place config finish
                row column counter document
                rakudoc pod nested section citation>.none {
                $!scoped-data.counter-tracker.process-counter( $type, $level, :%config );
                proceed; #continue with other handlers
            }
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
            when any(<code input output>) {
                $.gen-codeish( $ast, %config, $type, $level, $numerate )
            }
            when 'nested' {
                $.gen-nested( $ast, %config, $type, $level, $numerate )
            }
            when 'para' {
                $.gen-paraish( $ast, %config, $type, $level, $numerate )
            }
            # =comment
            # Content to be ignored by all renderers
            when 'comment' { '' }
            # =formula
            # Render content as LaTex formula
            when 'formula' { $.gen-formula($ast, %config, $type, $level, $numerate) }
            # =head
            # First-level heading
            # =headN
            # Nth-level heading
            when 'head' { $.gen-head($ast, %config, $type, $level, $numerate) }
            # =item
            # First-level list item
            # =itemN
            # Nth-level list item
            when 'item' { $.gen-item($ast, %config, $type, $level, $numerate) }
            # =defn
            # Definition of a term
            when 'defn' { $.gen-defn($ast, %config, $type, $level, $numerate) }
            when 'place' { $.gen-place($ast, %config, $type, $level) }
            # =citation
            when 'citation' { $.gen-citation($ast, %config, $type, $level, $numerate) }
            # =rakudoc
            # No "ambient" blocks inside
            # could be called if P<> embeds a RakuDoc file
            when 'rakudoc' | 'pod' { $.gen-rakudoc($ast, %config, $type, $level, $numerate) }
            # =pod
            # Legacy version of rakudoc
#           when 'pod' { '' } # when rakudoc differs from pod
            # =section
            # Defines a section
            # section does not have its own output, so numsection has no meaning
            when 'section' {
                $!scoped-data.start-scope( :starter($_) ); # title will be a Block number
                $.gen-section($ast, %config, $type, $level, $numerate);
                $!scoped-data.end-scope;
            }
            # =table
            # Visual or procedural table
            when 'table' { #toc
                $!scoped-data.start-scope( :starter($_) ); # title will be a Block number
                $.gen-table($ast, %config, $type, $level, $numerate);
                $!scoped-data.end-scope;
            }
            # Semantic blocks (SYNOPSIS, TITLE, etc.)
            when all($_.uniprops) ~~ / Lu / {
                # in RakuDoc v2 a Semantic block must have all uppercase letters
                $!scoped-data.start-scope( :starter('semantic') );
                $!scoped-data.last-title( $_ );
                $.gen-semantics($ast, %config, $type, $level, $numerate);
                $!scoped-data.end-scope;
            }
            # CustomName
            # User-defined block
            when any($_.uniprops) ~~ / Lu / and any($_.uniprops) ~~ / Ll / {
                # in RakuDoc v2 a custom block must have mix of uppercase and lowercase letters
                $!scoped-data.start-scope( :starter($_) );
                $!scoped-data.last-title( $_ );
                $.gen-custom($ast, %config, $type, $level, $numerate);
                $!scoped-data.end-scope;
            }
            default { $.gen-unknown-builtin($ast, %config, $type, $level, $numerate) }
        }
    }
    # RakuDoc declarator block
    multi method handle(RakuAST::Doc::DeclaratorTarget:D $ast) {
        $*prs.warnings.push: qq:to/WARN/;
            ｢{ $ast.DEPARSE }｣ is a declarator block and not rendered for text-based output formats.
            WARN
    }
    my @format-codes = <B H I J K R T U O W>;
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
                $prs.body ~= %!templates<markup-N>(
                    %( %config, :$retTarget, :$fnNumber, :$fnTarget )
                );
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
                        ~ " in block ｢$context｣ with heading ｢$place｣.");
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
                    $prs.warnings.push("Markup-M failed: no meta information. Got ｢{ $ast.DEPARSE }｣");
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
                    }
                }
                else {
                    # template is spelt like a SEMANTIC or builtin
                    $prs.body ~= %!templates<markup-M>( %(:$contents ) );
                    $prs.warnings.push("Markup-M failed: first meta string must conform to Custom template spelling. Got ｢{ $ast.DEPARSE }｣")
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

            # Q< METADATA = list of quoted sources >
            # leave a PCell - to be filled later - for
            # the marker, and for content to be made visible
            # with a mouse-over
            when 'Q' {
                my $mark = self.markup-contents($ast).Str.trim;
                my $id = 'QCode_' ~ self.name-id( $mark );
                my $contents = PCell.new( :$id, :$!register );
                $prs.q-codes{ $id } = $mark;
                $prs.body ~= %!templates<markup-Q>( %( :$contents ))
            }
            # Z< METADATA = COMMENT >
            # Comment zero-width  (contents never rendered)
            when 'Z' {
                $prs.body ~= '';
            }

            ## Undefined and reserved, so generate warnings
            # do not go through templates as these cannot be redefined
            when any(<G Y>) {
                $prs.body ~= %!templates{"markup-bad"}( %( :contents($ast.DEPARSE), ) );
                $prs.warnings.push(
                    "｢$letter｣ is not defined, but is reserved for future use"
                        ~ " in block ｢$context｣ with heading ｢$place｣.")
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
            }
            default {
                $prs.body ~= %!templates{"markup-bad"}( %( :contents($ast.DEPARSE), ) );
                $prs.warnings.push("｢$letter｣ may not be a markup code"
                        ~ " in block ｢$context｣ with heading ｢$place｣.")
            }
        }
    }
    #| A Doc::Paragraph is created by the parser when a text has embedded markup
    #| It is not necessarily a para block
    #| Implied para blocks are detected in the contents method
    multi method handle( RakuAST::Doc::Paragraph:D $ast ) {
        if $!scoped-data.verbatim {
            $ast.atoms.map({ $.handle($_) });
            return
        }
        my $rem = '';
        $rem = $.complete-item-list ~ $.complete-defn-list unless $!scoped-data.in-item;
        my %config = $.merged-config($, 'para' );
        do {
            my ProcessedState $*prs .= new;
            for $ast.atoms { $.handle($_) }
            my $prs := $*prs;
            my PStr $contents = $prs.body.clone;
            # each para should have a target, generate a SHA if no id given
            my $target = %config<id> // $.para-target($contents);
            my $is-in-head = $!scoped-data.in-head.so;
            $prs.body .= new( $rem );
            # deal with possible inline definitions
            if $prs.inline-defns.elems {
                for $prs.inline-defns.list -> $term {
                    $prs.warnings.push(
                        "Definition ｢$term｣ has been redefined as an inline"
                        ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
                        ) if $prs.definitions{ $term }:exists && %config<error>;
                    $prs.definitions{ $term } = $contents, $target;
                    $!register.add-payload(:payload($contents), :id($term));
                    $!register.add-payload(:payload($target), :id($term ~ '_target'))
                }
                $prs.inline-defns = ()
            }
            if $!scoped-data.in-item or $!scoped-data.in-q-code or $!scoped-data.in-para {
                $prs.body ~= $contents
            }
            elsif $!scoped-data.last-starter ~~ < document section semantic >.any {
                 my $rv = %!templates<para>(
                    %( :$contents, :$target, %config )
                );
                $prs.body ~= $rv;
            }
            else {
                $prs.body ~=$contents
            }
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
        return %() unless +@r;
        my @refs;
        my %h = %( :@refs, sub-index => %( ) );
        $.merge-index( %h<sub-index>, $.add-index( @r[ 1 .. *-1 ] , $ref ) ) if @r[1 .. *-1].elems.so;
        %( @r[0] => %h.clone )
    }

    # gen-XX methods take an $ast, process the contents, based on a template,
    # and add the string to a structure, typically, not always, to $*prs.body
    # They must all respect numerate, which means pulling in the block's enumeration

    #| generic code for code, input, output blocks
    #| No ToC content is added unless overridden by toc/caption/headlevel
    method gen-codeish( $ast, %config, $type, $level, $numerate, :$implied = False ) {
        my PStr $contents .= new;
        # item & para counters need to be triggered when implied by Str within Extended Blocks
        $!scoped-data.start-scope(:starter($type), :verbatim );
        if $type eq 'code' {
            if %config<allow>:exists {
                %config<in_code_context> = True;
                my %*ALLOW = %config<allow>
                    .grep({ any(@format-codes) })
                    .map({ $_ => True }).hash;
                $contents ~= $.contents($ast, $type);
            }
            else {
                $contents ~= $ast.paragraphs.map( *.Str ).join
            }
        }
        else {
            $contents ~= $.contents($ast, $type );
        }
        my $prs := $*prs;
        %config<caption> = $.option-contents( %config<caption> ) if %config<caption>;
        # help-numerate needs original $caption
        my $numeration = $numerate ?? self.help-numerate($type, $level, $contents, %config ) !! ();
        # hack to save out of verbatim scope
        my $last-numeration = $numerate
                ?? $!scoped-data.counter-tracker.last-enumeration($type, $level, :counter( %config<counter> // '') )
                !! Nil;
        my $caption = %config<caption> ?? ( %config<caption>:delete ) !! $type.tc;
        my $target = %config<id> // $.name-id($caption);
        self.help-toc(%config<toc>, $prs, $caption, $target, ( %config<headlevel> // $level), $numeration);
        $prs.body ~= $.complete-item-list;
        $prs.body ~= $.complete-defn-list;
        $prs.body ~= %!templates{ $type }(
            %( :$contents, :$numeration, :$caption, %config)
        );
        $!scoped-data.end-scope;
        # This feels a bit hacky
        # Basically a whole block scope seems too much to handle the inside of a codeish block
        $!scoped-data.counter-tracker.save-enumeration( $type, $level, $last-numeration ) if $numerate;
        self.manage-numalias($type, $level, $contents, $caption, %config);
    }
    #| nested is a container block; $level, num prefix and counters are ignored
    #| toc and caption are also ignored
    method gen-nested( $ast, %config, $type, $level, $numerate, :$implied = False ) {
        my PStr $contents .= new;
        $contents ~= $.contents($ast, $type );
        my $prs := $*prs;
        $prs.body ~= $.complete-item-list;
        $prs.body ~= $.complete-defn-list;
        $prs.body ~= %!templates{ $type }(
            %( :$contents, %config)
        );
    }
    #| code for para and implied para from container blocks
    #| No ToC content is added unless overridden by toc/caption/headlevel
    #| The para counter is triggered by the caller of this method
    method gen-paraish( $ast, %config, $type, $level, $numerate, :$in-type = ''  ) {
        my PStr $contents .= new;
        $!scoped-data.in-para = True;
        my @extension = ();
        if $ast ~~ RakuAST::Doc::Block && !$ast.for && !$ast.abbreviated && $ast.paragraphs.elems > 1 {
            $contents ~= $.contents( $ast.paragraphs.head, $type );
            @extension = $ast.paragraphs.tail( * -1  ).map({ $.contents( $_, $type ).clone })
        }
        else {
            $contents ~= $.contents( $ast, $type )
        }
        my $prs := $*prs;
        $prs.body ~= $.complete-item-list;
        $prs.body ~= $.complete-defn-list;
        %config<caption> = $.option-contents( %config<caption> ) if %config<caption>;
        # help-numerate needs caption in config
        my $numeration = $numerate ?? self.help-numerate($type, $level, $contents, %config ) !! ();
        my $caption = (%config<caption> // $type.tc).Str;
        %config<id> //= $.name-id($caption);
        self.help-toc(%config<toc>, $prs, $caption, %config<id>, ( %config<headlevel> // $level), $numeration);
        $prs.body ~= %!templates{ $type }(
            %( :@extension, :$contents, :$numeration, :$caption, %config)
        );
        $!scoped-data.in-para = False;
        self.manage-numalias($type, $level, $contents, $caption, %config);
    }
    #| A header adds contents at given level to ToC, unless overridden by toc/headlevel/caption
    #| toc and caption can be set by a config directive,
    #| headlevel cannot because it should be set by the head level itself
    #| The id option may be used to create a target
    #| An automatic target is also created from the contents
    method gen-head($ast, %config, $type, $level, $numerate ) {
        # stringify ast for internal use
        # set up data for embedded markup in header, eg., X
        my $textified = textify-head($ast);
        my $target = $.name-id($textified);
        # must set in-head in case of other inner scopes.
        $!scoped-data.in-head = $target;
        # P<> markup is not expected in a heading
        my $contents = $.contents($ast, $type).strip.trim.Str;
        %config<caption> = $.option-contents( %config<caption> ) if %config<caption>;
        # help-numerate needs caption in config
        my $prs := $*prs;
        #| When numeration is required, numerate will be True
        #| Then the specification requires
        #| :form to have a (default) value
        #| :numalias may be set, in which case the Tag will refer to the numeration value
        #| =head differs from other blocks as default order of enum & caption,
        my $numeration = $numerate ?? self.help-numerate($type, $level, $contents, %config, :from-head)
                !! ();
        my $caption = %config<caption> ?? ( %config<caption>:delete ) !! $contents;
        # allow internal X<> to have the final rendered title
        $!register.add-payload(:payload($contents), :id( $target ) );
        # set the last title for paragraphs following the title
        $!scoped-data.last-title( $contents );
        my $id = %config<id>:delete ;
        with $id {
            if self.is-target-unique( $_ ) {
                $id = self.register-target( $_ );
                $!register.add-payload(:payload($contents), :id( $id ) );
            }
            else {
                $prs.warnings.push("Attempt to register already existing id ｢$_｣ as new target in heading ｢$contents｣")
            }
        }
        else { $id = '' }
        self.help-toc((%config<toc> // 'head'), $prs, $caption, $target, (%config<headlevel> // $level), $numeration);
        $prs.body ~= %!templates{'head'}(
            %( :$numeration, :$level, :$target, :$contents, :$caption, :$id, %config )
        );
        self.manage-numalias($type, $level, $contents, $caption, %config);
        $!scoped-data.in-head = '';
    }
    #| Content is passed verbatim to template as formula
    #| An alt text is also generated
    method gen-formula($ast, %config, $type, $level, $numerate) {
        my $raw = $ast.paragraphs.Str.join.trim;
        # create a raw version for other formula renderers
        my $prs := $*prs;
        my $alt = %config<alt> ?? $.option-contents( %config<alt>:delete ) !! '';
        %config<caption> = $.option-contents( %config<caption> ) if %config<caption>;
        # help-numerate needs caption in config
        my $numeration = $numerate ?? self.help-numerate($type, $level, '', %config) !! ();
        my $caption = %config<caption> ?? ( %config<caption>:delete ) !! $type.tc;
        my $formula = $raw; # it should be replaced in the template
        my $target = $.name-id($caption.Str);
        my $id = %config<id>;
        with $id {
            if self.is-target-unique( $_ ) {
                $id = self.register-target( $_ );
            }
            else {
                $prs.warnings.push("Attempt to register already existing id ｢$_｣ as new target in heading ｢$alt｣")
            }
        }
        self.manage-numalias($type, $level, '', $caption, %config);
        self.help-toc(%config<toc>, $prs, $caption, $target, (%config<headlevel> // $level), $numeration);
        $prs.body ~= %!templates<formula>(%(:$raw, :$formula, :$alt, :$target, :$caption, :$level, :$numeration, :$id, %config ) )
    }
    #| generates a single item and adds it to the item structure
    #| nothing is added to the .body string
    #| bullet strategy can be left to template, with bullet in %config
    method gen-item($ast, %config, $type, $level, $numerate) {
        $!scoped-data.in-item = True;
        my PStr $contents .= new;
        my @extension = ();
        if $ast ~~ RakuAST::Doc::Block && !$ast.for && !$ast.abbreviated && $ast.paragraphs.elems > 1 {
            $contents ~= $.contents( $ast.paragraphs.head, $type );
            @extension = $ast.paragraphs.tail( * -1  ).map({ $.contents( $_, $type ) })
        }
        else {
            $contents ~= $.contents( $ast, $type )
        }
        %config<caption> = $.option-contents( %config<caption> ) if %config<caption>;
        $!scoped-data.in-item = False;
        return unless $contents.Str; # ignore empty items
        # help-numerate needs caption in config
        my $numeration = $numerate ?? self.help-numerate($type, $level, $contents, %config) !! ();
        my $caption = %config<caption> ?? ( %config<caption>:delete ) !! ''; # no caption by default
        $*prs.items.push: %!templates<item>(
            %( :@extension, :$level, :$contents, :$numeration, :$caption, %config )
        );
        self.manage-numalias($type, $level, $contents, $caption, %config);
    }
    #| generates a single definition and adds it to the defn structure
    #| unlike item, a defn:
    #| - list has a flat hierarchy
    #| - can be created by a markup code
    #| - needs a target for links, and text for popup
    #| - is PCell-stored allowing for defn to be redefined
    #| like items nothing is added to the .body string until next non-defn
    method gen-defn($ast, %config, $type, $level, $numerate) {
        my $term;
        my PStr $contents .= new;
        my @extension = ();
        if $ast.paragraphs.elems >= 2 {
            $term = $ast.paragraphs[0].Str.trim; # the term may not contain embedded code
            $contents ~= $.contents( $ast.paragraphs[1], 'defn' );
            @extension = $ast.paragraphs.tail( *-2 ).map({ $.contents( $_, $type ) })
                if $ast.paragraphs.elems > 2
        }
        else {
            my $string = $ast.Str;
            $*prs.body ~= $string;
            $*prs.warnings.push(
                "Invalid definition: ｢$string｣"
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.");
            return
        }
        my $target = $.name-id("defn_$term");
        my $prs := $*prs;
        my $numeration = $numerate ?? self.help-numerate($type, $level, $term, %config) !! ();
        my $defn-expansion = %!templates<defn>(
            %( :@extension, :$term, :$target, :$contents, :$numeration, %config )
        );
        $prs.defns.push: $defn-expansion; # for the defn list to be rendered
        $prs.warnings.push(
            "Definition ｢$term｣ has been redefined"
            ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.")
            if $prs.definitions{ $term }:exists and %config<error>;
        $prs.definitions{ $term } = $defn-expansion, $target;
        # define for previously referenced
        $!register.add-payload(:payload($defn-expansion), :id($term));
        $!register.add-payload(:payload($target), :id($term ~ '_target'));
        self.manage-numalias($type, $level, $contents, '', %config); #no caption
    }
    #| A place block adds Place at level 1 to ToC unless toc/headlevel/caption set
    #| The contents of Place is a URI that is generated and then rendered with place template
    method gen-place($ast, %config, $type, $level) {
        my $uri = %config<uri>;
        %config<caption> = $.option-contents( %config<caption> ) if %config<caption>;
        my $prs := $*prs;
        if $uri ~~ / 'semantic:' (.+) / {
                %config<caption> = ~$0 unless %config<caption>;
                %config<toc> = 'head' unless %config<toc>
        }
        else {
            %config<caption> = 'Placement' unless %config<caption>
        }
        my $caption = %config<caption> ?? ( %config<caption>:delete ) !! $type.tc;
        $!scoped-data.last-title($caption);
        my $target = %config<target> = $.name-id($caption);
        with %config<id> {
            if self.is-target-unique( $_ ) {
                %config<id> = self.register-target( $_ )
            }
            else {
                $prs.warnings.push("Attempt to register already existing id ｢$_｣ as new target in heading ｢$caption｣")
            }
        }
        self.help-toc(%config<toc>, $prs, $caption, $target, (%config<headlevel> // $level), () );
        $.make-placement(:$uri, :$caption, :%config, :template<place>, :level(%config<headlevel> // $level));
    }
    method make-placement( :$uri, :$caption, :%config, :$template, :$level ) {
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
            when 'citation' {
                $keep-format = True;
                $contents =  PCell.new( :$!register, :id( "citation_$uri-body" ), :spec($uri-body) );
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
                            $prs.warnings.push($error)
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
                    $prs.warnings.push($error)
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
                        ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.")
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
            %( :$contents, :$caption, :$keep-format, :$schema, :$uri-body, :$uri, :$level, %config )
        )
    }
    #| The rakudoc block should encompass the output
    #| Config data associated with block is provided to overall process state
    #| If a rakudoc file is embedded via place, then another rakudoc block
    #| will be called.
    method gen-rakudoc($ast, %config, $type, $level, $numerate) {
        $!current.source-data<rakudoc-config> = %config;
        my $contents = self.contents($ast, $type);
        # render any tailing lists
        $contents ~= $.complete-item-list ~ $.complete-defn-list;
        $*prs.body ~= %!templates<rakudoc>( %( :$contents, %config ) );
    }
    #| A section is invisible to ToC, but is used by scoping
    #| Some output formats may want to handle section, so
    #| embedded RakuDoc are rendered and contents rendered by section template
    method gen-section($ast, %config, $type, $level, $numerate) {
        my $contents = $.contents($ast, $type);
        # render any tailing lists
        $contents ~= $.complete-item-list ~ $.complete-defn-list;
        my $id = '';
        with %config<id> {
            if self.is-target-unique( $_ ) {
                self.register-target( $_ );
                $id = $_
            }
            else {
                $*prs.warnings.push(
                    "Attempt to register already existing id ｢$_｣ as new target in ｢section｣"
                    ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.")
            }
        }
        $*prs.body ~= %!templates<section>( %( :$contents, :$id, %config ) );
    }
    #| A citation block only contains data, so is not added to ToC or have a rendered value
    #| Method can obtain data from body, URL or local file
    #| converts data to id->cls-object where cls-object is in form that citeproc can process
    #| stores in $!current.citations< categories %data<id> >
    method gen-citation($ast, %config, $type, $level, $numerate) {
        my $content = $ast.paragraphs.Str.join.trim;
        my %citations := $!current.citations;
        my @warnings := $*prs.warnings;
        # Categorize data...
        my @categories = (%config<category> // []).values;
        # create new category
        @categories.map({ %citations<categories>{$_} = SetHash.new unless %citations<categories>{$_}:exists });
        # Does the citation block load data from elsewhere???
        with %config<load> {
            # Loading external content while also specifying internal content is confusing...
            if $content ~~ /\S/ {
                @warnings.push('=citation blocks with :load<URL> and in-document data are better written as two separate blocks'
                    ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.");
            }
            my $external-content;
            when m/ ^ file ':' / {
                my URI $f-uri .= new($_);
                if $f-uri.path.Str.IO ~~ :e & :f {
                    $external-content = $f-uri.path.Str.IO.slurp;
                }
                else {
                    my $error = "No file found at ｢$f-uri｣";
                    @warnings.push($error)
                }
            }
            default {
                # Load and convert external data to internal Raku format, categorizing as well...
                my LibCurl::Easy $curl .= new(:URL($_), :followlocation, :failonerror );
                try {
                    $external-content = $curl.perform.content;
                }
                if $! {
                    my $error = "URL ｢$_｣ caused LibCurl Exception, response code ｢{ $curl.response-code }｣ with error ｢{ $curl.error }｣";
                    @warnings.push($error)
                }
            }
            if $external-content ~~ / \S / {
                for convert-to-id-cls($external-content, $!current.warnings ) -> ($id, $cls) {
                    %citations<categories>{ @categories }».set($id);
                    %citations<data>{$id} = $cls
                }
            }
            else {
                @warnings.push( "Could not load citation data from %config<load>"
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.");
            }
        }
        # Convert citation block data to CSL data that will be used by citation and store it under its ID (or one we made up)...
        if $content ~~ /\S/ {
            for convert-to-id-cls($content, $!current.warnings ) -> ($id, $cls) {
                %citations<categories>{ @categories }».set($id);
                %citations<data>{$id} = $cls
            }
        }
    }
    #| Table has two forms of content: procedural / visual
    #| can take all standard options
    multi method gen-table($ast, %config, $type, $level, $numerate) {
        %config<caption> = $.option-contents( %config<caption> ) if %config<caption>;
        # help-numerate needs caption in config
        my $prs := $*prs;
        my $numeration = $numerate ?? self.help-numerate($type, $level, '', %config) !! ();
        my $caption = %config<caption> ?? ( %config<caption>:delete ) !! $type.tc;
        my $target = $.name-id($caption) if $caption;
        $!scoped-data.last-title( $target );
        my $id = %config<id>;
        with $id {
            if self.is-target-unique( $_ ) {
                $id = self.register-target( $_ );
            }
            else {
                $prs.warnings.push("Attempt to register already existing id ｢$_｣ as new target in heading ｢$caption｣")
            }
        }
        self.manage-numalias($type, $level, '', $caption, %config);
        self.help-toc(%config<toc>, $prs, $caption, $target, (%config<headlevel> // $level), $numeration);
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
                    $prs.warnings.push("｢{$grid-instruction.Str}｣ is illegal as an immediate child of a =table");
                    return
                }
                next if $grid-instruction.type eq 'comment';
                given $grid-instruction.type {
                    when 'cell' {
                        my %cell-config = $grid-instruction.resolved-config;
                        my %payload = %( |@cell-context[*-1], %cell-config );
                        # to be expanded to get-contents
                        %payload<data> = $.contents( $grid-instruction, 'cell' );
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
                        $prs.warnings.push("｢{$grid-instruction.DEPARSE}｣ is illegal as an immediate child of a =table");
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
                    $prs.warnings.push("｢{$row.Str}｣ is illegal as an immediate child of a =table");
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
            :$numeration, :$procedural, :$caption, :$id, :$target, :$level,
            :$header-rows, :@headers, :@rows, :@grid,
            %config ) );
    }
    #| A lower case block generates a warning
    #| DEPARSED Str is rendered with 'unknown' template
    #| Nothing added to ToC
    method gen-unknown-builtin($ast, %config, $type, $level, $numerate) {
        my $contents = $ast.DEPARSE;
        my $prs := $*prs;
        if $type ~~ @built-in.any { # a known built-in, but to get here the block is unimplemented
            $prs.warnings.push(
                "｢$type｣ is a valid, but unimplemented builtin block"
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣.")
        }
        else { # not known so create another warning
            $prs.warnings.push(
                "｢$type｣ is not a valid builtin block, is it a misspelt Custom block?"
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
                )
        }
        $prs.body ~= %!templates<unknown>( %( :$contents, :$type, :$level ) )
    }
    #| Semantic blocks defined by spelling
    #| embedded content is rendered and passed to template as contents
    #| rendered contents is added to the semantic structure
    #| If :hidden is True, then the string is not added to .body
    #| Unless :hidden, Block name is added to ToC at level 1, unless overriden by toc/caption/headlevel
    #| TITLE & SUBTITLE by default :hidden is True and added to $*prs separately
    #| All other SEMANTIC blocks are :!hidden by default
    method gen-semantics($ast, %config, $type, $level, $numerate) {
        $!scoped-data.last-title( $type );
        # treat all semantic blocks as a heading level 1 unless otherwise specified
        my $hidden;
        my $contents;
        if $ast.for or $ast.abbreviated {
            $contents = $.contents($ast, '' ).trim
        }
        else {
            $contents = $.contents($ast, 'semantic' ).trim
        }
        %config<caption> = $.option-contents( %config<caption> ) if %config<caption>;
        # help-numerate needs caption in config
        my $numeration = $numerate ?? self.help-numerate($type, $level, $contents, %config) !! ();
        my $caption = %config<caption> ?? ( %config<caption>:delete ) !! $type.tc;
        $contents ~= $.complete-item-list ~ $.complete-defn-list;
        my $prs := $*prs;
        my $rv;
        given $type {
            when 'TITLE' {
                $hidden = True; # hide by default
                $hidden = $_ with %config<hidden>;
                $!current.title = $contents.Str;
                my $target = $!current.title-target = $.name-id( $contents.Str);
                # allows for TITLE to have its own template
                if %!templates<TITLE>:exists {
                    $rv = %!templates<TITLE>( %( :$level, :$contents, :$caption, :$target, :$numeration, %config ) )
                }
                else {
                    $rv = %!templates<semantic>( %( :$level, :$contents, :$caption, :$target, :$hidden, :$numeration, %config ) )
                }
            }
            when 'SUBTITLE' {
                $hidden = True; # hide by default
                $hidden = $_ with %config<hidden>;
                $!current.subtitle = $contents.Str;
                my $target = $.name-id($contents.Str);
                if %!templates<SUBTITLE>:exists {
                    $rv = %!templates<SUBTITLE>( %( :$level, :$contents, :$caption, :$target, :$hidden, :$numeration, %config ) )
                }
                else {
                    $rv = %!templates<semantic>( %( :$level, :$contents, :$caption, :$target, :$hidden, :$numeration, %config ) )
                }
            }
            default {
                $hidden = %config<hidden><> // False;
                # other SEMANTIC by default rendered in place
                # allows for a plugin to add a SEMANTIC blockname to templates
                my $template = %!templates{ $type }:exists ?? $type !! 'semantic';
                my $target = $.name-id($type);
                my $id = '';
                with %config<id> {
                    if self.is-target-unique( $_ ) {
                        self.register-target( $_ );
                        $id = $_
                    }
                    else {
                        $prs.warnings.push(
                            "Attempt to register already existing id ｢$_｣ as new target in ｢$type｣"
                            ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
                            )
                    }
                }
                $rv = %!templates{$template}(
                    %( :$level, :$caption, :$hidden, :$target, :$contents, :$id, :$numeration, %config )
                );
                self.help-toc((%config<toc> // 'head'), $prs, $caption, $target, (%config<headlevel> // $level), $numeration)
                    unless $hidden;
            }
        }
        $prs.semantics{ $type } = [] unless $prs.semantics{ $type }:exists;
        $prs.semantics{ $type }.push: $rv;
        self.manage-numalias($type, $level, $contents, $caption, %config);
        $prs.body ~= $rv unless $hidden;
    }
    method gen-custom($ast, %config, $type, $level, $numerate) {
        # Custom blocks are defined by their spelling
        # - the block name is added to ToC at level 1 unless changed by toc/caption/headlevel
        # If a template exists with the block name
        # - provides content verbatim to template as raw
        # - provides content rendered to template as contents
        # If NOT,
        # - the block content is rendered as verbatim text
        # - the content is rendered with 'unknown' template
        # - a warning is issued
        my $prs := $*prs;
        my $contents = $.contents($ast, $type).trim;
        %config<caption> = $.option-contents( %config<caption> ) if %config<caption>;
        # help-numerate needs caption in config
        my $numeration = $numerate ?? self.help-numerate($type, $level, '', %config) !! ();
        my $id = '';
        with %config<id> {
            if self.is-target-unique( $_ ) {
                self.register-target( $_ );
                $id = $_
            }
            else {
                $prs.warnings.push(
                    "Attempt to register already existing id ｢$_｣ as new target in ｢$type｣"
                    ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
                )
            }
        }
        my $caption = %config<caption> ?? ( %config<caption>:delete ) !! $type.tc;
        my $target = %config<id>:delete // $.name-id($caption);
        self.help-toc(%config<toc>, $prs, $caption, $target, (%config<headlevel> // $level), $numeration);
        $contents ~= $.complete-item-list ~ $.complete-defn-list;
        if %!templates{ $type }:exists {
            my $raw = $ast.paragraphs.Str.join;
            $prs.body ~= %!templates{ $type }( %( :$contents, :$raw, :$level, :$target, :$caption, :$id, :$numeration, %config ) )
        }
        else {
            my $contents = $ast.DEPARSE;
            $contents = %config<alt> if %config<alt>:exists;
            $prs.warnings.push(
            "No template exists for custom block ｢$type｣. It has been rendered as unknown"
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
            );
            $prs.body ~= %!templates<unknown>( %( :$contents, :$type, :$target, :$caption, :$numeration, :$level ) )
        }
        self.manage-numalias($type, $level, $contents, $caption, %config);
    }
    # directive type methods
    method manage-config($ast) {
        my %options = $ast.resolved-config;
        my $name = $ast.paragraphs.head.Str;
        # all blocks without a level are assumed to be level 1
        # do not add 1 if just one letter == markup code
        $name = $name ~ '1' if $name ~~ / . \D $ /;
        # strip off any num as numblock and block are the same in config
        $name .= subst(/ $ 'num' /, '');
        $!scoped-data.config( { $name => %options } );
    }
    # document options are not black scoped
    method manage-document($ast) {
        my %options = $ast.resolved-config;
        for %options.kv -> $k,$v {
            $!current.document-options{$k} = $v
        }
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
            $!scoped-data.aliases{ $term } = $expansion;
            $prs.body .= new;
            CALLERS::<$*prs> += $prs;
        }
        else {
            $prs.warnings.push("Invalid alias ｢{ $ast.Str }｣")
        }
    }
    # helper methods
    method help-numerate($type, $level, $contents, %config, :$from-head = False ) {
        my $form = (%config<form> // '').Str;
        my $numeration;
        my $caption = (%config<caption> // '').Str;
        my $counter = $!scoped-data.counter-tracker.get-enumeration($type, $level, :counter( %config<counter> // '') );
        if $form {
            $numeration = $counter.numform(:$form, :$contents, :$caption, :$type)
        }
        elsif $from-head || $type ~~ <item defn para>.any {
            $numeration = (
                $counter.Str but FieldType('N'),
                $contents but FieldType('D')
            );
        }
        else {
            $numeration =
                (
                $type.tc but FieldType('T'),
                $counter.Str but FieldType('N'),
                $caption ?? $caption but FieldType('C') !! '',
                )
        }
        $numeration
    }
     # handle numalias
    method manage-numalias($type, $level, $contents, $caption, %config) {
        return unless %config<numalias>:exists;
        if %config<numalias>.Str ~~ /
        ^ $<disp> = (.+?) '|' $<tag> = (.+?) $
        |
        ^ $<tag> = (.+?) $
         / {
            my $tag = ~$<tag>.trim;
            my $expansion = '';
            my $counter = $!scoped-data.counter-tracker.last-enumeration($type, $level, :counter( %config<counter> // ''));
            # if the option value was set in a =config and there is no TAG in this block
            # then TAG will be set to *, so ignore the option
            if $<disp>:exists {
                my $form = $<disp>.Str.trim;
                if  $tag eq '*' {}
                elsif $form { # disp has a non-blank Str value and tag has a value, so disp over-rides config
                    $expansion = $counter.numform(:$form, :$caption, :$contents, :$type).list;
                }
                else { # process as default when a TAG is set but disp is blank str, so over-riding any config
                    $expansion = $type.tc but FieldType('T'), $counter.Str.chop but FieldType('N');
                }
            }
            else { #so only TAG is set
                if $!scoped-data.config{"$type$level"}<numalias> -> $c-disp { #check to see if a config specs a numalias
                    if $c-disp ~~ / ^ $<disp> = (.*) '|' \s* '*' \s* $ / {
                        $expansion = $counter.numform(:form( ~$<disp>), :$caption, :$contents, :$type)
                    }
                    else {
                        $*prs.warnings.push: "Mal-formed config declaration of numalias ｢$c-disp｣"
                    }
                }
                else { # process as default when a TAG is set but disp is blank str, so over-riding any config
                    $expansion = ($type.tc but FieldType('T'), $counter.Str.chop but FieldType('N'))
                }
            }
            if $expansion {
                $!scoped-data.aliases{ $tag } = $expansion;
            }
        }
        else {
            $*prs.warnings.push: "Mal-formed numalias ｢{ %config<numalias> }｣"
        }
    }
    method help-toc($toc,$prs, $caption, $target, $level, $numeration) {
        return unless $toc;
        given $toc {
            when Positional {
                $toc.map({
                    $_ eq '*' ??
                    $prs.toc.push(
                        %( :toc-type<head>, :$caption, :$target, :$level, :$numeration )
                    )
                    !!
                    $prs.toc.push(
                        %( :toc-type($_), :$caption, :$target, :$level, :$numeration )
                    )
                })
            }
            when Bool {
                $prs.toc.push(
                    %( :toc-type<head>, :$caption, :$target, :$level, :$numeration )
                ) if $toc
            }
            when Str {
                $prs.toc.push(
                    %( :toc-type($_), :$caption, :$target, :$level, :$numeration )
                )
            }
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
    #| Return a string with rendered bibliography according to category specification
    method make-bibliography( $spec --> Str ) {
        # At the stage this method is called,
        # $!current.citations contains citation block data
        # data = hash: citation-id => specification
        # categories = hash: category => array of citation-ids
        # $!current.document-options<citation-locale> & <citation-style>
        my %citations := $!current.citations;
        my %doc-options := $!current.document-options;
        my $style := %doc-options<citation-style>;
        my $lang := %doc-options<citation-locale>;
        my @warnings := $!current.warnings;
        my @references;
        my @citations; # will be left empty for this method
        # special case * for all citations, and cited, which has already been created
        if $spec ~~ / '*' / {
            @references = %citations<data>.values
        }
        elsif $spec.trim eq 'cited' {
            return $!current.rendered-citations
        }
        else {
            my @categories = ($spec ~~ / [ $<categories>=<ident>+ ] + %% ',' /).<categories>.map(*.Str);
            my @ids =   %citations<categories>{@categories}».keys.flat;
            @references = %citations<data>{ @ids };
        }
        my %input = :@citations, :$lang, :$style, :@references ;

        my %processed = process-citations( %input, @warnings );
        $*prs .= new;
        $.handle( "=begin rakudoc\n{ %processed<bibliography>.join("\n") }\n=end rakudoc".AST.rakudoc.head );
        my $contents = '';
        my @citation-items;
        if $*prs.items.elems {
            @citation-items = $*prs.items>>.Str
        }
        else { $contents = $*prs.body.Str }
        @warnings.append: $*prs.warnings;
        %!templates<citations>( %( :$contents, :@citation-items ) ).strip.Str;
    }
    # regexes for quotations
    my token indic {
            <-[,;|\\]>+   # or non-special characters
        }
    my token suffix {
        # Same pattern as above, except raw commas are allowed...
        <-[;|\\]> *
    }
    #| take citation data and expand Q-code markers
    #| create default citations list if required
    method expand-qcodes {
        # $!current.q-codes has quotation data
        # is an array of Pairs id => unpreprocessed content of Q markup
        # $!current.document-options<citation-locale> & <citation-style>
        # $!current.body has PCells with ids QCode_xxx

        my %q-codes := $!current.q-codes;
        my %citations := $!current.citations;
        my %doc-options := $!current.document-options;
        my $style := %doc-options<citation-style>;
        my $lang := %doc-options<citation-locale>;
        my $caption := %doc-options<auto-citations>;
        my @warnings := $!current.warnings;
        # go through q-codes to verify that there are citation ids matching the quoted one, otherwise fake a citation
        my @citations = gather for %q-codes.sort -> (:$key, :value($raw)) {
            my $inf = $raw ~~ / ^ [ $<term>=(<indic> [ ',' \s* <suffix> ]?) [\s* ';' \s*]? ]+ $/;
            my @citation-items = gather for $inf.<term> {
                my $id = .<indic>.Str;
                my $suffix = .<suffix> ?? ', ' ~ .<suffix> !! '';
                unless %citations<data>{$id} {
                    %citations<data>{$id} = citation-placeholder($id, 'NO SUCH CITATION ID');
                    @warnings.push: "Q markup content ｢$id｣ does not correspond to a citation. Placeholder added."
                }
                %citations<categories><cited>{ $id }++;
                take %( :$id, :$suffix );
            }
            take @citation-items;
        }
        %citations<categories><uncited> = %citations<data>.keys (-) %citations<categories><cited>;
        my @references = %citations<data>{ %citations<categories><cited>.keys }.values;
        my %input = :@citations, :$lang, :$style, :@references ;

        my %processed = process-citations( %input, @warnings );
        return unless %processed<markers>.elems;
            # if no markers, then the citation process has failed
            # a warning has been generated, any unfilled Q will generate errors
        # Retrieve and translate the markers back to RakuDoc...
        my @markers = %processed<markers>
            .map({ "=begin rakudoc\n$_\n=end rakudoc"})
            .map( *.AST.rakudoc.head.paragraphs.head )
            .map({ self.contents( $_, 'q-code' )  }) # this to to expand internal format codes
        ;
        for %q-codes.sort>>.keys Z @markers -> ( $id, $payload ) {
            $!register.add-payload( :$payload, :$id )
        }
        # create the default citation string
        if $caption {
            my $prs := $*prs .= new;
            $.handle( "=begin rakudoc\n{ %processed<bibliography>.join("\n") }\n=end rakudoc".AST.rakudoc.head );
            my $contents = '';
            my @citation-items;
            if $prs.items.elems {
                @citation-items = $prs.items>>.Str
            }
            else { $contents = $prs.body.Str }
            @warnings.append: $*prs.warnings;
            $!current.rendered-citations = %!templates<citations>( %( :$contents, :@citation-items ) ).Str;
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
    #| renders the toc objects
    method complete-toc( :$spec, :$caption --> PStr ) {
        my Set $levels;
        my $toc-type = 'head';
        if $spec ~~ /
        ^ $<toc-type>=\w+ ',' $<range>= ['*' | \d '..' \d+ | \d] $
        | ^ $<range>= ['*' | \d '..' \d+ | \d] $
        | ^ $<toc-type>=\w+ $
        / {
            with $<toc-type> {
                $toc-type = ~$_
            }
            with $<range> {
                if '*' {
                    $levels .=new: (^10).list
                }
                else {
                    $levels .= new: .EVAL.list
                }
            }
            else {
                $levels .=new: (^10).list
            }
            my @toc-list = gather for $!current.toc.grep({ .<toc-type>.defined and (.<toc-type> eq $toc-type) }) -> $toc-entry {
                take %!templates<toc-item>( %( :$toc-entry , ) ) if $levels{ +$toc-entry<level> }
            }
            PStr.new( @toc-list.elems ?? %!templates<toc>( %(:@toc-list, :toc( $!current.toc.grep({ .<toc-type> eq $toc-type })), :$caption ) )
                                      !! '' )
        }
        else {
            $!current.warnings.push: "The place toc:spec ｢$spec｣ is mal-formed. Placement ignored.";
            PStr.new: '';
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
    #| when scope is rakudoc, pod, section or Semantic, strings are considered paragraphs
    method contents( $ast, $from ) {
        my ProcessedState $*prs .= new;
        $!scoped-data.in-q-code = True if $from eq 'q-code';
        if $ast ~~ (Str, RakuAST::Doc::Paragraph).any {
            $.handle( $ast )
        }
        else {
            for $ast.paragraphs {
                if $_ ~~ Str and $from ~~ < rakudoc pod section semantic nested >.any {
                    $!scoped-data.counter-tracker.process-counter( 'para', 1 );
                    $.gen-paraish( $_.trim, %(), 'para', 1, False );
                }
                else {
                    $.handle( $_ );
                }
            }
        }
        my $prs := $*prs;
        my $text = $prs.body.trim-trailing;
        $prs.body .= new;
        CALLERS::<$*prs> += $prs;
        $!scoped-data.in-q-code = False if $from eq 'q-code';
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
    #| return the contents of a meta option that might contain RakuDoc
    multi method option-contents( $s ) {
        return $s.Str unless $s.Str ~~ / <:Lu> \< / ; # test for a single upper case letter followed by <
        # so some embedded rakudoc markup. Get the processed content
        my $ast = "=begin rakudoc\n$s\n=end rakudoc".AST.rakudoc.head.paragraphs.head;
        # result should be a Paragraph
        $.markup-contents( $ast )
    }

    #| options reserved for counter directive
    my @counter-opts = <restart-after restart-except-after prefix restart>;

    #| get config merged from the ast and scoped data
    #| handle generic metadata options such as delta
    method merged-config( $ast, $block-name --> Hash ) {
        my %config;
        # first get the block's inline options, which take precedence
        if $ast.defined && $ast.config {
            %config = .resolved-config with $ast;
            # .resolved-config does not work for all types of keys, so check to make sure
            for ($ast.config.keys (-) %config.keys).keys -> $k {
                my $opt = $ast.config{$k};
                if $opt ~~ RakuAST::QuotedString {
                    $opt = $ast.config{$k}.DEPARSE.substr(1,*-1).trim
                }
                %config{$k} = $opt.Str
            }
        }
        return %config if $block-name eq 'counter1'; # only get ast-defined options
        # now get options declared with =config in scope
        my %scoped = $!scoped-data.config;
        %scoped{ $block-name }.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        # check to see whether anything without possible 'num'
        if $block-name ~~ / ^ 'num' (.+) $ / {
            %scoped{ ~$0 }.pairs.map({
                %config{.key} = .value unless %config{.key}:exists
            })
        }
        %scoped{ '*' }.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        %config<error> = True unless %config<error>:exists;
        if   %config.keys.grep({ $_ (elem) @counter-opts })  -> $extra {
            $*prs.warnings.push("The config directive should not contain (any of) : { '"' «~« $extra.list »~» '"' }. Should these be in a counter statement?");
        }
        if %config<delta>:exists {
            my $contents = %config<delta>:delete;
            if $contents.join(' ') ~~ / (<-[;]>+) ';'? ( .* ) $ / {
                %config<delta> = %!templates<delta>(%( :note( ~$1.trim), :versions(~$0.trim) ));
            }
            else {
                $*prs.warnings.push("The delta option is ignored because it must have the form / 'v' \\S+ \\s* (['|'] .+)? \$ / ｢{ ~$ast.DEPARSE }｣")
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
    my constant SUPERSCR-OFF = "\e[75m\e[39;49m";
    my constant SUBSCR-ON = "\e[48;5;80m\e[74m";
    my constant SUBSCR-OFF = "\e[75m\e[39;49m";
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
                PStr.new: $del ~ "\n  --- { %prm<numeration> ?? %prm<numeration>.grep( *.so )».Str.join !! 'code' } --- \n"
                ~ %prm<contents>
                ~ "\n  --- ----- ---\n"
            },
            #| renders =input block
            input => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                PStr.new: $del ~ "\n  --- { %prm<numeration> ?? %prm<numeration>.grep( *.so )».Str.join !! 'input' } --- \n"
                ~ %prm<contents>
                ~ "\n  --- ------ ---\n"
            },
            #| renders =output block
            output => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                PStr.new: $del ~ "\n  --- { %prm<numeration> ?? %prm<numeration>.grep( *.so )».Str.join !! 'output' } --- \n"
                ~ %prm<contents>
                ~ "\n  --- ------ ---\n"
             },
            #| renders =comment block
            comment => -> %prm, $tmpl { '' },
            #| renders =formula block
            formula => -> %prm, $tmpl {
                my $head = $tmpl('head', %(
                    :contents(%prm<caption>),
                    |(%prm<level id target numeration delta>:p),
                ));
                PStr.new: $head ~ %prm<formula> ~ "\n\n"
            },
            #| renders =head block
            head => -> %prm, $tmpl {
                my $del = %prm<delta> // '';
                my $indent = %prm<level> > 5 ?? 4 !! (%prm<level> - 1) * 2;
                my $title = %prm<contents>;
                $title = %prm<numeration>.grep( *.so )».Str.join if %prm<numeration>;
                "\n" ~ ' ' x $indent ~ HEADING-ON ~ BOLD-ON ~ $title ~ BOLD-OFF ~  HEADING-OFF ~
                "\n" ~ $del
            },
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
                DEFN-TERM-ON ~ (%prm<numeration> ?? %prm<numeration>.grep( *.so )».Str.join !! %prm<term>) ~ DEFN-TERM-OFF ~ "\n" ~
                DEFN-TEXT-ON ~ %prm<contents> ~
                %prm<extension>.join(' ') ~
                DEFN-TEXT-OFF ~ "\n"
            },
            #| special template to render a defn list data structure
            defn-list => -> %prm, $tmpl { [~] %prm<defn-list> },
            #| renders =item block
            item => -> %prm, $tmpl {
                if %prm<numeration> {
                    %prm<numeration>.grep( *.so )».Str.join ~ ' ' ~ %prm<extension> ~ "\n"
                }
                else {
                    my $num = %prm<level> - 1;
                    my $indent = ' ' x %prm<level>;
                    $num = @bullets.elems - 1 if $num >= @bullets.elems;
                    my $bullet = %prm<bullet> // @bullets[$num];
                    $indent ~ $bullet ~ ' ' ~
                        %prm<contents> ~ ' ' ~
                        %prm<extension>.join(' ') ~
                        "\n"
                }
            },
            #| special template to render an item list data structure
            item-list => -> %prm, $tmpl {
                "\n" ~ [~] %prm<item-list>
            },
            #| renders =nested block
            nested => -> %prm, $tmpl {
                PStr.new: (%prm<delta> // '') ~ "\t" ~ ( %prm<numeration> ?? %prm<numeration>.grep( *.so )».Str.join !! %prm<contents> ) ~  "\n\n"
            },
            #| renders =para block
            para => -> %prm, $tmpl {
                PStr.new: (%prm<delta> // '') ~
                    ( %prm<numeration> ?? %prm<numeration>.grep( *.so )».Str.join !! %prm<contents> ) ~
                    %prm<extension>.join(' ') ~
                    "\n\n"
            },
            #| renders =place block, place cannot be enumerated
            place => -> %prm, $tmpl {
                my $rv = $tmpl('head', %(
                    :contents(%prm<caption>),
                    |(%prm<level id target delta numeration >:p )
                ));
                if %prm<content-type>.contains('text') {
                    $rv ~= %prm<contents>
                }
                else {
                    $rv ~= "URI returned {%prm<content-type>}, which cannot be rendered"
                }
                $rv ~= "\n\n";
            },
            #| renders =rakudoc block
            rakudoc => -> %prm, $tmpl { %prm<contents> ~ "\n" }, #pass through without change
            #| renders =section block
            section => -> %prm, $tmpl {
                (%prm<delta> // '') ~
                ( %prm<numeration> ?? %prm<numeration>.grep( *.so )».Str.join !! %prm<contents> ) ~ "\n"
            },
            #| renders =SEMANTIC block, if not otherwise given
            semantic => -> %prm, $tmpl {
                my $head = $tmpl('head', %(
                    :contents(%prm<caption>),
                    |(%prm<level id target numeration delta>:p),
                ));
                PStr.new:
                ( $head unless %prm<hidden> ) ~
                %prm<contents> ~ "\n"
            },
            #| renders =pod block
            pod => -> %prm, $tmpl { %prm<contents> },
            #| renders =table block
            table => -> %prm, $tmpl {
                use Text::MiscUtils::Layout;
                my $del = %prm<delta> // '';
                my $caption = HEADING-ON ~ %prm<caption> ~ HEADING-OFF;
                $caption = %prm<numeration>.grep( *.so )».Str.join if %prm<numeration>;
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
                PStr.new: HEADING-ON ~ %prm<type> ~
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
                    ?? ( "\n\n" ~ '=' x (%*ENV<WIDTH> // 80) ~ "\n" ~ %prm<rendered-citations> ~ "\n" )
                    !! ''
                ) ~
                ( %prm<rendered-citations>
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
            #| special template to render the citations structure
            citations => -> %prm, $tmpl {
                my $cap = %prm<caption>:exists ?? (HEADING-ON ~ %prm<caption> ~ HEADING-OFF ~ "\n") !! '';
                PStr.new: $cap ~ "\n" ~
                    ([~] %prm<citation-items>) ~ %prm<contents> ~ "\n\n"
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
            #| W< DISPLAY-TEXT >
            #| Verbatim (internal markup instructions ignored)
            markup-W => -> %prm, $tmpl { small-caps( %prm<contents> ) },

            ##| Markup codes, optional display and meta data

            #| A< DISPLAY-TEXT |  METADATA = ALIAS-NAME >
            #| Alias to be replaced by contents of specified V<=alias> directive, or numalias option
			markup-A => -> %prm, $tmpl {
                my $c = %prm<contents>;
                my $rv = $c ~~ Positional
                    ?? $c.grep( *.so )».Str.join
                    !! $c
                    ;
                $c
            },
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
            #| Q< METADATA = citation string >
            #| (typically rendered superscript)
            markup-Q => -> %prm, $tmpl { SUPERSCR-ON ~ %prm<contents> ~ SUPERSCR-OFF },

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

# Adapted from Damian Conway's code for citations
# (Note: unaccountably, there's no Unicode SMALL CAPITAL Q, so we cheat with ǫ)...
sub small-caps ($text) {
    $text.Str.trans: 'abcdefghijklmnopqrstuvwxyzàáâãäåçèéêëìíîïñòóôõöùúûüýÿ'
            => 'ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀsᴛᴜᴠᴡxʏᴢᴀ̀ᴀ́ᴀ̂ᴀ̃ᴀ̈ᴀ̊ᴄ̧ᴇ̀ᴇ́ᴇ̂ᴇ̈ɪ̀ɪ́ɪ̂ɪ̈ɴ̃ᴏ̀ᴏ́ᴏ̂ᴏ̃ᴏ̈ᴜ̀ᴜ́ᴜ̂ᴜ̈ʏ́ʏ̈',
            'āăąćĉċčďēĕėęěĝğġģĥĩīĭįıĵķĸĺļľńņňōŏőŕŗřśŝşšţťũūŭůűųŵŷźżž'
            => 'ᴀ̄ᴀ̆ᴀ̨ᴄ́ᴄ̂ᴄ̇ᴄ̌ᴅ̌ᴇ̄ᴇ̆ᴇ̇ᴇ̨ᴇ̌ɢ̂ɢ̆ɢ̇ɢ̧ʜ̂ɪ̃ɪ̄ɪ̆ɪ̨ıᴊ̂ᴋ̧ĸʟ́ʟ̧ʟ̌ɴ́ɴ̧ɴ̌ᴏ̄ᴏ̆ᴏ̋ʀ́ʀ̧ʀ̌śŝşšᴛ̧ᴛ̌ᴜ̃ᴜ̄ᴜ̆ᴜ̊ᴜ̋ᴜ̨ᴡ̂ʏ̂ᴢ́ᴢ̇ᴢ̌',
            'ǎǐǒǔǖǘǚǜǟǡǧǩǫǭǰǵǹǻȁȃȅȇȉȋȍȏȑȓȕȗșțȥȧȩȫȭȯȱȳḁḃḅḇḉḋḍḏḑḓḕḗḙḛḝḟḡ'
            => 'ᴀ̌ɪ̌ᴏ̌ᴜ̌ᴜ̈̄ᴜ̈́ᴜ̈̌ᴜ̈̀ᴀ̈̄ᴀ̇̄ɢ̌ᴋ̌ᴏ̨ᴏ̨̄ᴊ̌ɢ́ɴ̀ᴀ̊́ᴀ̏ᴀ̑ᴇ̏ᴇ̑ɪ̏ɪ̑ᴏ̏ᴏ̑ʀ̏ʀ̑ᴜ̏ᴜ̑șᴛ̦ȥᴀ̇ᴇ̧ᴏ̈̄ᴏ̃̄ᴏ̇ᴏ̇̄ʏ̄ᴀ̥ʙ̇ʙ̣ʙ̱ᴄ̧́ᴅ̇ᴅ̣ᴅ̱ᴅ̧ᴅ̭ᴇ̄̀ᴇ̄́ᴇ̭ᴇ̰ᴇ̧̆ꜰ̇ɢ̄',
            'ḣḥḧḩḫḭḯḱḳḵḷḹḻḽḿṁṃṅṇṉṋṍṏṑṓṕṗṙṛṝṟṡṣṥṧṩṫṭṯṱṳṵṷṹṻṽṿẁẃẅẇẉẋẍẏẑẓẕ'
            => 'ʜ̇ʜ̣ʜ̈ʜ̧ʜ̮ɪ̰ɪ̈́ᴋ́ᴋ̣ᴋ̱ʟ̣ʟ̣̄ʟ̱ʟ̭ᴍ́ᴍ̇ᴍ̣ɴ̇ɴ̣ɴ̱ɴ̭ᴏ̃́ᴏ̃̈ᴏ̄̀ᴏ̄́ᴘ́ᴘ̇ʀ̇ʀ̣ʀ̣̄ʀ̱ṡṣṥṧṩᴛ̇ᴛ̣ᴛ̱ᴛ̭ᴜ̤ᴜ̰ᴜ̭ᴜ̃́ᴜ̄̈ᴠ̃ᴠ̣ᴡ̀ᴡ́ᴡ̈ᴡ̇ᴡ̣ẋẍʏ̇ᴢ̂ᴢ̣ᴢ̱',
            'ẖẗẘẙạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹœɠæðłɔɹʒγλπρψлɨǝꝵɯ'
            => 'ʜ̱ᴛ̈ᴡ̊ʏ̊ᴀ̣ᴀ̉ᴀ̂́ᴀ̂̀ᴀ̂̉ᴀ̂̃ᴀ̣̂ᴀ̆́ᴀ̆̀ᴀ̆̉ᴀ̆̃ᴀ̣̆ᴇ̣ᴇ̉ᴇ̃ᴇ̂́ᴇ̂̀ᴇ̂̉ᴇ̂̃ᴇ̣̂ɪ̉ɪ̣ᴏ̣ᴏ̉ᴏ̂́ᴏ̂̀ᴏ̂̉ᴏ̂̃ᴏ̣̂ᴏ̛́ᴏ̛̀ᴏ̛̉ᴏ̛̃ᴏ̛̣ᴜ̣ᴜ̉ᴜ̛́ᴜ̛̀ᴜ̛̉ᴜ̛̃ᴜ̛̣ʏ̀ʏ̣ʏ̉ʏ̃ɶʛᴁᴆᴌᴐᴚᴣᴦᴧᴨᴩᴪᴫᵻⱻꝶꟺ';

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
#    elsif $letter eq 'A' {
#        rakudoc2text $ast.meta.head
#    }
    elsif $letter eq <C V A>.any {
        rakudoc2text $ast.atoms.join
    }
    else {
        $ast.atoms.map(&rakudoc2text).join
    }
}
