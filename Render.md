        # Minimal documentation of RakuDoc::Render Module
>
## Table of Contents
[Overview](#overview)  
[Templates](#templates)  
[Warnings](#warnings)  
[Customisability](#customisability)  
[Custom blocks](#custom-blocks)  
[Custom markup codes](#custom-markup-codes)  
[Markup M](#markup-m)  
[Markup UNICODE[upper]](#markup-unicodeupper)  
[Global data accessible in templates](#global-data-accessible-in-templates)  
[Debugging](#debugging-0)  
[Debug options](#debug-options)  

----
# Overview
The module contains the RakuDoc::Processor class.

The class method 'render' is the principal one for rendering RakuDoc v2. The Raku compiler expects to call render with an AST and to return a Str. It can be called with the option `:pre-finalised` to get the processed data, see the example in [Debugging](debugging).

The aim is for a **RakuDoc::Processor** object (an **RPO**) to be as generic as possible, allowing for other classes to instantiate it, and to attach templates that will generate more specific formats, such as HTML, MarkDown, or EPub pages.

An **RPO** relies on [Templates](/Templates.md), [PromiseStrings](/PromiseStrings.md), and [ScopedData](/ScopedData.md).

It is also necessary to have a good understanding of RakuDoc v2.

The following describes choices that are left by RakuDoc v2 to the renderer.

## Templates
An **RPO** contains two sets of templates, one to be used for testing, as can be seen in the `xt/` directory, and a default set of Text templates.

The aim of the text templates is that they are the lowest level templates needed to render any RakuDoc source.

When a renderer is needed to output a new format, eg., HTML, the renderer instantiates an **RPO** and attaches new templates to it using the `add-template( Pair $p )` method or the `add-templates( Hash $h )` method.

The design of the Templates object means that new additions to the object push the previous definition onto a linked list, and so they will always be available by default.

The set of template keys needed to create a renderer is [tabulated here](/test-text-templates.md).

All aspects of the output can be defined using the templates.

## Warnings
In order to offer the maximum flexibility to a RakuDoc author, if there is an error condition after the RakuDoc source has been compiled, a set of warnings are generated.

By default these are rendered using the 'warnings' template, and the rendered version is appended to the output file.

## Customisability
RakuDoc allows for customisability. This renderer handles customisability via the template mechanism.

### Custom blocks
When custom block is detected according to the RakuDoc v2 spelling rules, an **RPO** will check whether a template exists with that name.

If a template has been attached to an **RPO**, then the rendered content of the block (including rendered embedded RakuDoc instructions) will be provided to the template as `contents` and the verbatim contents with no renderering will be provided as `raw`.

So a new block can be created by attaching a template with the blockname to the **RPO**.

### Custom markup codes
RakuDoc v2 allows for custom markup codes in two ways:

*  the `M< DISPLAY | FUNCTION ; list of comma delimited strings > `

*  a single Unicode (not ASCII ) character with the _upper_ property.

#### Markup M
When a `M< DISPLAY | FUNCTION ; LIST > ` is encountered, the renderer will look for a template named in the "> \{\{\{ contents }}}

 position. If no such template exists, the text will be rendered verbatim and a warning logged.

#### Markup UNICODE[upper]
When some custom markup is encountered, the renderer will

*  check that the character, eg Ɵ (Greek Capital Theta), has the unicode property _Upper_;

*  look for a template called (eg) **markup-Ɵ**. For clarity, the Unicode character chosen for the markup code is prefixed by **markup-** in order to name the template.

Thus in order to create a new markup code, create an appropriately named template and add it to the **RPO**.

### Global data accessible in templates
More information is available in [Templates](/Templates.md).

All templates can attach items to the Table of Contents, Index, Footnotes, and Warnings structures of the rendered source using the helper methods.

The following helper methods are available:

*  add-to-toc( %h ), where %h is a hash with the following keys:

	*  :caption(Str)

	*  :target( Str )

	*  :level( Int )

*  add-to-index( %h ), where %h is a hash with the following keys:

	*  :contents(Str)

	*  :target(Str)

	*  :place( Str }

*  add-to-footnotes( %h ), where %h is a hash with the following keys:

	*  :retTarget(Str)

	*  :fnTarget(Str)

	*  :fnNumber(Str}

*  add-to-warnings( $warning )

In addition, within a template, it is possible to attach data to globals, and to retrieve the data in another template.

For an example of this, see test **xt/030-customisation-data.rakutest**. (test number may be changed, but otherwise the filename will be the same).

## Debugging
When developing new templates or renderers based on an **RPO**, several debug options can be attached to the **RPO**, eg.

```
    my RakuDoc::Processor $rdp .=new( :test );
    $rdp.debug( AstBlock, Templates);
    $ast = Q:to/QAST/.AST;
    =begin rakudoc
    =head This is a header

    Some text

    =end rakudoc
    QAST

    $rv = $rdp.render( $ast, :pre-finalised );
    'myOutput'.IO.spurt: $rdp.finalise

```
Commentary on the code

*  `new( :test )` this attaches the test templates to the **RPO**

*  the list inside the debug method may contain several entities as described below

*  creation of an AST from a string, or it can be slurped in from a file.

*  `:pre-finalised ` returns the RakuDoc::Processed object

*  if called with `:pre-finalised`, calling `finalise` returns a Str that can then be stored as a file.

### Debug options
The following options are available:

*  None removes all previous debugging

*  All adds all debugging options

*  AstBlock diagnostic whenever a new Block is called

*  BlockType information about which `RakuAST::Doc::Block` is being processed

*  Scoping produces scope level diagnostics when a new level is started/ended

*  Templates indicates which templates are called and the params they are called with

*  MarkUp like BlockType but gives the MarkUp letter

It is also possible to get the result of one template (so as to reduce the amount of output information). This is done eg for the 'table' template: $rdp.verbose( 'table' ); $rv = $rdp.render( $ast, :pre-finalised );







----
Rendered from Render at 2024-06-04T22:21:33Z