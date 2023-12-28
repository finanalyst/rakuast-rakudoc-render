use experimental :rakuast;

use RakuDoc::Processed;
use RakuDoc::Templates;

class RakuDoc::Processor {
    has %.templates is Template-directory;
    has Supplier::Preserving $.com-channel .= new;
    has RakuDoc::Processed $.current;
    has $.output-format;

    submethod BUILD(:$!output-format = 'text') {
        %!templates = text-temps;
    }

    method render($ast , :%source-data --> RakuDoc::Processed) {
        $!current .= new(:%source-data);
        #| create the config hash
        my %*scoped-data;
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
        $*prs.body ~= $.gen-item-list() unless $ast.type and $ast.type eq 'item';
        $*prs.body ~= $.gen-defn-list() unless $ast.type and $ast.type eq 'defn';
        given $ast.type {
            when 'alias' { $.gen-alias( $ast ) }
            when 'code' { $.gen-code( $ast ) }
            when 'comment' { '' }
            when 'config' { '' }
            when 'head' { $.gen-head( $ast ) }
            when 'implicit-code' { $.gen-code( $ast ) }
            when 'item' { $.gen-item( $ast ) }
            when 'rakudoc' | 'pod' { $.gen-rakudoc( $ast ) }
#            when 'rakudoc' { '' }
            when 'section' { $.section( $ast ) }
            when 'table' { $.gen-table( $ast ) }
            default { $.gen-unknown( $ast ) }
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
        $*blocks{'PARAGRAPH'}++;
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
    method gen-alias( $ast ) {
        ''
    }
    method gen-code( $ast ) {
        ''
    }
    method gen-head( $ast ) {

        my $level = $ast.level > 1 ?? $ast.level !! 1;
        my $target = name-id( $ast );
        my @rejects;
        until $.is-target-unique( $target ) {
            @rejects.push( $target );
            $target = name-id( $ast, :@rejects )
        }
        $.register-target( $target );
        my $contents = $.contents($ast);
        $*prs.body ~= %!templates<head>(
            %( :$level, :$target, :$contents )
        )
    }
    method gen-item( $ast ) {
        ''
    }
    method gen-rakudoc( $ast ) {
        ''
    }
    method gen-section( $ast ) {
        ''
    }
    method gen-table( $ast ) {
        ''
    }
    method gen-unknown( $ast ) {
        ''
    }
    method gen-item-list() {
        ''
    }
    method gen-defn-list() { '' }
    method is-target-unique( $targ --> Bool ) {
        ! $!current.targets{ $targ }
    }
    method register-target( $targ ) {
        $!current.targets{ $targ }++
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
        my ProcessedState $rv  .= new;
        $rv += $_ for @prs;
        my PStr $text = $rv.body;
        $rv.body .= new;
        $*prs += $rv;
        $text
    }
}


#| Strip out formatting code and links from a Title or Link
multi sub recurse-until-str(Str:D $s) is export { $s }
multi sub recurse-until-str(RakuAST::Doc::Block $n) is export {
    $n.paragraphs>>.&recurse-until-str().join
}
#| name-id takes an ast and an optional array of rejects
#| returns a Str to be used as an internal target
#| renderers should sub-class name-id
sub name-id( $ast, :@rejects  --> Str ) {
    my $target = recurse-until-str($ast).join.trim;
    if +@rejects {
        # if plain target is rejected, then start adding a suffix
        $target ~= '_0';
        $target += 1 while $target ~~ any( @rejects )
    }
    $target
}
sub text-temps {
    %(
        code => -> %prm, $tmpl {
            '<code>' ~ %prm.gist ~ '</code>'
        },
        input => -> %prm, $tmpl {
            '<input>' ~ %prm.gist ~ '</input>'
        },
        output => -> %prm, $tmpl {
            '<output>' ~ %prm.gist ~ '</output>'
        },
        comment => -> %prm, $tmpl {
            '<comment>' ~ %prm.gist ~ '</comment>'
        },
        head => -> %prm, $tmpl {
            '<head>' ~ %prm.gist ~ '</head>'
        },
        numhead => -> %prm, $tmpl {
            '<numhead>' ~ %prm.gist ~ '</numhead>'
        },
        defn => -> %prm, $tmpl {
            '<defn>' ~ %prm.gist ~ '</defn>'
        },
        item => -> %prm, $tmpl {
            '<item>' ~ %prm.gist ~ '</item>'
        },
        numitem => -> %prm, $tmpl {
            '<numitem>' ~ %prm.gist ~ '</numitem>'
        },
        nested => -> %prm, $tmpl {
            '<nested>' ~ %prm.gist ~ '</nested>'
        },
        para => -> %prm, $tmpl {
            '<para>' ~ %prm.gist ~ '</para>'
        },
        rakudoc => -> %prm, $tmpl {
            '<rakudoc>' ~ %prm.gist ~ '</rakudoc>'
        },
        section => -> %prm, $tmpl {
            '<section>' ~ %prm.gist ~ '</section>'
        },
        pod => -> %prm, $tmpl {
            '<pod>' ~ %prm.gist ~ '</pod>'
        },
        table => -> %prm, $tmpl {
            '<table>' ~ %prm.gist ~ '</table>'
        },
        semantic => -> %prm, $tmpl {
            '<semantic>' ~ %prm.gist ~ '</semantic>'
        },
        custom => -> %prm, $tmpl {
            '<custom>' ~ %prm.gist ~ '</custom>'
        },
    );
}