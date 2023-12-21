use v6.d;
use RakuDoc::Templates;
use RakuDoc::Render;
use RakuDoc::Processed;

class RakuDoc::To::HTML::Plugin is RakuDoc::Plugin {

}

module RakuDoc::To::HTML {

    multi sub MAIN( Str:D $fn ) is export {
        exit note "Cannot find source file $fn, try adding a relative path"
            unless $fn.IO ~~ :e & :f;
        my RakuDoc::Processor $processor .= new( :output-format<HTML>, :meta( %(:path( $fn ),) ) );
        $processor.plugin( RakuDoc::To::HTML::plugin.new );
        my RakuDoc::Processed $rpo = $processor.render( $fn.IO.slurp.AST
    }

}