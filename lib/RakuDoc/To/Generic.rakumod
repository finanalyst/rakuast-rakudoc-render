use experimental :rakuast;
use RakuDoc::Render;

unit class RakuDoc::To::Generic;
method render( $ast ) {
    my $rdp = RakuDoc::Processor.new;
    $rdp.render( $ast[0] )
}