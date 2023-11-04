# Design of RakuDoc v2 renderer
>Design document for a renderer will render a RakuDoc source that is compliant with RakuDoc version 2. It uses the RakuAST statement list as input. It is a text oriented renderer, not a code oriented renderer.


## Table of Contents
[Requirements](#requirements)  
[Background](#background)  
[Aims](#aims)  
[Process flow](#process-flow)  
[Template management](#template-management)  
[Combination of RPR and Collection](#combination-of-rpr-and-collection)  
[Flaws](#flaws)  
[Lessons](#lessons)  
[New design](#new-design)  
[RakuAST-Render (RR) class](#rakuast-render-rr-class)  
[render( RakuAST::Block @list, :%meta --&gt; ProcessedRakuDoc )](#render-rakuastblock-list-meta----processedrakudoc-)  
[add plugin( Str $path-to-plugin-directory )](#add-plugin-str-path-to-plugin-directory-)  
[ProcessedRakuDoc (RPD) class](#processedrakudoc-rpd-class)  
[Object structures](#object-structures)  
[Class methods](#class-methods)  
[Str](#str)  
[Verify](#verify)  

----
# Requirements
*  Render RakuDoc v2 as specified

*  Allow for customisation

	*  Custom blocks

	*  Custom MarkUp

	*  Customisation via `M<...>` markup

*  Separate processing of RakuDoc from the output format, eg., HTML, MarkDown, XHTML, pdf.

	*  `RakuDoc::To::HTML` is called when `raku --doc=HTML` is entered at the terminal.

	*  `RakuDoc::To::HTML` instantiates the Renderer and supplies what is needed for the output.

*  Allow for multithreading as much as possible.

# Background
This renderer is based on the experience of writing `Raku::Pod::Render`, so the following is some background on RPR, which in turn was mostly based on Pod::To::BigPage.

## Aims
The aims of RPR was to pass all the tests for Pod::To::HTML but for all the HTML formating to be separate from the rendering. So, RPR initially only handled what Pod::To::HTML handled - not the whole of RakuDoc v1.

The formatting was done for each output by a set of templates. Thus, each output format had its own templates.

`Pod::To::HTML` was mirrored by having a parent class `ProcessedPod` that was given HTML templates, whilst `Pod::To::MarkDown` was mirrored by providing MarkDown templates.

An effort was made to make RPR neutral about the templating engine, and templates could be written in Mustache. For speed and convenience, a new Templating engine was written called RakuClosure.

## Process flow
*  an instance of a ProcessedPod (a processor) is created

*  a set of templates must be provided to the processor

	*  a check is made that the minimum set of keys is provided

*  plugins are attached to the processor, each plugin may provide additional templates and custom data.

*  the processor method `process-pod` is called with the compiled version of `$=pod`, which is an Array of `Pod::Blocks`.

	*  A new instance of the PODF class is created, and accumulates (different structures for each data type)

		*  the Table of Contents data (from headings and custom blocks),

		*  Index (glossary) (from `X<>` markup),

		*  Footnotes,

		*  Links,

		*  the rendered body for each block

	*  each `Pod::Block` (PB) has its own handler. Handlers update the PODF object.

	*  constraints are checked (eg., unique id's for each header)

*  the processor method `source-wrap` is called

	*  the meta data (ToC, glossary, footnotes) are rendered using templates

	*  the parameters for the templates are taken from the PODF object

	*  finally, the source-wrap template is used, which expects the body, and rendered ToC and other data

*  the PODF object can be detached from the processor, and the processor used for a new RakuDoc source.

## Template management
*  a minimum set of templates is required

	*  originally requiring a minimum set was intended to be able to catch unknown templates would be caught before processing started

*  new versions of existing templates can be added.

	*  adding a new version of an existing template, adds it to a linked list

*  each template can call other templates

	*  so in fact unknown templates could be called during processing

	*  a template can call a previous version of itself

The `ProcessedPod` object contains a hash of templates, eg.

```
    %.tmpl = %(
        # format-b is called by the handler for B<  >
        format-b => sub ( %prm, %tml --> Str ) {
            qq :to/TMPL/;
                <b>{ %prm<contents> }</b>
            TMPL
        },
        # keys for all the other templates
    );

```
The handler for `B< > ` can then call the sub with the parameters and get a string, eg.

```
    my $returnvalue =  %.tmpl<format-b>.( %( contents => $node.contents, ), %.tmpl );

```
Any template can then call other templates from the `%tml` hash.

Later a plugin can contain a callable that returns a hash of templates, eg.

```
    use v6.d;
    %(
        format-b => sub ( %prm, %tml --> Str ) {
            qq :to/TMPL/;
                <strong>{ %prm<contents> }</strong>
            TMPL
        },
    )

```
Simplistically, the new value of `format-b` overwrites the previous value.

Actually, `%.tmpl` is not an ordinary hash, but an extended hash so that `%.tmpl<format-b>` accesses the most recent value, but `%.tmpl<format-b>.prior` accesses the next value of the linked list.

The use case of this was to have a plugin that pre-processes headings in order to extract information, but then uses the preceding template to actually render the template. So the rendering the heading is separated from the pre-processing of the heading.

## Combination of RPR and Collection
Collection links together multiple RakuDoc sources using a pipeline of actions, include rendering with RPR.

The idea behind Collection is that information about the entire website (such as a list of files together with their metadata) is added to the Processor by a plugin, and the information is then available when a custom block is encountered in a RakuDoc source file (eg `=Listfiles`).

When a template for the custom block (eg. `=Listfiles`) is called, it can access the custom data that has been attached to the processor instance because the block handler for a Custom block automatically provides the data associated with the block name as one of the parameters to the template.

This also means that block templates cannot access data from other plugins.

## Flaws
*  It turned out that making PRP neutral about the templating engine was not justified. Mustache does not have processing capacity - by design. Mustache was also very slow when handling lots of files as it was difficult to parallise.

*  Initially, highlighting was handled within the code for the `=code` blocks, but then this was spun off into a separate role, and then moved into a plugin. The plugin replaces the default template for code-blocks.

*  A full set of templates, one for each `Pod::Block` type and for rendering structures such as Footnotes, ToC, and Index (glossary), was required before the class instance could be used. But templates can use other templates, and an error has to be thrown when a template is called, but is not declared. So the idea of maintaining a set of default templates seems redundant.

*  It is useful for plugins to modify existing templates, but to be able to call previous ones. Templates are therefore stored as a linked list, but the syntax is not optimal.

*  The original idea was that plugins - at the rendering stage - provide the name of the block, and the template used for the block. Since by default when a RakuDoc file comes across a custom block, RPR calls a template associated with that name, there is no need to specify separately the name of the custom block. This extra information is redundant.

*  The original idea was to allow for plugins to provide new templates that could be used for existing blocks, eg., a quotation para that would be called by the handler for ``Pod::Block::Para``. However, the RakuDoc source has to be changed to add (eg) ``:template<quotation>``, but it could quite easily be changed to have ``=QuotationPara``. So supporting ``:template`` for all blocks is redundant.

*  Although the template mechanism works well and is flexible, there is too much boiler plate for each template. All RakuClosure templates have the form `key =` sub (%prm, %tml) { ... } >.

*  The meta document structures, such as Footnotes, ToC, and glossary (aka index) cannot be easily accessed within templates. A plugin can create custom data which is then available to other templates. So, this would indicate that all meta document structures should be handled in a uniform way with plugins.

*  the module `Pod::To::HTML2` which is distributed with RPR has to simulate the post-processing plugins because RPR only has plugins for the rendering stage. `Collection` has plugins for different stages.

*  Several RakuDoc v1 functions, eg. _Alias_, were not implemented.

## Lessons
*  RPR extensively uses plugins (more later), even though they were not a part of the initial design. Plugins are useful because

	*  They allow for the customisation of blocks. A plugin can be created that adds a template to the existing list. The most recent template added is called first.

	*  Collection, which calls RPR, also uses plugins, but allows for pre-processing and post-processing functions.

		*  Pre-processing is not needed for `Pod::To::HTML` for a standalone file, but it is useful for changing the pathname of an input file (eg., the `docs` directory has `docs/Language/operators.rakudoc` or `docs/Type/IO.rakudoc` but within the sources these files are referenced as `/language/operators` and `/type/IO` - only one part of the source name is changed)

		*  Post-processing is needed for a standalone HTML file, for example, to collect all CSS or JS files specified in different plugins (different custom blocks), or to collect images. Links to the CSS need to be included in the head part of the HTML file.

		*  Data can be collected during processing and passed back to the render for use by later plugins.

	*  Different output formats require additional files, eg., CSS and JS files for HTML. If a custom block exposes an online service (eg. Leaflet maps), then user tokens need to be included with the configuration.

		*  The original idea was to have an Asset cache with RPR in order to manage assets. This was too restrictive and required more knowledge to write a plugin.

		*  All the information for a custom block can be held together by defining a plugin

		*  Plugin information is more conveniently manipulated by pre- or post-processing plugins.

# New design
The render method of an instance of the RakuAST-Render (RR) class transforms a RakuAST statement list (the methods input) into a ProcessedRakuDoc object (returned object).

If the RR instance has not been modified, the Stringification of the ProcessedRakuDoc (RPD) object will be a text version of the RakuDoc source.

The RR instance may be modified by providing one or more templates and data for each component name, in which case stringifying the RPD object will produce a render that is dependent on the templates.

To produce a rendering in an output (eg. HTML), the calling software will

*  create an RR object (the _processor_), eg. `my RakuAST-Render $pocessor .= new ;`

*  attach templates and data to the _processor_,

*  obtain the RakuAST list from the RakuDoc source, eg `my $ast = 'filename'.IO.slurp.AST.rakudoc`

*  obtain a RPD object by calling render on processor, eg. `my $obj = $processor.render($ast)`

*  stringify the RPD object (string output), eg., `my $str = $obj.Str`

*  save the string output as a file

*  save extra assets required (eg. for HTML: image, CSS and JS files in directories consistent with information provided in template files)

## RakuAST-Render (RR) class
### render( RakuAST::Block @list, :%meta --&gt; ProcessedRakuDoc )
Creates a new ProcessedRakuDoc object from the RakuAST::BLock list.

If %meta is given, then the keys/values are added to the source-data structure of the RR object.

### add plugin( Str $path-to-plugin-directory )
TO BE DETERMINED

## ProcessedRakuDoc (RPD) class
### Object structures
*  body (string of rendered source, may contain Promises during rendering)

*  data about the source

	*  this might include

		*  file name

		*  path name

		*  modification time of source file

	*  data about the source can be attached with render, see below)

	*  data about the source may also be generated by templates, eg. meta data attached to rakudoc block

*  the Table of Contents data (from headings and custom blocks),

*  Index (glossary) (from `X<>` markup),

*  Footnotes,

*  Links (internal, local, external), (from `L<>` markup)

	*  Internal are of the form `#this is a heading` and refer to anchors inside the file

	*  Local are of the form `some-type#a heading there`, where _some-type_ is a file name in the same directory

	*  External is a fully qualified URL

*  Targets (generated from block names and :id metadata)

*  Aliases

*  Definitions

*  Semantic blocks (which includes TITLE & SUBTITLE)

*  Unknown templates (by default all components are rendered in some way)

## Class methods
### Str
*  Each of the base structures (Body, ToC, Index, and Footnotes) are rendered to a string using templates of the same name.

*  The base structures are combined using the _Wrap_ template

*  The method returns a string under all circumstances, even if there are errors.

## Verify
It seems to me to be useful to have one method that produces some output, and another that does verification for debugging purposes.

Method should be called before Str, which will emit a string if it can even if there are undefined / incomplete values

Checks the following:

*  Unknown templates structure is empty

*  All the promises in Body have been kept

*  All internal links are satisfied by an element in the targets structure

Throws an exception if any of the above are not true.







----
Rendered from design at 2023-11-02T22:13:58Z