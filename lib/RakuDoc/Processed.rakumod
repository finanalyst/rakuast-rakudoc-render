use v6.d;
use RakuDoc::Templates;
use PrettyDump;

#| Instances of ProcessedState are created to contain the rendered form and collected data
#| of leaves of a RakuDoc AST.
class ProcessedState {
    #| String of rendered source, may contain Promises during rendering
    has PStr $.body is rw .= new;

    #| Table of Contents data
    #| Ordered array of { :level, :text, :target, :is-heading }
    #| level - in heading hierarchy, text - to be shown in TOC
    #| target - of item in text, is-heading - used for Index placing
    has Hash @.toc;

    #| Index (from X<> markup)
    #| Hash key => Array of :target, :is-header, :place
    #| key to be displayed, target is for link, place is description of section
    #| is-header because X<> in headings treated differently to ordinary text
    has Array %.index;

    #| Footnotes (from N<> markup)
    #| Ordered Array of :$text, :$retTarget, :$fnNumber, :$fnTarget
    #| text is content of footnote, fnNumber is footNote number
    #| fnTarget is link to rendered footnote
    #| retTarget is link to where footnote is defined to link back form footnote
    has @.footnotes;

    #| Links (from L<link-label|destination> markup)
    #| Hash of destination => :target, :type, :place, :link-label
    #| target = computed URL (for local files), place = anchor inside file
    #| type has following values
    #| Internal are of the form '#this is a heading' and refer to anchors inside the file
    #| Local are of the form 'some-type#a heading there', where 'some-type' is a file name in the same directory
    #| External is a fully qualified URL
    #|
    has Hash %.links;

    #| Semantic blocks (which includes TITLE & SUBTITLE) can be hidden
    #| Hash of SEMANTIC => [ PStr | Str ]
    has Array %.semantics;

    #| An array of warnings is generated and then rendered by the warnings template
    #| The warning template, by default is called by the wrap-source template
    #| RakuDoc warnings are generated as specified in the RakuDoc v2 document.
    has Str @.warnings;

    multi method gist(ProcessedState:U: ) { 'Undefined ProcessedState object' }

    multi method gist(ProcessedState:D: Int :$output = 300 ) {
        qq:to/GIST/;
        ProcessedState contains:
            semantics => { pretty-dump( %.semantics, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
            :indent('  '), :post-separator-spacing("\n  ") )  }
            toc => { pretty-dump(@.toc, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ")) }
            index => { pretty-dump( %.index, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ") )  }
            footnotes => { pretty-dump( @.footnotes, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") )  }
            links => { pretty-dump( %.links, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") )  }
            warnings => { pretty-dump( @.warnings, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            body => { with $.body.debug  { .substr(0, $output) ~ ( .chars > $output ?? "\n... (" ~ .chars - $output ~ ' more chars)' !! '') } }
        GIST
    }
}

|# Class object contains the rendered date of a RakuDoc source
class RakuDoc::Processed is ProcessedState {
    #| Information about the RakuDoc source, eg file name, path, modified, language
    has %.source-data;
    #| Text between =TITLE and first header, used for X<> place before first header
    has Str $.front-matter is rw = 'preface';
    #| Name to be used in titles and files.
    has Str $.name is rw = 'UNNAMED';
    #| String value of TITLE.
    has Str $.title is rw = 'NO_TITLE';
    #| Target of Title Line
    has Str $.title-target is rw = '___top';
    #| String value of SUBTITLE, provides description of file
    has Str $.subtitle is rw = '';
    #| When RakuDoc Processed Object modified
    #| (source-data<modified> should be earlier than RPO.modified)
    has Str $.modified is rw = now.DateTime.utc.truncated-to('seconds').Str;
    #| target data generated from block names and :id metadata
    #| A set of unique targets inside the file, new targets must be unique
    has SetHash $.targets;

    submethod BUILD( :%source-data ) {
        %!source-data = %(
            name => 'Un-named source',
            path => '.',
            language => 'en',
            modified => '2020-12-31T00:00:01Z',
            toc-caption => 'Table of Contents',
            index-caption => 'Index',
        );
        %!source-data{ .key } = .value for %source-data.pairs;
        $!targets .= new;
    }
    
    multi method gist(RakuDoc::Processed:U: ) { 'Undefined RakuDoc::Processed object' }
    
    multi method gist(RakuDoc::Processed:D: Int :$output = 300 ) {
        qq:to/GIST/;
        RakuDoc source contains:
            front-matter => Str=｢{ $!front-matter }｣
            name => Str=｢{ $!name }｣
            title => Str=｢{ $!title }｣
            title-target => Str=｢{ $!title-target }｣
            subtitle => Str=｢{ $!subtitle }｣
            source-data => { pretty-dump( %!source-data ) }｣
            semantics => { pretty-dump( %.semantics, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
            :indent('  '), :post-separator-spacing("\n  ") )  }
            toc => { pretty-dump(@.toc, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ")) }
            index => { pretty-dump( %.index, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ") )  }
            footnotes => { pretty-dump( @.footnotes, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") )  }
            links => { pretty-dump( %.links, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") )  }
            targets => <｢{ $!targets.keys.join('｣, ｢') }｣>
            warnings => { pretty-dump( @.warnings, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            body => { with $.body.debug  { .substr(0, $output) ~ ( .chars > $output ?? "\n... (" ~ .chars - $output ~ ' more chars)' !! '') } }
        GIST
    }
}

#| Add one ProcessedState object to another
multi sub infix:<+>( ProcessedState $p, ProcessedState $q ) is export {
    sink $p.body ~ $q.body;
    $p.toc.append: $q.toc;
    for $q.index.kv -> $k, $v { # by definition, same key but multiple values
        $p.index{ $k }.append: $v.Slip
    }
    $p.footnotes.append: $q.footnotes;
    $p.links ,= $q.links; # allow rewriting because keys refer to unique places but may be duplicated in source
    for $q.semantics.kv -> $k, $v { # by definition, same key but multiple values
        $p.semantics{$k}.append: $v.Slip
    }
    $p.warnings.append: $q.warnings;
    $p
}