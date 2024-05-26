use experimental :rakuast;
use RakuDoc::Processed;
use RakuDoc::Templates;
use RakuDoc::ScopedData;
use RakuDoc::MarkupMeta;
use RakuDoc::PromiseStrings;
use LibCurl::Easy;
use Digest::SHA1::Native;
use URI;

enum RDProcDebug <None All AstBlock BlockType Scoping Templates MarkUp>;

#| Class for setting numeration of headings and items
class Numeration {
    has Int @!counters is default(0);
    method Str () { @!counters>>.Str.join('.') ~ '.' }
    method inc ($level) {
        @!counters[$level - 1]++;
        @!counters.splice($level);
        self
    }
    method reset () {
        @!counters = Nil;
        self
    }
    method set ( $level, $value ) {
        @!counters[ $level - 1 ] = $value;
        self
    }
}

class RakuDoc::Processor {
    has %.templates is Template-directory;
    has CompletedCells $.register .= new;
    has RakuDoc::Processed $.current;
    has $.output-format;
    has RakuDoc::ScopedData $!scoped-data .= new;
    #| debug modes that are checked
    has SetHash $!debug-modes .= new;
    multi method debug(RDProcDebug $type --> Nil ) {
        given $type {
            when None {
                $!debug-modes = Nil;
                %!templates.debug = False;
            }
            when All {
                $!debug-modes .= new( RDProcDebug::.values.grep( none( All, None )) );
                %!templates.debug = True;
            }
            when Templates {
                %!templates.debug = True;
                proceed
            }
            default {
                $!debug-modes{ $type }++
            }
        }
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

    multi submethod TWEAK(:$!output-format = 'txt',
     :$test = False,
     :$debug = None ) {
        %!templates.source = $test ?? 'test templates' !! 'default templates' ;
        %!templates = $test ?? self.test-text-templates !! self.default-text-templates;
        %!templates.helper = self.text-helpers;
        if $debug ~~ List { self.debug($debug.list) }
        else { self.debug( $debug ) }
    }

    #| renders to a String by default,
    #| but returns ProcessedState object if pre-finalised = True
    multi method render( $ast, :%source-data, :pre-finalize(:$pre-finalised) = False ) {
        $!current .= new(:%source-data, :$!output-format );
        my ProcessedState $*prs .= new;
        $ast.rakudoc.map( { $.handle( $_ ) } );
        $!current += $*prs;
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
        # Since the footnote order may only be known at the end
        # footnote numbers are PCells, which need triggering
        self.complete-footnotes;
        # P<toc:>, P<index:> may put PCells into body
        # so ToC and Index need to be rendered and any other PCells triggered
        # toc may contain numbered captions, so the heading-numbers need to be calculated
        self.complete-heading-numerations;
        my $rendered-toc = PCell.new( :$!register, :id<toc-schema> );
        self.complete-toc;
        my $rendered-index = PCell.new( :$!register, :id<index-schema> );
        self.complete-index;
        # placed semantic blocks now need triggering
        for $!current.semantics.kv -> $block, @vals {
            $!register.add-payload( :payload( @vals.join ), :id("semantic-schema_$block") )
        }
        # All PCells should be triggered by this point
        $!current.body.strip; # replace expanded PCells with Str
        # all suspended PCells should have been replaced by Str
        # Remaining PCells should trigger warnings
        if $!current.body.has-PCells {
            while $!current.body.debug ~~ m :c / 'PCell' .+? 'Waiting for: ' $<id> = (.+?) \s \x3019 / {
                $!current.warnings.push( "Still waiting for ｢{ $/<id> }｣ to be expanded." )
            }
        }
        return $.current if $pre-finalised;
        # Placing of footnotes, ToC etc, is left to final template
        %!templates<final>( %( :processed( $!current ), :$rendered-index, :$rendered-toc ) ).Str
    }

    method compactify( Str:D $s ) {
        $s .subst(/ \v+ /,' ',:g )
        .subst(/ <?after \S\s> \s+ /, '', :g)
    }

    #| All handle methods may generate debug reports
    proto method handle( $ast ) {
        say "Handling: { $ast.WHICH.Str.subst(/ \| .+ $/, '') }"
            if $.debug (cont) AstBlock;
        {*}
    }
    multi method handle(Str:D $ast) {
        $*prs.body ~= $!scoped-data.verbatim
            ?? ~$ast !! $.compactify( $ast )
    }
    multi method handle(RakuAST::Node:D $ast) {
        $ast.rakudoc.map({ $.handle($_) })
    }
            # =column
            # Start a new column in a procedural table

            # =row
            # Start a new row in a procedural table

            # =formula
            # Render content as LaTex formula

    multi method handle(RakuAST::Doc::Block:D $ast) {
        if $!scoped-data.verbatim {
            $*prs.body ~= $ast.set-paragraphs( $ast.paragraphs.map({ $.handle($_) }) ).DEPARSE;
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
        # there may be a list of preceeding items or defns, which need to be
        # completed and rendered
        $*prs.body ~= $.complete-item-list unless $type eq 'item';
        $*prs.body ~= $.complete-defn-list unless $type eq 'defn';

        # Not all Blocks create a new scope. Some change the current scope data
        given $ast.type {
            # =alias
            # Define a RakuDoc macro, scoped to the current block
            when 'alias' {
                if $ast.paragraphs.elems >= 2 {
                    my $term = $ast.paragraphs[0].Str; # it should be a string without embedded codes
                    my $expansion = $ast.paragraphs[1 .. *-1 ].map({ $.handle( $_ ) });
                    $!scoped-data.aliases{ $term } = $expansion;
                }
                else {
                    $*prs.warnings.push: "Invalid alias ｢{ $ast.Str }｣"
                }
            }
            # =code
            # implicit code created by indenting
            # =para block, as opposed to unmarked paragraphs in a block
            # not the same as a logical Doc::Paragraph, which has atoms, not paragraphs
            # =nested
            # Nest block contents within the current context
            # unlike =section, does not create block scope
            # =input
            # Pre-formatted sample input
            # =output
            # Pre-formatted sample output
            when any(<code implicit-code para nested input output>)
            {
                $.gen-paraish( $ast, $ast.type, $parify )
            }
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
                $!scoped-data.start-scope(:starter($_)) if $parify;
                say $!scoped-data.debug if $.debug (cont) Scoping ;
                $.gen-headish($ast, $parify);
                $!scoped-data.end-scope if $parify;
                say $!scoped-data.debug if $.debug (cont) Scoping ;
            }
            # =item
            # First-level list item
            # =itemN
            # Nth-level list item
            when 'item' {
                $.gen-item($ast, $parify)
            }
            # =defn
            # Definition of a term
            when 'defn' {
                $.gen-defn($ast)
            }
            # =numhead
            # First-level numbered heading
            # =numheadN
            # Nth-level numbered heading
            # heading numeration is fixed when TOC is generated and all headers are known
            when 'numhead' {
                $.gen-headish( $ast, $parify, :template<numhead>, :numerate)
            }
            # =numitem
            # First-level numbered list item
            # =numitemN
            # Nth-level numbered list item
            when 'numitem' {

            }
            # =numdefn
            when 'numdefn' {

            }
            # =place block, mostly mimics P<>, but allows for TOC and caption
            when 'place' {
                 $.gen-place($ast);
            }
            # =rakudoc
            # No "ambient" blocks inside
            when 'rakudoc' | 'pod' {
                $!scoped-data.start-scope(:starter($_));
                $!scoped-data.last-title( $!current.source-data<rakudoc-title> );
                say $!scoped-data.debug if $.debug (cont) Scoping;
                $.gen-rakudoc($ast, $parify);
                $!scoped-data.end-scope;
                say $!scoped-data.debug if $.debug (cont) Scoping ;
            }
            # =pod
            # Legacy version of rakudoc
#           when 'pod' { '' } # when rakudoc differs from pod
            # =section
            # Defines a section
            when 'section' {
                my $last-title = $!scoped-data.last-title;
                $!scoped-data.start-scope( :starter($_) );
                $!scoped-data.last-title( $last-title );
                say $!scoped-data.debug if $.debug (cont) Scoping ;
                $.gen-section($ast, $parify);
                $!scoped-data.end-scope;
                say $!scoped-data.debug if $.debug (cont) Scoping ;
            }
            # =table
            # Visual or procedural table
            when 'table' { $.gen-table($ast) }
            # RESERVED
            # Semantic blocks (SYNOPSIS, TITLE, etc.)
            when all($_.uniprops) ~~ / Lu / {
                # in RakuDoc v2 a Semantic block must have all uppercase letters
                $!scoped-data.start-scope( :starter($_) );
                $!scoped-data.last-title( $_ );
                say $!scoped-data.debug if $.debug (cont) Scoping ;
                $.gen-semantics($ast, $parify);
                $!scoped-data.end-scope;
                say $!scoped-data.debug if $.debug (cont) Scoping ;
            }
            # CustomName
            # User-defined block
            when any($_.uniprops) ~~ / Lu / and any($_.uniprops) ~~ / Ll / {
                # in RakuDoc v2 a Semantic block must have mix of uppercase and lowercase letters
                $!scoped-data.start-scope( :starter($_) );
                $!scoped-data.last-title( $_ );
                say $!scoped-data.debug if $.debug (cont) Scoping ;
                $.gen-custom($ast, $parify);
                $!scoped-data.end-scope;
                say $!scoped-data.debug if $.debug (cont) Scoping ;
            }
            default { $.gen-unknown-builtin($ast) }
        }
    }
    # Raku data section
    multi method handle(RakuAST::Doc::DeclaratorTarget:D $ast) {
        #ignore declarator block
    }
    multi method handle(RakuAST::Doc::Markup:D $ast) {
        my $letter = $ast.letter;
        if ($!scoped-data.verbatim(:called-by) eq 'code') and !%*ALLOW{ $letter } {
            $*prs.body ~= $ast.DEPARSE;
            return
        }
        say "Doc::Markup letter: $letter" if $.debug (cont) MarkUp;
        my %config;
        my %scoped = $!scoped-data.config;
        %scoped{ $letter }.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        # for X<> and to help with warnings
        my $place = $!scoped-data.last-title;
        my $context = $!scoped-data.last-starter;
        given $letter {
            ## Markup codes with only display (format codes), no meta data allowed
            ## meta data via Config is allowed
            ## E is not format code, but we can ignore display possibility
            # TODO add :allow to C & V
            when any( <B C H I J K R S T U V O E> ) {
                my $contents = self.markup-contents($ast);
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
                my $id = self.name-id($ast.Str);
                my $contents = self.markup-contents($ast);
                my $retTarget = $id;
                my $fnNumber = PCell.new( :id("fn_num_$id"), :$!register);
                my $fnTarget = "fn_target_$id";
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
                my $term = self.markup-contents($ast).Str;
                my Bool $error = False;
                my $error-text = '';
                # check to see if there is a text to over-ride automatic failure message
                if $term ~~ / ^ (<-[ | ]>+) \| (.+) $ / {
                    $error-text = ~$0;
                    $term = ~$1
                }
                my $contents;
                if $!scoped-data.aliases{ $term }:exists {
                    $contents = $!scoped-data.aliases{ $term }
                }
                else {
                    $error = True;
                    $error-text = $term unless $error-text;
                    $*prs.warnings.push:
                        "unknown alias ｢$term｣"
                        ~ " in block ｢$context｣ with heading ｢$place｣"
                        ~ ( $error-text ?? " over-riden by ｢$error-text｣" !! ''  )
                }
                $*prs.body ~ %!templates<markup-A>( %( :$contents, :$error, :$error-text, %config ) )
            }
            # E< DISPLAY-TEXT |  METADATA = HTML/UNICODE-ENTITIES >
            # Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> )
            # included with format codes

            # F< DISPLAY-TEXT |  METADATA = LATEX-FORM >
            # Formula inline content ( F<ALT|LaTex notation> )
            when 'F' {

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
                            my %definitions = $*prs.definitions;
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
                    %( :$target, :$link-label, :$type, :$extra, %config)
                );
                $*prs.body ~= $rv;
            }
            # P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            # Placement link
            when 'P' {
                # The contents of P<> markup must be a Str.
                my $contents = self.markup-contents($ast).Str;
                my $uri;
                # check to see if there is a text to over-ride automatic failure message
                if $contents ~~ / ^ (<-[ | ]>+) \| (.+) $ / {
                    %config<fallback> = ~$0;
                    $uri = ~$1
                }
                else { $uri = $contents }
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
                    $*prs.warnings.push: "Ignored unparsable definition synonyms ｢{ ~$ast.meta }｣"
                        ~ " in block ｢$context｣ with heading ｢$place｣."
                }
                my $rv = %!templates{"markup-$letter"}(
                    %( :$contents, %config )
                );
                $*prs.inline-defns.append: @terms;
                $*prs.body ~= $rv
            }
            # Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            # Delta note ( Δ<visible text|version; Notification text> )
            when 'Δ' {
                my $contents = self.markup-contents($ast);
                my $meta = RakuDoc::MarkupMeta.parse( $ast.meta, actions => RMActions.new ).made<value>;
                my $rv = %!templates{"markup-$letter"}(
                    %( :$contents, :$meta, %config)
                );
                $*prs.body ~= $rv;
            }
            # M< DISPLAY-TEXT |  METADATA = WHATEVER >
            # Markup extra ( M<display text|functionality;param,sub-type;...>)
            when 'M' {
            }
            # X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            # Index entry ( X<display text|entry,subentry;...>)
            #| Index (from X<> markup)
            #| Hash key => Array of :target, :context, :place
            #| key to be displayed, target is for link, place is description of section
            #| context because X<> in headings treated differently to ordinary text
            when 'X' {
                my $contents = self.markup-contents($ast);
                my $meta = RakuDoc::MarkupMeta.parse( $ast.meta, actions => RMActions.new ).made<value>;
                my $target = self.index-id($ast, :$context, :$contents, :$meta);
                $*prs.index{$contents} = %( :$target, :$place );
                my $rv = %!templates{"markup-$letter"}(
                    %( :$contents, :$meta, :$target, :$place, %config )
                );
                $*prs.body ~= $rv;
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
                $*prs.body ~= $ast.DEPARSE;
                $*prs.warnings.push:
                    "｢$letter｣ is not defined, but is reserved for future use"
                        ~ " in block ｢$context｣ with heading ｢$place｣."
            }
            when (.uniprop ~~ / Lu / and %!templates{ "markup-$letter" }:exists) {
                my $contents = self.markup-contents($ast);
                $*prs.body ~= %!templates{ "markup-$letter" }(
                    %( :$contents, %config )
                );
            }
            when (.uniprop ~~ / Lu /) {
                $*prs.body ~= $ast.DEPARSE;
                $*prs.warnings.push:
                    "｢$letter｣ does not have a template, but could be a custom code"
                        ~ " in block ｢$context｣ with heading ｢$place｣."
            }
            default {
                $*prs.body ~= $ast.DEPARSE;
                $*prs.warnings.push: "｢$letter｣ may not be a markup code"
                        ~ " in block ｢$context｣ with heading ｢$place｣."
            }
        }
    }
    # This block is created by the parser when a text has embedded markup
    # Also ordinary strings in an extended block are coerced into one
    multi method handle(RakuAST::Doc::Paragraph:D $ast) {
        if $!scoped-data.verbatim {
            $ast.atoms.map({ $.handle($_) });
            return
        }
        my %config;
        my %scoped = $!scoped-data.config;
        %config{ .key } = .value for %scoped<para>.pairs;
        my $rem = $.complete-item-list ~ $.complete-defn-list;
        do {
            my ProcessedState $*prs .= new;
            for $ast.atoms { $.handle($_) }
            my PStr $contents = $*prs.body;
            # each para should have a target, generate a SHA if no id given
            my $target = %config<id> // sha1-hex($contents.Str);
            $*prs.body .= new( $rem );
            my $rv = %!templates<para>(
                %( :$contents, :$target, %config)
            );
            # deal with possible inline definitions
            if $*prs.inline-defns.elems {
                for $*prs.inline-defns.list -> $term {
                    $*prs.warnings.push:
                        "Definition ｢$term｣ has been redefined as an inline"
                        ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
                        if $*prs.definitions{ $term }:exists;
                    $*prs.definitions{ $term } = $rv, $target;
                    $!register.add-payload(:payload($rv), :id($term));
                    $!register.add-payload(:payload($target), :id($term ~ '_target'))
                }
                $*prs.inline-defns = ()
            }
            $*prs.body ~= $rv;
            CALLERS::<$*prs> += $*prs;
       }
    }
    multi method handle(RakuAST::Doc::Row:D $ast) {
        self.handle($ast.WHICH.Str)
    }
    multi method handle(Cool:D $ast) {
        self.handle($ast.WHICH.Str)
    }
    # gen-XX methods take an $ast, process the contents, based on a template,
    # and add the string to a structure, typically, not always, to $*prs.body

    #| generic code for next, para, code, input, output blocks
    method gen-paraish( $ast, $template, $parify ) {
        my %config = $ast.resolved-config;
        my %scoped = $!scoped-data.config;
        %scoped{ $template }.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        my %*ALLOW;
        $!scoped-data.start-scope(:starter($template), :verbatim )
            if $template ~~ any(<code input output>);
        if $template eq 'code' {
            %*ALLOW = %config<allow>:exists
                ?? %config<allow>.map({ $_ => True }).hash
                !! {}
        }

        my PStr $contents = $.contents($ast, $parify);
        $*prs.body ~= %!templates{ $template }(
            %( :$contents, %config)
        );
        $!scoped-data.end-scope if $template ~~ any( <code input output> )
    }
    #| handles blocks that are like headings
    method gen-headish($ast, $parify, :$template = 'head', :$numerate = False ) {
        my $contents = $.contents($ast, $parify).strip.trim;
        my $level = $ast.level > 1 ?? $ast.level !! 1;
        $!scoped-data.last-title( $contents );
        my %config = $ast.resolved-config;
        my %scoped = $!scoped-data.config;
        my $scoping = $template eq <head numhead>.any ?? ($template ~ $level) !! $template;
        %scoped{ $scoping }.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        my $target = $.name-id($contents);
        my $id = %config<id>:delete;
        with $id {
            if self.is-target-unique( $_ ) {
                $id = self.register-target( $_ );
            }
            else {
                $*prs.warnings.push: "Attempt to register already existing id ｢$_｣ as new target in heading ｢$contents｣";
            }
        }
        # level is over-ridden if headlevel is set, eg =for head2 :headlevel(3)
        $level = %config<headlevel> if %config<headlevel>:exists;
        $level = 1 if $level < 1;
        # numeration is attached to contents first
        my $numeration = '';
        if $numerate {
            $numeration = PCell( :$!register, :id('num_' ~ $target ) );
            $*prs.head-numbering.push: ['num_' ~ $target, $level ];
        }
        my $caption = %config<caption>:delete;
        $caption = ($template eq <head numhead>.any ?? $contents !! $template) without $caption;
        my $toc = %config<toc>:delete // True;
        # attach numeration to caption and contents separately, allowing template
        # user to add to caption if wanted by changing the template
        $caption = %!templates<toc-numeration>(:$numeration, :$caption) if $numerate;
        $*prs.toc.push(
            { :$caption, :$target, :$level }
        ) if $toc;
        $*prs.body ~= %!templates{ $template }(
            %( :$numeration, :$level, :$target, :$contents, :$toc, :$caption, :$id, %config )
        )
    }
    #| generates a single item and adds it to the item structure
    #| nothing is added to the .body string
    method gen-item($ast, $parify) {
        my $level = $ast.level > 1 ?? $ast.level !! 1;
        my $contents = $.contents($ast, $parify);
        my %config = $ast.resolved-config;
        my %scoped = $!scoped-data.config;
        %scoped{ "item$level" }.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        $*prs.items.push: %!templates<item>(
            %( :$level, :$contents, %config )
        )
    }
    #| generates a single definition and adds it to the defn structure
    #| unlike item, a defn:
    #| - list has a flat hierarchy
    #| - can be created by a markup code
    #| - needs a target for links, and text for popup
    #| - is PCell-stored allowing for defn to be redefined
    #| like items nothing is added to the .body string until next non-defn
    method gen-defn($ast) {
        unless $ast.paragraphs.elems == 2 {
            my $string = $ast.Str;
            $*prs.body ~= $string;
            $*prs.warnings.push:
                "Invalid definition: ｢$string｣"
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
        }
        my $term = $ast.paragraphs[0].Str; # the term may not contain embedded code
        my $target = $.name-id("defn_$term");
        # generate contents from second str/paragraph
        my ProcessedState $*prs .= new;
        $.handle( $ast.paragraphs[1] );
        my $contents = $*prs.body;
        # keep most of state, initialise body
        $*prs.body .= new;
        my %config = $ast.resolved-config;
        my %scoped = $!scoped-data.config;
        %scoped<defn>.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        my $defn-expansion = %!templates<defn>(
            %( :$term, :$target, :$contents, %config )
        );
        $*prs.defns.push: $defn-expansion; # for the defn list to be rendered
        $*prs.warnings.push:
            "Definition ｢$term｣ has been redefined"
            ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
            if $*prs.definitions{ $term }:exists;
        $*prs.definitions{ $term } = $defn-expansion, $target;
        CALLERS::<$*prs> += $*prs;
        # define for previously referenced
        $!register.add-payload(:payload($defn-expansion), :id($term));
        $!register.add-payload(:payload($target), :id($term ~ '_target'))
    }
    method gen-place($ast) {
        my %config = $ast.resolved-config;
        my $uri = %config<uri>:delete;
        my %scoped = $!scoped-data.config;
        %scoped<place>.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        %config<caption> = 'Placement' unless %config<caption>:exists;
        my $caption = %config<caption>;
        my $level = %config<headlevel> // 1;
        $!scoped-data.last-title($caption);
        my $target = $.name-id($caption);
        my $id = '';
        with %config<id> {
            if self.is-target-unique( $_ ) {
                $id = self.register-target( $_ );
            }
            else {
                $*prs.warnings.push: "Attempt to register already existing id ｢$_｣ as new target in heading ｢$caption｣";
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
        my $body = $uri;
        my $contents;
        if $uri ~~ / ^ $<sch> = (\w+) ':' $<body> = (.+) $ / {
            $schema = $/<sch>.Str;
            $body = $/<body>.Str
        }
        given $schema {
            when 'toc' {
                # TODO add the constraints for toc: in RakuDoc v2.
                $contents = PCell.new( :$!register, :id<toc-schema> );
                $keep-format = True;
            }
            when 'index' {
                $contents = PCell.new( :$!register, :id<index-schema> );
                $keep-format = True;
            }
            when 'semantic' {
                $keep-format = True;
                $contents =  PCell.new( :$!register, :id( "semantic-schema_$body" ) );
            }
            when 'http' | 'https' {
                my LibCurl::Easy $curl;
                $curl .= new(:URL($uri), :followlocation, :failonerror );
                try {
                    $curl.perform;
                    $contents = $curl.perform.content;
                    CATCH {
                        default {
                            my $error = "Link ｢$uri｣ caused LibCurl Exception, response code ｢{ $curl.response-code }｣ with error ｢{ $curl.error }｣";
                            $contents = %config<fallback> // $error;
                            $*prs.warnings.push: $error
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
                    $*prs.warnings.push: $error
                }
            }
            when 'defn' {
                # get definition from Processed state, or make a PCell
                my %definitions = $*prs.definitions;
                $contents = $body;
                if %definitions{ $body }:exists {
                    %config<defn-expansion> = %definitions{ $body }[0];
                    %config<defn-target> = %definitions{ $body }[1]
                }
                else {
                    %config<defn-expansion> = PCell.new( :$!register, :id( $body ));
                    %config<defn-target> = PCell.new( :$!register, :id( $body ~ '_target' ));
                }
            }
            default {
                    $contents = %config<fallback> // "See $uri";
                    $*prs.warnings.push:
                        "The schema ｢$schema｣ is not implemented. Full link was ｢$uri｣"
                        ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
            }
        }
        %config<html> = so $contents ~~ / '<html' .+ '</html>'/;
        $contents = ~$/ if %config<html>;
        # strip off any chars before & after the <html> container if there is one

        $*prs.body ~= %!templates{ $template }(
            %( :$contents, :$keep-format, :$schema, %config )
        )
    }
    method gen-rakudoc($ast, $parify) {
        my %config = $ast.resolved-config;
        $!current.source-data<rakudoc-config> = %config;
        my $contents = self.contents($ast, $parify);
        # render any tailing lists
        $contents ~= $.complete-item-list;
        $contents ~= $.complete-defn-list;
        $*prs.body ~= %!templates<rakudoc>( %( :$contents, %config ) );
    }
    method gen-section($ast, $parify) {
        my %config = $ast.resolved-config;
        my $contents = $.contents($ast, $parify);
        # render any tailing lists
        $contents ~= $.complete-item-list;
        $contents ~= $.complete-defn-list;
        $*prs.body ~= %!templates<section>( %( :$contents, %config ) )
    }
    method gen-table($ast) {
        $*prs.body ~= ''
    }
    method gen-unknown-builtin($ast) {
        my %config = $ast.resolved-config;
        my $contents = $.contents($ast, False);
        if $ast.type ~~ any(<
                cell code input output comment head numhead defn item numitem nested para
                rakudoc section pod table formula
            >) { # a known built-in, but to get here the block is unimplemented
            $*prs.warnings.push:
                '｢' ~ $ast.type ~ '｣'
                ~ 'is a valid, but unimplemented builtin block'
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
        }
        else { # not known so create another warning
            $*prs.warnings.push:
                '｢' ~ $ast.type ~ '｣' ~ 'is not a valid builtin block, is it a misspelt Custom block?'
                ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
        } # TODO make like unknown Custom
        $*prs.body ~= %!templates<unknown>( %( :block-type($ast.type), :$contents, %config ) )
    }
    #| All Semantic blocks are processed into strings, and the contents added to the semantic structure
    #| If :hidden is True, then the string is not added to .body
    #| TITLE SUBTITLE NAME are by default :hidden and added to $*prs separately
    #| All other SEMANTIC blocks are :!hidden by default
    method gen-semantics($ast, $parify) {
        my $block-name = $ast.type;
        my %config = $ast.resolved-config;
        my %scoped = $!scoped-data.config;
        %scoped{ $block-name }.pairs.map({
            %config{ .key } = .value unless %config{ .key }:exists
        });
        # treat all semantic blocks as a heading level 1 unless otherwise specified
        my $caption = %config<caption> // $block-name;
        my $level = %config<headlevel> // 1;
        my $hidden;
        my $contents = $.contents($ast, $parify).trim;
        $!scoped-data.last-title( $block-name );
        my $rv;
        given $ast.type {
            when 'TITLE' {
                $hidden = %config<hidden>.so // True; # hide by default
                $!current.title = $contents;
                # allows for TITLE to have its own template
                if %!templates<TITLE>:exists {
                    $rv = %!templates<TITLE>( %( :$contents, %config ) )
                }
                else {
                    $rv = $contents
                }
            }
            when 'SUBTITLE' {
                $hidden = %config<hidden>.so // True;
                $!current.subtitle = $contents;
                if %!templates<SUBTITLE>:exists {
                    $rv = %!templates<SUBTITLE>( %( :$contents, %config ) )
                }
                else {
                    $rv = $contents
                }
            }
            when 'NAME' {
                $hidden = %config<hidden>.so // True;
                # name probably should not be anything but a bare string
                $!current.name = $rv = $contents ~ '.' ~ $!output-format;
            }
            default {
                $hidden = %config<hidden>.so // False; # other SEMANTIC by default rendered in place
                my $template = %!templates{ $block-name }:exists ?? $block-name !! 'head';
                my $target = $.name-id($block-name);
                my $id = '';
                with %config<id> {
                    if self.is-target-unique( $_ ) {
                        self.register-target( $_ );
                        $id = $_
                    }
                    else {
                        $*prs.warnings.push:
                            "Attempt to register already existing id ｢$_｣ as new target in ｢$block-name｣"
                            ~ " in block ｢{ $!scoped-data.last-starter }｣ with heading ｢{ $!scoped-data.last-title }｣."
                    }
                }
                $rv = %!templates{$template}(
                    %( :$level, :$target, :$contents, :$id, %config )
                );
                $*prs.toc.push(  %( :$caption, :$target, :$level ) ) unless $hidden;
            }
        }
        $*prs.semantics{ $block-name } = [] unless $*prs.semantics{ $block-name }:exists;
        $*prs.semantics{ $block-name }.push: $rv;
        $*prs.body ~= $rv unless $hidden;
    }
    method gen-custom($ast, $parify) {
        # Custom blocks are defined by their spelling
        my $template = $ast.type;
        # A customiser must provide a template with the same name & spelling as the block name
        if %!templates{ $template }:exists {
            $.gen-headish( $ast, $parify, :$template)
        }
        else {
            # by spec, the name of an unrecognised Custom is treated like =head1
            # the contents are treated like =code
            $.gen-headish( RakuAST::Doc::Block.new(
                :type<head>,
                :paragraphs( $template, ),
                :config( $ast.resolved-config ),
                :abbreviated
            ), False );
            $.gen-paraish( RakuAST::Doc::Block.new(
                :type<code>,
                :paragraphs( $ast.paragraphs ),
                :config( $ast.resolved-config ),
                :for( $ast.for ),
                :abbreviated( $ast.abbreviated )
            ), 'code', $parify );
            $*prs.warnings.push: "Undefined custom block ｢$template｣ has been rendered as as code"
        }
    }
    # directive type methods
    method manage-config($ast) {
        my %options = $ast.resolved-config;
        my $name = $ast.paragraphs[0].Str;
        $name = $name ~ '1' if $name ~~ / ^ 'item' $ | ^ 'head' $ /;
        $!scoped-data.config( { $name => %options } );
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
    #| completes the index by rendering each key
    #| triggers the 'index-schema' id, which may be placed by a P<>
    method complete-index {
        my @index-list = gather for $!current.index.sort( *.key )>>.kv -> ( $key, @index-entries ) {
            take %!templates<index-item>( %( :@index-entries , ) )
        }
        my $payload = %!templates<index>( %(:@index-list, :caption( $!current.source-data<index-caption> ) ));
        $!register.add-payload( :$payload, :id('index-schema') );
    }
    #| renders the toc and triggers the 'toc-schema' id for P<>
    method complete-toc {
        my @toc-list = gather for $!current.toc -> $toc-entry {
            take %!templates<toc-item>( %( :$toc-entry , ) )
        }
        $!register.add-payload( :payload(
            %!templates<toc>( %(:@toc-list, :caption( $!current.source-data<toc-caption>) )) ),
            :id('toc-schema')
        )
    }
    #| finalises all the heading numerations
    method complete-heading-numerations() {
        for $*prs.head-numbering {
            my Numeration $heads .= new;
            $heads.set(1,1)
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
        return '' unless $*prs.defns; # do nothing of no accumulated items
        my $rv = %!templates<defn-list>(
            %( :defn-list($*prs.defns), )
        );
        $*prs.defns = ();
        $rv
    }
    # helper methods
    method is-target-unique($targ --> Bool) {
        !$!current.targets{$targ}
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
        my $text = $*prs.body;
        $*prs.body .= new;
        CALLERS::<$*prs> += $*prs;
        $text
    }
    #| similar to contents but expects atoms structure
    method markup-contents($ast) {
        my ProcessedState $*prs .= new;
        for $ast.atoms { $.handle($_) }
        my $text = $*prs.body;
        $*prs.body .= new;
        CALLERS::<$*prs> += $*prs;
        $text
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

    #| name-id takes an ast
    #| returns a unique Str to be used as an anchor / target
    #| Used by any name (block) that is placed in the ToC
    #| Also used for the main anchor in the text for a footnote
    #| Not called if an :id is specified in the source
    #| This method should be sub-classed by Renderers for different outputs
    #| renderers can use method is-target-unique to test for uniqueness
    method name-id($ast --> Str) {
        my $target = $ast.Str.trim.subst(/ \s /, '_', :g);
        return self.register-target($target) if $.is-target-unique($target);
        my @rejects = $target, ;
        # if plain target is rejected, then start adding a suffix
        $target ~= '_0';
        $target += 1 while $target ~~ any(@rejects);
        self.register-target($target);
    }

    #| Like name-id, index-id returns a unique Str to be used as a target
    #| Target should be unique
    #| Should be sub-classed by Renderers
    method index-id($ast, :$context, :$contents, :$meta ) {
        my $target = 'index-entry-' ~ $contents.Str.trim.subst(/ \s /, '_', :g );
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
        $ast.Str.trim.subst(/ \s /, '_', :g);
    }

    #| utility for test templates
    our &express-params is export = -> %h, $t, $c {
        my PStr $rv .= new("<{ $c }>\n");
        for %h.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ ( $v // 'UNINITIALISED' ) ~  "｣\n" }
        $rv ~= "</{ $c }>\n"
    }

    #| returns hash of test templates
    multi method test-text-templates {
        %(
            #| special key to name template set
            _name => -> %, $ {
                'test templates'
            },
            #| renders =code block
            code => -> %prm, $tmpl { express-params( %prm, $tmpl, 'code' ) },
            #| renders =input block
            input => -> %prm, $tmpl { express-params( %prm, $tmpl, 'input' ) },
            #| renders =output block
            output => -> %prm, $tmpl { express-params( %prm, $tmpl, 'output' ) },
            #| renders =comment block
            comment => -> %prm, $tmpl { express-params( %prm, $tmpl, 'comment' ) },
            #| renders =head block
            head => -> %prm, $tmpl { express-params( %prm, $tmpl, 'head' ) },
            #| renders =numhead block
            numhead => -> %prm, $tmpl { express-params( %prm, $tmpl, 'numhead' ) },
            #| renders the numeration part for a toc
            toc-numeration => -> %prm, %tmpl { express-params( %prm, %tmpl, 'toc-num' )},
            #| renders =defn block
            defn => -> %prm, $tmpl { express-params( %prm, $tmpl, 'defn' ) },
            #| renders =item block
            item => -> %prm, $tmpl { express-params( %prm, $tmpl, 'item' ) },
            #| renders =numitem block
            numitem => -> %prm, $tmpl { express-params( %prm, $tmpl, 'numitem' ) },
            #| renders =nested block
            nested => -> %prm, $tmpl { express-params( %prm, $tmpl, 'nested' ) },
            #| renders =para block
            para => -> %prm, $tmpl { express-params( %prm, $tmpl, 'para' ) },
            #| renders =place block
            place => -> %prm, $tmpl { express-params( %prm, $tmpl, 'place' ) },
            #| renders =rakudoc block
            rakudoc => -> %prm, $tmpl { express-params( %prm, $tmpl, 'rakudoc' ) },
            #| renders =section block
            section => -> %prm, $tmpl { express-params( %prm, $tmpl, 'section' ) },
            #| renders =pod block
            pod => -> %prm, $tmpl { express-params( %prm, $tmpl, 'pod' ) },
            #| renders =table block
            table => -> %prm, $tmpl { express-params( %prm, $tmpl, 'table' ) },
            #| renders =custom block
            custom => -> %prm, $tmpl { express-params( %prm, $tmpl, 'custom' ) },
            #| renders any unknown block minimally
            unknown => -> %prm, $tmpl { express-params( %prm, $tmpl, 'unknown' ) },
            #| special template to encapsulate all the output to save to a file
            final => -> %prm, $tmpl {
                %prm<processed>.title ~ "\n"
                ~ %prm<processed>.subtitle ~ "\n"
                ~ %prm<rendered-toc> ~ "\n"
                ~ %prm<rendered-index> ~ "\n"
                ~ %prm<processed>.body.Str ~ "\n"
                ~ $tmpl('footnotes', {
                    footnotes => %prm<processed>.footnotes,
                }) ~ "\n"
                ~ $tmpl('warnings', {
                    warnings => %prm<processed>.warnings,
                }) ~ "\n"
                ~ 'Rendered from ｢' ~ %prm<processed>.source-data<name> ~ "｣\n"
                ~ 'at ' ~ %prm<processed>.modified ~ "\n"
                ~ 'into ｢' ~ %prm<processed>.name ~ "｣\n"
            },
            #| renders a single item in the toc
            toc-item => -> %prm, $tmpl { express-params( %prm, $tmpl, 'toc' ) },
            #| special template to render the toc list
            toc => -> %prm, $tmpl {
                my $toc-list = %prm<toc-list>:delete;
                $toc-list = .elems ?? .join !! "No items\n" with $toc-list;
                my $rv = "<toc>\n";
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ ( $v // 'UNINITIALISED' ) ~  "｣\n" }
				$rv ~= "items:" ~ $toc-list ~"</toc>\n"
            },
            #| renders a single item in the index
            index-item => -> %prm, $tmpl { express-params( %prm, $tmpl, 'index' ) },
            #| special template to render the index data structure
            index => -> %prm, $tmpl {
                my $ind-list = %prm<index-list>:delete;
                $ind-list = .elems ?? .join !! "No items\n" with $ind-list;
                my $rv = "\n<index>\n";
				for %prm.sort(*.key)>>.kv -> ($k, $v) { $rv ~= $k ~ ': ｢' ~ ( $v // 'UNINITIALISED' ) ~  "｣\n" }
				$rv ~= "items:" ~ $ind-list ~"</index>\n"
            },
            #| special template to render the footnotes data structure
            footnotes => -> %prm, $tmpl {
                if %prm<footnotes>.elems {
                    my $n = 1;
                    "<footnote-list>\n"
                    ~ [~] %prm<footnotes>.map({
                        "<footnote>{ $n++ }: $_\</footnote>\n"
                    })
                    ~ "</footnote-list>\n"
                }
                else {
                    ''
                }
            },
            #| special template to render an item list data structure
            item-list => -> %prm, $tmpl {
                "<item-list>\n" ~ %prm<item-list>.join ~ "</item-list>\n"
            },
            #| special template to render an item list data structure
            defn-list => -> %prm, $tmpl {
                "<defn-list>\n" ~ %prm<defn-list>.join ~ "</defn-list>\n"
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
			markup-B => -> %prm, $tmpl { express-params( %prm, $tmpl, 'basis' ) },
            #| C< DISPLAY-TEXT >
            #| Code (typically rendered fixed-width)
			markup-C => -> %prm, $tmpl { express-params( %prm, $tmpl, 'code' ) },
            #| H< DISPLAY-TEXT >
            #| High text (typically rendered superscript)
			markup-H => -> %prm, $tmpl { express-params( %prm, $tmpl, 'high' ) },
            #| I< DISPLAY-TEXT >
            #| Important (typically rendered in italics)
			markup-I => -> %prm, $tmpl { express-params( %prm, $tmpl, 'important' ) },
            #| J< DISPLAY-TEXT >
            #| Junior text (typically rendered subscript)
			markup-J => -> %prm, $tmpl { express-params( %prm, $tmpl, 'junior' ) },
            #| K< DISPLAY-TEXT >
            #| Keyboard input (typically rendered fixed-width)
			markup-K => -> %prm, $tmpl { express-params( %prm, $tmpl, 'keyboard' ) },
            #| N< DISPLAY-TEXT >
            #| Note (not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.))
            #| This is the template for the in-text part, which should have a Number, link, and return anchor
			markup-N => -> %prm, $tmpl { express-params( %prm, $tmpl, 'note' ) },
            #| O< DISPLAY-TEXT >
            #| Overstrike or strikethrough
			markup-O => -> %prm, $tmpl { express-params( %prm, $tmpl, 'overstrike' ) },
            #| R< DISPLAY-TEXT >
            #| Replaceable component or metasyntax
			markup-R => -> %prm, $tmpl { express-params( %prm, $tmpl, 'replaceable' ) },
            #| S< DISPLAY-TEXT >
            #| Space characters to be preserved
			markup-S => -> %prm, $tmpl { express-params( %prm, $tmpl, 'space' ) },
            #| T< DISPLAY-TEXT >
            #| Terminal output (typically rendered fixed-width)
			markup-T => -> %prm, $tmpl { express-params( %prm, $tmpl, 'terminal' ) },
            #| U< DISPLAY-TEXT >
            #| Unusual (typically rendered with underlining)
			markup-U => -> %prm, $tmpl { express-params( %prm, $tmpl, 'unusual' ) },
            #| V< DISPLAY-TEXT >
            #| Verbatim (internal markup instructions ignored)
			markup-V => -> %prm, $tmpl { express-params( %prm, $tmpl, 'verbatim' ) },

            ##| Markup codes, optional display and meta data

            #| A< DISPLAY-TEXT |  METADATA = ALIAS-NAME >
            #| Alias to be replaced by contents of specified V<=alias> directive
			markup-A => -> %prm, $tmpl { express-params( %prm, $tmpl, 'alias' ) },
            #| E< DISPLAY-TEXT |  METADATA = HTML/UNICODE-ENTITIES >
            #| Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> )
			markup-E => -> %prm, $tmpl { express-params( %prm, $tmpl, 'entity' ) },
            #| F< DISPLAY-TEXT |  METADATA = LATEX-FORM >
            #| Formula inline content ( F<ALT|LaTex notation> )
			markup-F => -> %prm, $tmpl { express-params( %prm, $tmpl, 'formula' ) },
            #| L< DISPLAY-TEXT |  METADATA = TARGET-URI >
            #| Link ( L<display text|destination URI> )
			markup-L => -> %prm, $tmpl { express-params( %prm, $tmpl, 'link' ) },
            #| P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            #| Placement link
			markup-P => -> %prm, $tmpl { express-params( %prm, $tmpl, 'placement' ) },

            ##| Markup codes, mandatory display and meta data
            #| D< DISPLAY-TEXT |  METADATA = SYNONYMS >
            #| Definition inline ( D<term being defined|synonym1; synonym2> )
			markup-D => -> %prm, $tmpl { express-params( %prm, $tmpl, 'inline-defn' ) },
            #| Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            #| Delta note ( Δ<visible text|version; Notification text> )
            markup-Δ => -> %prm, $tmpl { express-params( %prm, $tmpl, 'delta' ) },
            #| M< DISPLAY-TEXT |  METADATA = WHATEVER >
            #| Markup extra ( M<display text|functionality;param,sub-type;...>)
			markup-M => -> %prm, $tmpl { express-params( %prm, $tmpl, 'markup' ) },
            #| X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            #| Index entry ( X<display text|entry,subentry;...>)
			markup-X => -> %prm, $tmpl { express-params( %prm, $tmpl, 'index' ) },
            #| Unknown markup, render minimally
            markup-unknown => -> %prm, $tmpl { express-params( %prm, $tmpl, 'unknown' ) },
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
            code => -> %prm, $tmpl { express-params( %prm, $tmpl, 'code' ) },
            #| renders =input block
            input => -> %prm, $tmpl { express-params( %prm, $tmpl, 'input' ) },
            #| renders =output block
            output => -> %prm, $tmpl { express-params( %prm, $tmpl, 'output' ) },
            #| renders =comment block
            comment => -> %prm, $tmpl { express-params( %prm, $tmpl, 'comment' ) },
            #| renders =head block
            head => -> %prm, $tmpl {
                my $indent = %prm<level> > 2 ?? 4 !! (%prm<level> - 1) * 2;
                qq:to/HEAD/
                { %prm<contents>.Str.indent($indent) }
                { ('-' x %prm<contents>.Str.chars).indent($indent) }
                HEAD
            },
            #| renders =numhead block
            numhead => -> %prm, $tmpl { express-params( %prm, $tmpl, 'numhead' ) },
            #| renders the numeration part for a toc
            toc-numeration => -> %prm, %tmpl { express-params( %prm, %tmpl, 'toc-num' )},
            #| renders =defn block
            defn => -> %prm, $tmpl { express-params( %prm, $tmpl, 'defn' ) },
            #| renders =item block
            item => -> %prm, $tmpl { express-params( %prm, $tmpl, 'item' ) },
            #| renders =numitem block
            numitem => -> %prm, $tmpl { express-params( %prm, $tmpl, 'numitem' ) },
            #| renders =nested block
            nested => -> %prm, $tmpl { express-params( %prm, $tmpl, 'nested' ) },
            #| renders =para block
            para => -> %prm, $tmpl { express-params( %prm, $tmpl, 'para' ) },
            #| renders =place block
            place => -> %prm, $tmpl { express-params( %prm, $tmpl, 'place' ) },
            #| renders =rakudoc block
            rakudoc => -> %prm, $tmpl { express-params( %prm, $tmpl, 'rakudoc' ) },
            #| renders =section block
            section => -> %prm, $tmpl { express-params( %prm, $tmpl, 'section' ) },
            #| renders =pod block
            pod => -> %prm, $tmpl { express-params( %prm, $tmpl, 'pod' ) },
            #| renders =table block
            table => -> %prm, $tmpl { express-params( %prm, $tmpl, 'table' ) },
            #| renders =custom block
            custom => -> %prm, $tmpl { express-params( %prm, $tmpl, 'custom' ) },
            #| renders any unknown block minimally
            unknown => -> %prm, $tmpl { express-params( %prm, $tmpl, 'unknown' ) },
            #| special template to encapsulate all the output to save to a file
            final => -> %prm, $tmpl { express-params( %prm, $tmpl, 'final' ) },
            #| renders a single item in the index
            toc-item => -> %prm, $tmpl { express-params( %prm, $tmpl, 'toc' ) },
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
            #| renders a single item in the index
            index-item => -> %prm, $tmpl { express-params( %prm, $tmpl, 'index' ) },
            #| special template to render an item list data structure
            defn-list => -> %prm, $tmpl {
                "<defn-list>\n" ~ %prm<defn-list>.join ~ "</defn-list>\n"
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
			markup-B => -> %prm, $tmpl { express-params( %prm, $tmpl, 'basis' ) },
            #| C< DISPLAY-TEXT >
            #| Code (typically rendered fixed-width)
			markup-C => -> %prm, $tmpl { express-params( %prm, $tmpl, 'code' ) },
            #| H< DISPLAY-TEXT >
            #| High text (typically rendered superscript)
			markup-H => -> %prm, $tmpl { express-params( %prm, $tmpl, 'high' ) },
            #| I< DISPLAY-TEXT >
            #| Important (typically rendered in italics)
			markup-I => -> %prm, $tmpl { express-params( %prm, $tmpl, 'important' ) },
            #| J< DISPLAY-TEXT >
            #| Junior text (typically rendered subscript)
			markup-J => -> %prm, $tmpl { express-params( %prm, $tmpl, 'junior' ) },
            #| K< DISPLAY-TEXT >
            #| Keyboard input (typically rendered fixed-width)
			markup-K => -> %prm, $tmpl { express-params( %prm, $tmpl, 'keyboard' ) },
            #| N< DISPLAY-TEXT >
            #| Note (not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.))
			markup-N => -> %prm, $tmpl { express-params( %prm, $tmpl, 'note' ) },
            #| O< DISPLAY-TEXT >
            #| Overstrike or strikethrough
			markup-O => -> %prm, $tmpl { express-params( %prm, $tmpl, 'overstrike' ) },
            #| R< DISPLAY-TEXT >
            #| Replaceable component or metasyntax
			markup-R => -> %prm, $tmpl { express-params( %prm, $tmpl, 'replaceable' ) },
            #| S< DISPLAY-TEXT >
            #| Space characters to be preserved
			markup-S => -> %prm, $tmpl { express-params( %prm, $tmpl, 'space' ) },
            #| T< DISPLAY-TEXT >
            #| Terminal output (typically rendered fixed-width)
			markup-T => -> %prm, $tmpl { express-params( %prm, $tmpl, 'terminal' ) },
            #| U< DISPLAY-TEXT >
            #| Unusual (typically rendered with underlining)
			markup-U => -> %prm, $tmpl { express-params( %prm, $tmpl, 'unusual' ) },
            #| V< DISPLAY-TEXT >
            #| Verbatim (internal markup instructions ignored)
			markup-V => -> %prm, $tmpl { express-params( %prm, $tmpl, 'verbatim' ) },

            ##| Markup codes, optional display and meta data

            #| A< DISPLAY-TEXT |  METADATA = ALIAS-NAME >
            #| Alias to be replaced by contents of specified V<=alias> directive
			markup-A => -> %prm, $tmpl { express-params( %prm, $tmpl, 'alias' ) },
            #| E< DISPLAY-TEXT |  METADATA = HTML/UNICODE-ENTITIES >
            #| Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> )
			markup-E => -> %prm, $tmpl { express-params( %prm, $tmpl, 'entity' ) },
            #| F< DISPLAY-TEXT |  METADATA = LATEX-FORM >
            #| Formula inline content ( F<ALT|LaTex notation> )
			markup-F => -> %prm, $tmpl { express-params( %prm, $tmpl, 'formula' ) },
            #| L< DISPLAY-TEXT |  METADATA = TARGET-URI >
            #| Link ( L<display text|destination URI> )
			markup-L => -> %prm, $tmpl { express-params( %prm, $tmpl, 'link' ) },
            #| P< DISPLAY-TEXT |  METADATA = REPLACEMENT-URI >
            #| Placement link
			markup-P => -> %prm, $tmpl { express-params( %prm, $tmpl, 'placement' ) },

            ##| Markup codes, mandatory display and meta data
            #| D< DISPLAY-TEXT |  METADATA = SYNONYMS >
            #| Definition inline ( D<term being defined|synonym1; synonym2> )
			markup-D => -> %prm, $tmpl { express-params( %prm, $tmpl, 'definition' ) },
            #| Δ< DISPLAY-TEXT |  METADATA = VERSION-ETC >
            #| Delta note ( Δ<visible text|version; Notification text> )
            markup-Δ => -> %prm, $tmpl { express-params( %prm, $tmpl, 'delta' ) },
            #| M< DISPLAY-TEXT |  METADATA = WHATEVER >
            #| Markup extra ( M<display text|functionality;param,sub-type;...>)
			markup-M => -> %prm, $tmpl { express-params( %prm, $tmpl, 'markup' ) },
            #| X< DISPLAY-TEXT |  METADATA = INDEX-ENTRY >
            #| Index entry ( X<display text|entry,subentry;...>)
			markup-X => -> %prm, $tmpl { express-params( %prm, $tmpl, 'index' ) },
            #| Unknown markup, render minimally
            markup-unknown => -> %prm, $tmpl { express-params( %prm, $tmpl, 'unknown' ) },
        ); # END OF TEMPLATES (this comment is to simplify documentation generation)
    }
    #| returns hash of test helper callables
    multi method text-helpers {
        %(
            add-to-toc => -> %h {
                %h<state>.toc.push:
                    { :caption(%h<caption>.Str), :target(%h<target>), :level(%h<level>) },
            },
            add-to-index => -> %h {
                %h<state>.index.push:
                    { :contents(%h<contents>.Str), :target(%h<target>), :place(%h<place>) },
            },
            add-to-footnotes => -> %h {
                %h<state>.footnotes.push:
                    { :retTarget(%h<retTarget>), :fnTarget(%h<fnTarget>), :fnNumber(%h<fnNumber>) },
            }
        )
    }
}
