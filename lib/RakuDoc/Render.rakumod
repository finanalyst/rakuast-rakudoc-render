use v6.d;
use RakuDoc::Processed;

class RakuDoc::Processor {
    has @plugins;
    has %templates;

    method render( @rakudoc-statements, :%metadata --> RakuDoc::Processed ) {
        %metadata<creation-time> = now;
        %metadata<name> = 'unknown' unless %metadata<name>:exists;
        %metadata<output-type> = 'text' unless %metadata<output-type>:exists;
        my RakuDoc::Processed $rpo .= new( %metadata );
    }

}