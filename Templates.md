        # Templates for RakuDoc-Render
>Snippets to customise RakuDoc blocks


## Table of Contents
[Overview](#overview)  
[Templates](#templates)  
[Custom data](#custom-data)  
[Template object](#template-object)  
[method $tmpl.prev](#method-tmplprev)  
[Calling a helper callable](#calling-a-helper-callable)  
[Calling another defined template](#calling-another-defined-template)  
[PStr class and concatenation](#pstr-class-and-concatenation)  
[Concatenation to PStr](#concatenation-to-pstr)  
[Template methods lead and tail](#template-methods-lead-and-tail)  
[Predefined templates](#predefined-templates)  

----
# Overview
RakuDoc-Render (RR) uses _plugins_ to customise blocks. A plugin will add custom data and templates to an instance of an RR **processor**.

The templates are added to an instance of the **Template-directory** class held within the _processor_.

The custom data is also added to the _processor_'s **Template-directory** object.

Helper callables that can be used inside a template can also be added to the _processor_'s **Template-directory** object.

Within a template, all the registered templates, the custom data of the _processor_, and the helper callables can be accessed. The helper callables, such as `name-id` which is used to name internal links, may be output format sensitive, and so should be added after the _Processor_ has been instantiated.

When a template is added to a _Template-directory_ and the template name already exists, the old value is pushed onto a stack, and can be accessed.

A generic RakuDoc::Processor will populate the _Template-directory_ with text templates that then served as the generic defaults.

When a template is added to the directory, the `source` attribute on the **Template-directory** is set, and copied into each template. In this way, the origin of a template can be traced.

When the `debug` attribute on the **Template-directory** is True, the name and origin of each Template is reported whenever a Template is called.

# Templates
A _Template-directory_ object is an extended Hash structure.

Templates are specified as a list of Pairs of the form

```
    # psuedocode
    <key> => -> <Hash>, <Template object> <Block>
    # or as an example
    head => -> %prm, $tmpl { ... }

```
where

*  key is a string and serves as the name of the template

*  `%prm` is an ordinary Hash of the parameters that are accessed inside the block

	*  In order to access 'contents', the code inside the block would be `%prm<contents> `

	*  The name of the Hash parameter is arbitrary, but conventionally is called `%prm`.

*  `$tmpl` is a _Template_ object, see below, and conventionally is called `$tmpl`.

*  The contents of the block is a normal Raku program and should return a Str or PStr (see below).

	*  The block shown above is the _pointy_ form, so the object returned is the value of the last statement

	*  If the Raku program in the block is more easily written using a `return` statement, then a `sub` form should be used, eg.

key => sub ( %prm, $tmpl ) { ... }

# Custom data
A _Template-directory_ object also has a `%.data ` structure, which is intended for use by plugins that need to make extra data available for templates.

For example, suppose a custom block is written to include data about all the documents in a website, and the information is collected into a structure called `%files`, which is to be available to the template `listfiles`, then we could have

```
    my %temp-dir is Target-directory = listfile => -> %prm, $tmpl {
        my %file-data = $tmpl.globals.data<listfiles>
        # code to create the output string using the data
    }

    # somewhere later
    %temp-dir.data<listfiles> = %files;
    # use the template
    my $rv = %temp-dir<listfile>;

```
The `%temp-dir` object, which is an instance of the _Template-directory_ class, provides access to the data through the `.globals` attribute of the _Template_ object.

# Template object
The Template object contains a reference to the Template-directory object, so all the templates registered with the RakuDoc processor, and all the data attached to it, can be accessed.

Inside the Raku block of a new template, the following methods can be used on the `$tmpl` object.

## method **$tmpl.prev**
This calls the previously defined block of the template with the same name, with the same parameters provided to current block. The use case is to allow some pre- and (limited) post- processing of the parameters while keeping the previous template.

**Pre-processing** Suppose a new template is required that merely adds the word 'Chapter' to the contents of a `=Chapter` block. So the parameter needs to be preprocessed and the previous template called. Assuming %prm<contents> is a Str.

chapter => -> %prm, $tmpl { %prm<contents> = 'Chapter ' ~ %prm<contents>; $tmpl.prev( %prm ); # pass the new value of contents }

**Post-processing** For example, suppose a template 'table' has been defined, but a new template is needed that substitutes the HTML class, then some post-processing of the old template is sufficient, eg.,

table => -> %prm, $tmpl { ($tmpl.prev).subst( / '<table' \s+ 'class="pod-table' /, '<table class="table is-centered') }

This assumes that the return object from both templates _chapter_ and _table_ is a Str, which it could be. But generically, it is best not to assume this. A fuller example is given below.

## Calling a helper callable
Suppose a template generates objects that need to be added to the Table of Contents (ToC). The ToC structure is collected by the Renderer leaf by leaf, and the order of the leaf data is constructed because the order of the ToC is important.

So the code in the template block can call

$tmpl.globals.helper<add-to-toc>( :caption<...>, :target<...>, :level(1) )

## Calling another defined template
The block registered with key `aaa` can be called inside another template block, with or without parameters.

_Without parameters_, eg `$tmpl<aaa>` or **$tmpl('aaa')** the other template block is called with the same parameters, eg

page => -> %prm, $tmpl { $tmpl<header> ~ $tmpl<body> ~ $tmpl<footer> } where `header`, `body`, and `footer` are all registered in the _RR_ processor.

_With parameters_, eg. `$tmpl('aaa', %( :attr(1), :new-attr<some string> ) )`, the block registered with the key `aaa` is called with the new set of parameters specified in the Hash. It can be used to provide a subset of parameters, or to rename the parameters for a different template.

# PStr class and concatenation
Some RakuDoc statements make references to structures or data that have not been completely rendered. These references are embedded in **PCells**, which contain supplies that will interpolate the rendering once known.

Consequently, parameters to a template may contain a mixture of Raku _Str_ and _PCells_, in an object of type called **PStr**.

_PCells_ should not be visible to the template user.

If a _PStr_ or _PCell_ is stringified before the data has been rendered, its internal _id_ and _UNAVAILABLE_ will be the rendered result.

Since the embedded content of a _PStr_ may ony be available after a template has rendered, care must be taken not be stringify any of the parameters prematurely.

Consequently, the return object from a template should be built from the parameter values using the concatenation operator `~`.

## Concatenation to PStr
A PStr is built up by concatenating using the infix operator `~`. Assignment does not add to a PStr. Concatenation can be on the left or the right of the PStr and the result will depend on the type.

*  A PCell on the left or right is added to the start or end, respectively, of the PStr

*  Concatentating two PStr adds the right hand one to the left hand one, and returns the left hand one

*  Any other type on the left or right is coerced to a Str and added to the start/end of the PStr

Since left concatenation has an effect on the PStr on the right, use `sink` to discard the return value, unless of course the return value is the last line of a block, in which case it is returned as the value of the block, eg.,

my PStr $p; $p ~= PCell.new( :s($a-supplier.Supply), :id<AAA> ); sink '<bold>' ~ $p

## Template methods **lead** and **tail**
These two methods of a _PStr_ object return any of the **leading** or **tailing** (respectively) _Str_ elements of the _PStr_. The elements are removed, and so should be concatenated back on after processing.

For simplicity above, examples were given of pre- and post-processing templates, and treating the contents of `%prm` as _Str_. Since some parameters may contain _PStr_, more care is needed. For example, the post-processing should be done as follows:

table => -> %prm, $tmpl { my $rv = $tmpl.prev; if $rv ~~ PStr { # get leading text my $lead = $rv.lead; # process the string, if it exists $lead.subst( / '<table' \s+ 'class="pod-table' /, '<table class="table is-centered'); # left concatenate onto the PStr $lead ~ $rv # concatenating to a PStr results in a PStr, which is the return object } else { $rv.subst( / '<table' \s+ 'class="pod-table' /, '<table class="table is-centered') } }

# Predefined templates
`RakuAST::Render` defines a number of templates for Text output. These will be the fall-back templates when more specialist renderers add new templates to the Template Directory.

Since it is anticipated that the output Text templates will be modified over time to match changing preferences, it is best for another set of minimal templates be used to test the module. Consequently, a different set of text templates is used when a `RakuDoc::Processor` object is instantiated as `$rpp .= new(:test)`.

The special template `_name` is used to distinguish between test and default templates, and can be used to check that that a new Renderer has loaded its templates.

Information about both sets of templates are listed in the generated files [default-text-templates](/default-text-templates.md) and [test-text-templates](/test-text-templates.md).







----
Rendered from Templates at 2024-01-30T21:15:28Z