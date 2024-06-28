use v6.d;
use RakuDoc::To::HTML;

unit class RakuDoc::To::HTML-Extra is RakuDoc::To::HTML;

submethod TWEAK {}

method render($ast) {
    my $fn = $*PROGRAM;
    my %source-data = %(
        name     => ~$fn,
        modified => $fn.modified,
        path     => $fn.dirname,
    );
    self.new.rdp.render( $ast, :%source-data  )
}
