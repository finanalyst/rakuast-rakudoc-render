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
        $!current .= new(%source-data);
        #| create the config hash
        my %*config;
        $!current += [+] await $ast.rakudoc.map({ start self.handle($_) });
        # statements now created
        say $.current.gist;
    }

    proto method handle(|c --> ProcessedState) {
        my ProcessedState $*prs .= new;
        {*}
        $*prs
    }
    multi method handle(Str:D $ast) {
        $*prs.body ~ $ast
    }
    multi method handle(RakuAST::Node:D $ast) {
        $*prs = [+] await $ast.rakudoc.map({ start self.handle($_) });
    }
    multi method handle(RakuAST::Doc::Block:D $ast) {
        given $ast.type {
            when 'alias' { '' }
            when 'code' { '' }
            when 'comment' { '' }
            when 'config' { '' }
            when 'head' { '' }
            when 'implicit-code' { '' }
            when 'item' { '' }
            when 'pod' { '' }
            when 'rakudoc' { '' }
            when 'table' { '' }
            default { '' }
        }
        $*prs = [+] await $ast.paragraphs.map({ start self.handle($_) });
    }
    multi method handle(RakuAST::Doc::DeclaratorTarget:D $ast) {
        #ignore declarator blocks
    }
    multi method handle(RakuAST::Doc::Markup:D $ast) {
        $*blocks{'MARKUP / ' ~ $ast.letter}++
    }
    multi method handle(RakuAST::Doc::Paragraph:D $ast) {
        $*blocks{'PARAGRAPH'}++;
        $*prs = [+] await $ast.atoms.map({ start self.handle($_) });
    }
    multi method handle(RakuAST::Doc::Row:D $ast) {
        self.handle('ROW')
    }
    multi method handle(Cool:D $ast) {
        self.handle($ast.WHICH.Str)
    }

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