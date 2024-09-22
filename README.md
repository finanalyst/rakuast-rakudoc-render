### has SetHash $!debug-modes

debug modes that are checked

### multi method render

```raku
multi method render(
    $ast,
    :%source-data,
    :pre-finalized(:$pre-finalised) = Bool::False
) returns Mu
```

renders to a String by default, but returns ProcessedState object if pre-finalised = True

### method post-process

```raku
method post-process(
    Str:D $final
) returns Str
```

This method is used to post process the final rendered output Use case: change targets to line numbers in a text output It should be overridden in subclasses for other outputs

### method handle

```raku
method handle(
    $ast
) returns Mu
```

All handle methods may generate debug reports

### multi method handle

```raku
multi method handle(
    RakuAST::Doc::Paragraph:D $ast
) returns Mu
```

This block is created by the parser when a text has embedded markup Also ordinary strings in an extended block are coerced into one Sometimes, eg for a table cell, the paragraph should not be ended with a newline.

### multi method merge-index

```raku
multi method merge-index(
    %p,
    %q
) returns Mu
```

similar to merge-index in Processed, but simpler because less generic

### method gen-paraish

```raku
method gen-paraish(
    $ast,
    $template,
    $parify
) returns Mu
```

generic code for next, para, code, input, output blocks No ToC content is added unless overridden by toc/caption/headlevel

### method gen-headish

```raku
method gen-headish(
    $ast,
    $parify,
    :$template = "head",
    :$numerate = Bool::False
) returns Mu
```

A header adds contents at given level to ToC, unless overridden by toc/headlevel/caption These can be set by a config directive The id option may be used to create a target An automatic target is also created from the contents

### method gen-formula

```raku
method gen-formula(
    $ast
) returns Mu
```

Formula at level 1 is added to ToC unless overriden by toc/headlevel/caption Content is passed verbatim to template as formula An alt text is also generated

### method gen-item

```raku
method gen-item(
    $ast,
    $parify
) returns Mu
```

generates a single item and adds it to the item structure nothing is added to the .body string bullet strategy can be left to template, with bullet in %config

### method gen-numitem

```raku
method gen-numitem(
    $ast,
    $parify
) returns Mu
```

generates a single numitem and adds it to the numitem structure nothing is added to the .body string

### method gen-defn

```raku
method gen-defn(
    $ast,
    :$numerate = Bool::False
) returns Mu
```

generates a single definition and adds it to the defn structure unlike item, a defn: - list has a flat hierarchy - can be created by a markup code - needs a target for links, and text for popup - is PCell-stored allowing for defn to be redefined like items nothing is added to the .body string until next non-defn

### method gen-place

```raku
method gen-place(
    $ast
) returns Mu
```

A place block adds Place at level 1 to ToC unless toc/headlevel/caption set The contents of Place is a URI that is generated and then rendered with place template

### method gen-rakudoc

```raku
method gen-rakudoc(
    $ast,
    $parify
) returns Mu
```

The rakudoc block should encompass the output Config data associated with block is provided to overall process state If a rakudoc file is embedded via place, then another rakudoc block will be called. Only allow embedding to three levels to avoid circularity.

### method gen-section

```raku
method gen-section(
    $ast,
    $parify
) returns Mu
```

A section is invisible to ToC, but is used by scoping Some output formats may want to handle section, so embedded RakuDoc are rendered and contents rendered by section template

### multi method gen-table

```raku
multi method gen-table(
    $ast
) returns Mu
```

Table is added to ToC with level 1 as TABLE unless overriden by toc/headlevel/caption contents is processed and rendered using table template

### method gen-unknown-builtin

```raku
method gen-unknown-builtin(
    $ast
) returns Mu
```

A lower case block generates a warning DEPARSED Str is rendered with 'unknown' template Nothing added to ToC

### method gen-semantics

```raku
method gen-semantics(
    $ast,
    $parify
) returns Mu
```

Semantic blocks defined by spelling embedded content is rendered and passed to template as contents rendered contents is added to the semantic structure If :hidden is True, then the string is not added to .body Unless :hidden, Block name is added to ToC at level 1, unless overriden by toc/caption/headlevel TITLE & SUBTITLE by default :hidden is True and added to $*prs separately All other SEMANTIC blocks are :!hidden by default

### method complete-footnotes

```raku
method complete-footnotes() returns Mu
```

finalise the rendering of footnotes the numbering only happens when all footnotes are collected completes the PCell in the body

### sub si

```raku
sub si(
    %h,
    $n,
    $max
) returns Mu
```

completes the index by rendering each key triggers the 'index-schema' id, which may be placed by a P<>

### method complete-toc

```raku
method complete-toc(
    :$spec,
    :$caption
) returns PStr
```

renders the complete toc

### method complete-heading-numerations

```raku
method complete-heading-numerations() returns Mu
```

finalises all the heading numerations

### method complete-item-list

```raku
method complete-item-list() returns Mu
```

finalises rendering of the item list in $*prs

### method complete-defn-list

```raku
method complete-defn-list() returns Mu
```

finalises rendering of a defn list in $*prs

### method complete-numitem-list

```raku
method complete-numitem-list() returns Mu
```

finalises rendering of the item list in $*prs

### method complete-numdefn-list

```raku
method complete-numdefn-list() returns Mu
```

finalises rendering of a defn list in $*prs

### method contents

```raku
method contents(
    $ast,
    Bool $parify
) returns Mu
```

The 'contents' method is called when $ast.paragraphs is a sequence. The $*prs for a set of paragraphs is new to collect all the associated data. The body of the contents must then be incorporated using the template of the block calling content when parify, strings are considered paragraphs

### method markup-contents

```raku
method markup-contents(
    $ast
) returns Mu
```

similar to contents but expects atoms structure

### method merged-config

```raku
method merged-config(
    $ast,
    $block-name
) returns Hash
```

get config merged from the ast and scoped data handle generic metadata options such as delta

### method name-id

```raku
method name-id(
    $ast
) returns Str
```

name-id takes an ast returns a unique Str to be used as an anchor / target Used by any name (block) that is placed in the ToC Also used for the main anchor in the text for a footnote Not called if an :id is specified in the source This method should be sub-classed by Renderers for different outputs renderers can use method is-target-unique to test for uniqueness

### method index-id

```raku
method index-id(
    :$context,
    :$contents,
    :$meta
) returns Mu
```

Like name-id, index-id returns a unique Str to be used as a target Target should be unique Should be sub-classed by Renderers

### method local-heading

```raku
method local-heading(
    $ast
) returns Mu
```

Like name-id, local-heading returns a Str to be used as a target A local-heading is assumed to exist because specified by document author Should be sub-classed by Renderers

### multi method default-text-templates

```raku
multi method default-text-templates() returns Mu
```

returns a set of text templates

### multi method default-helpers

```raku
multi method default-helpers() returns Mu
```

returns hash of test helper callables

