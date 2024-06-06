use experimental :rakuast;
use RakuDoc::Render;

unit class RakuDoc::To::Generic;
method render( $ast ) {
    say 'got here';
#    my $rdp = RakuDoc::Processor.new(:test);
#    say $_.raku;
#    $rdp.render( $ast )
}