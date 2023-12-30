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

    submethod BUILD(:$!output-format = 'text', :$test = False ) {
        %!templates = $test ?? test-text-temps() !! text-temps();
    }

    method render($ast, :%source-data --> RakuDoc::Processed) {
        $!current .= new(:%source-data);
        my ProcessedState @prs = $ast.rakudoc.map({ $.handle($_) });
        $!current += $_ for @prs;
        # statements now created
        $.current;
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
    multi method handle(RakuAST::Doc::Block:D $ast) {
        # When a built in block, other than =item, is started,
        # there may be a list of items or defns, which need to be
        # completed and rendered
        $*prs.body ~= $.complete-item-list() unless $ast.type and $ast.type eq 'item';
        $*prs.body ~= $.complete-defn-list() unless $ast.type and $ast.type eq 'defn';

        # Not all Blocks create a new scope. Some change the current scope data
        given $ast.type {
            when 'alias' { $.gen-alias($ast) }
            when 'code' { $.gen-code($ast) }
            when 'comment' { '' }
            # do nothing
            when 'config' { $.manage-config($ast); }
            when 'head' {
                $!scoped-data.start-scope(:callee($_));
                $.gen-head($ast);
                $!scoped-data.end-scope
            }
            when 'implicit-code' { $.gen-code($ast) }
            when 'item' { $.gen-item($ast) }
            when 'rakudoc' | 'pod' {
                $!scoped-data.start-scope(:callee($_));
                $.gen-rakudoc($ast);
                $!scoped-data.end-scope}
            #            when 'pod' { '' } # when rakudoc differs from pod
            when 'section' {
                $!scoped-data.start-scope(:callee($_));
                $.gen-section($ast);
                $!scoped-data.end-scope
            }
            when 'table' { $.gen-table($ast) }
            when all($_.uniprops) ~~ / Lu / {
                # in RakuDoc v2 a Semantic block must have all uppercase letters
                $!scoped-data.start-scope(:callee($_));
                $.gen-semantics($ast);
                $!scoped-data.end-scope
            }
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
    multi method handle(RakuAST::Doc::DeclaratorTarget:D $ast) {
        #ignore declarator blocks
    }
    multi method handle(RakuAST::Doc::Markup:D $ast) {
        $*blocks{'MARKUP / ' ~ $ast.letter}++
    }
    multi method handle(RakuAST::Doc::Paragraph:D $ast) {
        my ProcessedState @prs = $ast.atoms.map({ $.handle($_) });
        $*prs += $_ for @prs;
        $*prs
    }
    multi method handle(RakuAST::Doc::Row:D $ast) {
        self.handle('ROW')
    }
    multi method handle(Cool:D $ast) {
        self.handle($ast.WHICH.Str)
    }
    # gen-XX methods take an $ast and adds a string to $*prs.body
    # based on a template
    method gen-alias($ast) {
        ''
    }
    method gen-code($ast) {
        ''
    }
    method gen-head($ast) {
        my $level = $ast.level > 1 ?? $ast.level !! 1;
        my $target = name-id($ast);
        my @rejects;
        until $.is-target-unique($target) {
            @rejects.push($target);
            $target = name-id($ast, :@rejects)
        }
        $.register-target($target);
        my $contents = $.contents($ast);
        my %config = get-meta($ast);
        my %scoped-head = $!scoped-data.config;
        %config{ .key } = .value for %scoped-head{"head$level"}.pairs;
        $*prs.body ~= %!templates<head>(
            %( :$level, :$target, :$contents, %config)
        )
    }
    method gen-item($ast) {
        ''
    }
    method gen-rakudoc($ast) {
        my %config = get-meta($ast);
        $!current.source-data<rakudoc-config> = %config;
        my $contents = $.contents($ast);
        $*prs.body ~= %!templates<rakudoc>( %( :$contents, %config ) )
    }
    method gen-section($ast) {
        my %config = get-meta($ast);
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
        my %options = get-meta($ast);
        my $name = $ast.paragraphs[0].Str;
        $name = $name ~ '1' if $name ~~ / ^ 'item' $ | ^ 'head' $ /;
        $!scoped-data.config( { $name => %options } );
    }
    method manage-aliases($ast) {
        my %options = get-meta($ast);
        my $name = $ast.paragraphs[0].Str;
        $!scoped-data.aliases( %options );
    }
    method manage-definitions($ast) {
        my %options = get-meta($ast);
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
}

#| Strip out formatting code and links from a Title or Link
multi sub recurse-until-str(Str:D $s) is export {
    $s
}
multi sub recurse-until-str(RakuAST::Doc::Block $n) is export {
    $n.paragraphs>>.&recurse-until-str().join
}
#| name-id takes an ast and an optional array of rejects
#| returns a Str to be used as an internal target
#| renderers should sub-class name-id
sub name-id($ast, :@rejects  --> Str) {
    my $target = recurse-until-str($ast).join.trim.subst(/ \s /, '_', :g);
    if +@rejects {
        # if plain target is rejected, then start adding a suffix
        $target ~= '_0';
        $target += 1 while $target ~~ any(@rejects)
    }
    $target
}
#| gets the meta data from a block
sub get-meta($ast --> Hash) {
    $ast.config.pairs.map(
            { .key => .value.literalize }
            ).hash
}

#| returns hash of test templates
sub test-text-temps {
    %(
        code => -> %prm, $tmpl {
            "<code>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</code>\n"
        },
        input => -> %prm, $tmpl {
            "<input>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</input>\n"
        },
        output => -> %prm, $tmpl {
            "<output>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</output>\n"
        },
        comment => -> %prm, $tmpl {
            "<comment>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</comment>\n"
        },
        head => -> %prm, $tmpl {
            "<head>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</head>\n"
        },
        numhead => -> %prm, $tmpl {
            "<numhead>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</numhead>\n"
        },
        defn => -> %prm, $tmpl {
            "<defn>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</defn>\n"
        },
        item => -> %prm, $tmpl {
            "<item>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</item>\n"
        },
        numitem => -> %prm, $tmpl {
            "<numitem>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</numitem>\n"
        },
        nested => -> %prm, $tmpl {
            "<nested>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</nested>\n"
        },
        para => -> %prm, $tmpl {
            "<para>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</para>\n"
        },
        rakudoc => -> %prm, $tmpl {
            "<rakudoc>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</rakudoc>\n"
        },
        section => -> %prm, $tmpl {
            "<section>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</section>\n"
        },
        pod => -> %prm, $tmpl {
            "<pod>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</pod>\n"
        },
        table => -> %prm, $tmpl {
            "<table>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</table>\n"
        },
        semantic => -> %prm, $tmpl {
            "<semantic>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</semantic>\n"
        },
        custom => -> %prm, $tmpl {
            "<custom>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</custom>\n"
        },
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
#| returns a set of default text templates
sub text-temps {
    %(
        code => -> %prm, $tmpl {
            "<code>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</code>\n"
        },
        input => -> %prm, $tmpl {
            "<input>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</input>\n"
        },
        output => -> %prm, $tmpl {
            "<output>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</output>\n"
        },
        comment => -> %prm, $tmpl {
            "<comment>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</comment>\n"
        },
        head => -> %prm, $tmpl {
            my $indent = %prm<level> > 2 ?? 4 !! (%prm<level> - 1) * 2;
            qq:to/HEAD/
            { %prm<contents>.Str.indent($indent) }
            { ('-' x %prm<contents>.Str.chars).indent($indent) }
            HEAD
        },
        numhead => -> %prm, $tmpl {
            "<numhead>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</numhead>\n"
        },
        defn => -> %prm, $tmpl {
            "<defn>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</defn>\n"
        },
        item => -> %prm, $tmpl {
            "<item>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</item>\n"
        },
        numitem => -> %prm, $tmpl {
            "<numitem>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</numitem>\n"
        },
        nested => -> %prm, $tmpl {
            "<nested>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</nested>\n"
        },
        para => -> %prm, $tmpl {
            "<para>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</para>\n"
        },
        rakudoc => -> %prm, $tmpl {
            "<rakudoc>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</rakudoc>\n"
        },
        section => -> %prm, $tmpl {
            "<section>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</section>\n"
        },
        pod => -> %prm, $tmpl {
            "<pod>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</pod>\n"
        },
        table => -> %prm, $tmpl {
            "<table>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</table>\n"
        },
        semantic => -> %prm, $tmpl {
            "<semantic>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</semantic>\n"
        },
        custom => -> %prm, $tmpl {
            "<custom>\n" ~ %prm.sort>>.fmt("%s: %s\n") ~ "</custom>\n"
        },
    );
}