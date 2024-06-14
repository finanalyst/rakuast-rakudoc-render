use experimental :rakuast;
use RakuDoc::Render;

unit class RakuDoc::To::Generic;
method render( $ast ) {
    my $fn = $*PROGRAM;
    my %source-data = %(
        name     => ~$fn,
        modified => $fn.modified,
        path     => $fn.dirname
    );
    my $rdp = RakuDoc::Processor.new;
    $rdp.render( $ast, :%source-data  )
}