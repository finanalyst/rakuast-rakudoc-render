        # Templates for RakuDoc-Render
>Snippets to customise RakuDoc blocks


## Table of Contents
[Overview](#overview)  
[Templates](#templates)  
[Custom data](#custom-data)  
[Template object](#template-object)  
[method $tmpl.prev](#method-tmplprev)  
[Calling a helper callable](#calling-a-helper-callable-0)  
[Calling another defined template](#calling-another-defined-template)  
[Template information and debugging](#template-information-and-debugging)  
[.debug attribute](#debug-attribute)  
[Verbose output of one template](#verbose-output-of-one-template)  
[The .test attribute](#the-test-attribute)  
[The .pretty attribute](#the-pretty-attribute)  

----
# Overview
RakuDoc-Render (RR) uses _plugins_ to customise blocks. A plugin will add custom data and templates to an instance of an RR **processor**.

The templates are added to an instance of the **Template-directory** class held within the _processor_.

The custom data is also added to the _processor_'s **Template-directory** object.

Helper callables that can be used inside a template can also be added to the _processor_'s **Template-directory** object.

Within a template, all the registered templates, the custom data of the _processor_, and the helper callables can be accessed. See [helper callables](calling-a-helper-callable) for more information.

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

# Template information and debugging
Four attributes can be set on a `Template-directory` object to aid with debugging templates, especially when templates have content that is derived from other templates:

*  **debug**

*  **verbose**

*  **test**

*  **pretty**

## `.debug` attribute
When set to True, eg

my Template-directory %template-dir; # assign some templates to %template-dir %template-dir.debug = True;

information about the name of the template being used, and the source of the template is sent to STDOUT via `say`. This is used by the `debug(Templates)` command in a `Rakudoc::Processor` object.

The information generated is for the registered template, not to be confused with the `.test` or `.pretty` attributes.

## Verbose output of one template
The `Template-directory` class has a `.verbose` attribute. When set to a string corresponding to the name of a template, eg.

my Template-directory %template-dir = %( one => -> %prm, $tml { 'Hello world' }, two => -> %prm, $tml { 'Not again' }, ); # later ... %template-dir.verbose = 'one';

the verbose result of that template (eg. 'one') will be sent to STDOUT via `say`.

The output of only one template at a time is supported at the moment.

## The `.test` attribute
When this attribute is set for the Template-directory object, eg.

my Template-directory %template-dir; # assign some templates to %template-dir %template-dir = %( aaa => -> %prm, $tmpl { 'orig: ' ~ %prm<contents>; }, ggg =. -> %prm, $tmpl { %prm<contents> = 'Chapter ' ~ %prm<contents> } ); %template-dir.test = True;

In order to test the template with a set of unit tests, it is important for the results of the template to be uniform and predictable.

Also the renderer will call the template with options defined at run time, eg., because of a `=config` directive.

The output from a template when `test` is True does not depend on the block registered with the template. Instead, all the options (which may include the output from other templates) are returned in alphabetical order.

For example, the result of calling the templates defined above, with `test=True`, where the output from one template is contained in another, will be:

say %template-dir<aaa>(%( :contents<something>, ggg => %template-dir<ggg>(%(:contents<more stiff>,)), )); # output <aaa> contents: ｢something｣ ggg: ｢<ggg> contents: ｢more stiff｣ </ggg> ｣ </aaa>

It does not matter _how_ the templates were defined, but it does matter that they **were** defined. Calling a template that is not registered in the **Templated-directory** object will cause an error.

## The `.pretty` attribute
When this attribute is set for the Template-directory object, eg.

my Template-directory %template-dir; # assign some templates to %template-dir %template-dir = %( aaa => -> %prm, $tmpl { 'orig: ' ~ %prm<contents>; }, ggg =. -> %prm, $tmpl { %prm<contents> = 'Chapter ' ~ %prm<contents> } ); %template-dir.pretty = True;

the output is similar to the `.test` attribute, which it overrides, but white space is added to make the content structure clearer.

For example,

say %template-dir<aaa>(%( :contents<something>, array => <one two three four>, hash => ( <eight nine ten> Z=> 1..* ).hash, )); # output produced <aaa> array: ｢List=( "one", "two", "three", "four" )｣ contents: ｢something｣ hash: ｢Hash={ :eight(1), :nine(2), :ten(3) }｣ </aaa>







----
Rendered from Templates at 2024-06-11T15:33:23Z