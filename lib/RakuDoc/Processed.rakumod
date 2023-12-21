use v6.d;
use RakuDoc::Templates;
use PrettyDump;

class RakuDoc::Processed {
    #| (string of rendered source, may contain Promises during rendering)
    has PStr $!body .= new;
    #| about the source, eg file name, path, modified, language
    has %.source-data =
            name => 'UNNAMED',
            path => '.',
            language => 'en',
            modified => '2020-12-31T00:00:01Z', # before module written
    ;
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

    #| Source configuration (from =rakudoc metadata options)
    has %!source-config;

    #| Table of Contents data
    #| Ordered array of { :level, :text, :target, :is-heading }
    #| level - in heading hierarchy, text - to be shown in TOC
    #| target - of item in text, is-heading - used for Index placing
    has @.toc;

    #| Index (glossary) (from X<> markup)
    #| Hash key => Array of :target, :is-header, :place
    #| key to be displayed, target is for link, place is description of section
    #| is-header because X<> in headings treated differently to ordinary text
    has %.index;

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
    has %.links;

    #| target data generated from block names and :id metadata
    #| A set of unique targets inside the file, new targets must be unique
    has SetHash $.targets;

    #| Aliases (from =alias ALIAS EXPANSION)
    #| ALIAS => EXPANSION (which may be PStr)
    has %.aliases;

    #| Definitions (from =defn DEFINITION EXPANSION, D<DEFINITION|EXPANSION>)
    #| DEFINITION => EXPANSION
    has %.definitions;

    #| Semantic blocks (which includes TITLE & SUBTITLE) can be hidden
    #| Hash of SEMANTIC => [Array of] PStr
    has %.semantics;
    
    multi method gist(RakuDoc::Processed:U: ) { 'Undefined PodFile' }
    
    multi method gist(RakuDoc::Processed:D: Int :$output = 175 ) {
        qq:to/GIST/;
        PodFile contains:
            front-matter => Str=｢{ $!front-matter }｣
            name => Str=｢{ $!name }｣
            title => Str=｢{ $!title }｣
            title-target => Str=｢{ $!title-target }｣
            subtitle => Str=｢{ $!subtitle }｣
            source-data => { pretty-dump( %!source-data ) }｣
            semantics => { pretty-dump( %!semantics, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
            :indent('  '), :post-separator-spacing("\n  ") )  }
            toc => { pretty-dump(@!toc, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ")) }
            index => { pretty-dump( %!index, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ") )  }
            footnotes => { pretty-dump( @!footnotes, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") )  }
            source-config => { pretty-dump( %!source-config, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") )  }
            links => { pretty-dump( %!links, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") )  }
            targets => <｢{ $!targets.keys.join('｣, ｢') }｣>
            body => { with $!body.Str  { .substr(0, $output) ~ ( .chars > $output ?? "\n... (" ~ .chars - $output ~ ' more chars)' !! '') } }
        GIST
    }
}

#| Add one processed object to another, push toc, concat body, merge other structures
multi sub infix:<+>( RakuDoc::Processed $p, RakuDoc::Processed $q ) is export {
    $p.body ~ $q.body;
    $p.toc.push: $q.toc;
    $p.index ,= $q.index;
    # TODO this is probably wrong as same name keys will be over-written
    $p.footnotes.push: $q.footnotes;
    $p.links ,= $q.links;
    $p.targets ,= $q.targets;
    $p.aliases ,= $q.aliases;
    $p.definitions ,= $q.definitions;
    $p.semantics ,= $q.semantics;
    $p
}