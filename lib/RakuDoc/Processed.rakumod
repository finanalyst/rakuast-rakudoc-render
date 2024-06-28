use v6.d;
use RakuDoc::PromiseStrings;
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

    #| heading numbering data
    #| Ordered array of [ $id, $level ]
    #| $id is the PCell id of where the numeration structure is to be placed
    #| level - in heading hierarchy
    has Array @.head-numbering;

    #| Index (from X<> markup)
    #| Hash entry => Hash of :refs, :sub-index
    #| :index (maybe empty) is Hash of sub-entry => :target, :sub-index
    #| :refs is Array of (Hash :target, :place, :is-header)
    #| :target is for link, :place is section name
    #| :is-header because X<> in headings treated differently to ordinary text
    has %.index;

    #| Footnotes (from N<> markup)
    #| Ordered Array of :$text, :$retTarget, :$fnNumber, :$fnTarget
    #| text is content of footnote, fnNumber is footNote number
    #| fnTarget is link to rendered footnote
    #| retTarget is link to where footnote is defined to link back form footnote
    has @.footnotes;

    #| Semantic blocks (which includes TITLE & SUBTITLE) can be hidden
    #| Hash of SEMANTIC => [ PStr | Str ]
    has Array %.semantics;

    #| An array of warnings is generated and then rendered by the warnings template
    #| The warning template, by default is called by the wrap-source template
    #| RakuDoc warnings are generated as specified in the RakuDoc v2 document.
    has @.warnings;

    #| An array of accumulated rendered items, added to body when next non-item block encountered
    has @.items;

    #| An array of accumulated rendered definitions, added to body when next non-defn block encountered
    has @.defns;

    #| An array of accumulated rendered numbered items, added to body when next non-item block encountered
    has @.numitems;

    #| An array of accumulated rendered numbered definitions, added to body when next non-defn block encountered
    has @.numdefns;

    #| Hash of definition => rendered value for definitions
    has %.definitions;

    #| Array to signal when one or more inline defn are made in a Paragraph
    has @.inline-defns;

    multi method gist(ProcessedState:U: ) { 'Undefined ProcessedState object' }

    multi method gist(ProcessedState:D: Int :$output = 300 ) {
        qq:to/GIST/;
        ProcessedState contains:
            semantics => { pretty-dump( %.semantics, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
            :indent('  '), :post-separator-spacing("\n  ") )  }
            toc => { pretty-dump(@.toc, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ")) }
            head-numbering => { pretty-dump(@.head-numbering, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ")) }
            index => { pretty-dump( %.index, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ") )  }
            footnotes => { pretty-dump( @.footnotes, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") )  }
            warnings => { pretty-dump( @.warnings, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            items => { pretty-dump( @.items, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            definitions => { pretty-dump( %.definitions, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ") )  }
            defns => { pretty-dump( @.defns, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            inline-defns => { pretty-dump( @.inline-defns, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            numitems => { pretty-dump( @.numitems, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            numdefns => { pretty-dump( @.numdefns, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            body => { with $.body.debug  { .substr(0, $output) ~ ( .chars > $output ?? "\n... (" ~ .chars - $output ~ ' more chars)' !! '') } }
        GIST
    }
}

|# Class object contains the rendered date of a RakuDoc source
class RakuDoc::Processed is ProcessedState {
    #| Information about the RakuDoc source, eg file name, path, modified, language
    has %.source-data;
    #| The output format that the source has been rendered into
    has $!output-format = 'txt';
    #| Text between =TITLE and first header, used for X<> place before first header
    has Str $.front-matter is rw = 'preface';
    #| Name to be used in titles and files
    #| name can be modified after creation of Object
    #| name can be set when creating object
    #| if name is not set, then it is taken from source name + format
    has Str $.name is rw;
    #| String value of TITLE.
    has Str $.title is rw = 'NO_TITLE';
    #| Target of Title Line
    has Str $.title-target is rw = '___top';
    #| String value of SUBTITLE, provides description of file
    has Str $.subtitle is rw = '';
    #| When RakuDoc Processed Object modified
    #| (source-data<modified> should be earlier than RPO.modified)
    has Str $.modified is rw = now.DateTime.truncated-to('seconds').Str;
    #| target data generated from block names and :id metadata
    #| A set of unique targets inside the file, new targets must be unique
    has SetHash $.targets;
    #| Links (from L<link-label|destination> markup)
    #| Hash of destination => :target, :type, :place, :link-label
    #| target = computed URL (for local files), place = anchor inside file
    #| type has following values
    #| Internal are of the form '#this is a heading' and refer to anchors inside the file
    #| Local are of the form 'some-type#a heading there', where 'some-type' is a file name in the same directory
    #| External is a fully qualified URL
    #|
    has Hash %.links;
    #| Rendered version of the ToC
    has $.rendered-toc is rw;
    #| Rendered version of the Index
    has $.rendered-index is rw;

    submethod TWEAK( :%source-data, :$name, :$output-format ) {
        %!source-data =
            name => 'Unnamed-source',
            path => '.',
            language => 'en',
            modified => '2020-12-31T00:00:01Z',
            toc-caption => 'Table of Contents',
            index-caption => 'Index',
            rakudoc-title => 'Preface', # used to name sections before first title
            paragraph-id-length => 7,
            |%source-data,  # let arguments override the above
        ;
        %!source-data{ .key } = .value for %source-data.pairs;
        $!output-format = $_ with $output-format;
        # if name is set on new, then it will be defined by TWEAK, else undefined, so take it from
        without $!name { $!name = %!source-data<name> ~ '.' ~ $!output-format }
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
            head-numbering => { pretty-dump(@.head-numbering, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ")) }
            index => { pretty-dump( %.index, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ") )  }
            footnotes => { pretty-dump( @.footnotes, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") )  }
            links => { pretty-dump( %.links, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") )  }
            targets => <｢{ $!targets.keys.join('｣, ｢') }｣>
            items => { pretty-dump( @.items, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            definitions => { pretty-dump( %.definitions, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
               :indent('  '), :post-separator-spacing("\n  ") )  }
            defns => { pretty-dump( @.defns, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            inline-defns => { pretty-dump( @.inline-defns, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            numitems => { pretty-dump( @.numitems, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            numdefns => { pretty-dump( @.numdefns, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            warnings => { pretty-dump( @.warnings, :pre-item-spacing("\n   "),:post-item-spacing("\n    "),
                :indent('  '), :post-separator-spacing("\n  ") ) }
            body => { with $.body.debug  { .substr(0, $output) ~ ( .chars > $output ?? "\n... (" ~ .chars - $output ~ ' more chars)' !! '') } }
        GIST
    }
}
multi sub merge-index( %p, %q ) {
    for %q.keys -> $k {
        if %p{$k}:exists {
            %p{$k}<refs>.append: %q{$k}<refs>.Slip;
            if %p{$k}<sub-index>.elems and %q{$k}<sub-index>.elems {
                %p{$k}<sub-index> = merge-index( %p{$k}<sub-index>, %q{$k}<sub-index> )
            }
            elsif %q{$k}<sub-index>.elems {
                %p{$k}<sub-index> = %q{$k}<sub-index>
            } # otherwise either p-subindex or q-sub-index are empty, so no change
        }
        else {
            %p{$k} = %q{$k}
        }
    }
}
multi sub merge-index( $p, $q ) {
    # no change needed
}

#| Add one ProcessedState object to another
multi sub infix:<+>( ProcessedState $p, ProcessedState $q ) is export {
    sink $p.body ~ $q.body;
    $p.toc.append: $q.toc;
    $p.head-numbering.append: $q.head-numbering;
    merge-index($p.index, $q.index);
    $p.footnotes.append: $q.footnotes;
    for $q.semantics.kv -> $k, $v { # by definition, same key but multiple values
        $p.semantics{$k}.append: $v.Slip
    }
    $p.warnings.append: $q.warnings;
    $p.items.append: $q.items;
    $p.defns.append: $q.defns;
    $p.inline-defns.append: $q.inline-defns;
    for $q.definitions.kv -> $k, $v { # no multiple values
        $p.definitions{$k} = $v # redefinition possible
    }
    $p.numitems.append: $q.numitems;
    $p.numdefns.append: $q.numdefns;
    $p
}