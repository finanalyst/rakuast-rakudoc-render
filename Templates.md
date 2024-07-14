
# Templates for RakuDoc-Render

	Snippets to customise RakuDoc blocks

----

## Table of Contents
<a href="#Overview">Overview</a>   
<a href="#Templates">Templates</a>   
<a href="#Custom_data">Custom data</a>   
<a href="#Template_object">Template object</a>   
&nbsp;&nbsp;- <a href="#<span_class="para"_id="fb491c6"></span>method_**$tmpl.prev**"><span class="para" id="fb491c6"></span>method **$tmpl.prev** 

</a>   
&nbsp;&nbsp;- <a href="#Calling_a_helper_callable">Calling a helper callable</a>   
&nbsp;&nbsp;- <a href="#Calling_another_defined_template">Calling another defined template</a>   
<a href="#Template_information_and_debugging">Template information and debugging</a>   
&nbsp;&nbsp;- <a href="#<span_class="para"_id="71d192b"></span>`.debug`_attribute"><span class="para" id="71d192b"></span>`.debug` attribute 

</a>   
&nbsp;&nbsp;- <a href="#Verbose_output_of_one_template">Verbose output of one template</a>   
&nbsp;&nbsp;- <a href="#<span_class="para"_id="2aad8a1"></span>The_`.test`_attribute"><span class="para" id="2aad8a1"></span>The `.test` attribute 

</a>   
&nbsp;&nbsp;- <a href="#<span_class="para"_id="00a6e3c"></span>The_`.pretty`_attribute"><span class="para" id="00a6e3c"></span>The `.pretty` attribute 

</a>   
<a href="#Credits">Credits</a>   



----

## Overview<div id="Overview"> </div>
<span class="para" id="16273bd"></span>RakuDoc-Render (RR) uses *plugins* to customise blocks. A plugin will add custom data and templates to an instance of an RR **processor**. 

<span class="para" id="fee5367"></span>The templates are added to an instance of the **Template-directory** class held within the *processor*. 

<span class="para" id="bea7637"></span>The custom data is also added to the *processor*'s **Template-directory** object. 

<span class="para" id="b7bcc7f"></span>Helper callables that can be used inside a template can also be added to the *processor*'s **Template-directory** object. 

<span class="para" id="4cb8052"></span>Within a template, all the registered templates, the custom data of the *processor*, and the helper callables can be accessed. See [helper callables](#Calling_a_helper_callable) for more information. 

<span class="para" id="6456d29"></span>When a template is added to a *Template-directory* and the template name already exists, the old value is pushed onto a stack, and can be accessed. 

<span class="para" id="d340a31"></span>A generic RakuDoc::Processor will populate the *Template-directory* with text templates that then served as the generic defaults. 

<span class="para" id="34ef685"></span>When a template is added to the directory, the `source` attribute on the **Template-directory** is set, and copied into each template. In this way, the origin of a template can be traced. 

<span class="para" id="afe59bc"></span>When the `debug` attribute on the **Template-directory** is True, the name and origin of each Template is reported whenever a Template is called. 


----

## Templates<div id="Templates"> </div>
<span class="para" id="6b6bf40"></span>A *Template-directory* object is an extended Hash structure. 

<span class="para" id="4b68c2d"></span>Templates are specified as a list of Pairs of the form 


```
    # psuedocode
    <key> => -> <Hash>, <Template object> <Block>
    # or as an example
    head => -> %prm, $tmpl { ... }
```
<span class="para" id="0bef7be"></span>where 



&nbsp;&nbsp;• key is a string and serves as the name of the template  
&nbsp;&nbsp;• <span class="para" id="f4cf6d0"></span>`%prm` is an ordinary Hash of the parameters that are accessed inside the block 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="3221c4b"></span>In order to access 'contents', the code inside the block would be ` %prm<contents> ` 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="74b272c"></span>The name of the Hash parameter is arbitrary, but conventionally is called `%prm`. 

  
&nbsp;&nbsp;• <span class="para" id="0d1de71"></span>`$tmpl` is a *Template* object, see below, and conventionally is called `$tmpl`. 

  
&nbsp;&nbsp;• The contents of the block is a normal Raku program and should return a Str or PStr (see below).  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="a9d27a4"></span>The block shown above is the *pointy* form, so the object returned is the value of the last statement 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="fe16584"></span>If the Raku program in the block is more easily written using a `return` statement, then a `sub` form should be used, eg. 

  

```
key => sub ( %prm, $tmpl ) { ... }
```

----

## Custom data<div id="Custom_data"> </div>
<span class="para" id="b5568ea"></span>A *Template-directory* object also has a ` %.data ` structure, which is intended for use by plugins that need to make extra data available for templates. 

<span class="para" id="54820c5"></span>For example, suppose a custom block is written to include data about all the documents in a website, and the information is collected into a structure called `%files`, which is to be available to the template `listfiles`, then we could have 


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
<span class="para" id="6842261"></span>The `%temp-dir` object, which is an instance of the *Template-directory* class, provides access to the data through the `.globals` attribute of the *Template* object. 


----

## Template object<div id="Template_object"> </div>
<span class="para" id="7392f1d"></span>The Template object contains a reference to the Template-directory object, so all the templates registered with the RakuDoc processor, and all the data attached to it, can be accessed. 

<span class="para" id="783cfdb"></span>Inside the Raku block of a new template, the following methods can be used on the `$tmpl` object. 



### <span class="para" id="fb491c6"></span>method **$tmpl.prev** 

<div id="<span_class="para"_id="fb491c6"></span>method_**$tmpl.prev**"> </div>
<span class="para" id="87631bf"></span>This calls the previously defined block of the template with the same name, with the same parameters provided to current block. The use case is to allow some pre- and (limited) post- processing of the parameters while keeping the previous template. 

<span class="para" id="e422cd9"></span>**Pre-processing** Suppose a new template is required that merely adds the word 'Chapter' to the contents of a `=Chapter` block. So the parameter needs to be preprocessed and the previous template called. Assuming %prm<contents> is a Str. 


```
chapter => -> %prm, $tmpl {
    %prm<contents> = 'Chapter ' ~ %prm<contents>;
    $tmpl.prev( %prm ); # pass the new value of contents
}
```
<span class="para" id="a8d4b99"></span>**Post-processing** For example, suppose a template 'table' has been defined, but a new template is needed that substitutes the HTML class, then some post-processing of the old template is sufficient, eg., 


```
table => -> %prm, $tmpl {
    ($tmpl.prev).subst( / '<table' \s+ 'class="pod-table' /, '<table class="table is-centered')
}
```
<span class="para" id="9d290c9"></span>This assumes that the return object from both templates *chapter* and *table* is a Str, which it could be. But generically, it is best not to assume this. A fuller example is given below. 



### Calling a helper callable<div id="Calling_a_helper_callable"> </div>
<span class="para" id="4b3a0a2"></span>Suppose a template generates objects that need to be added to the Table of Contents (ToC). The ToC structure is collected by the Renderer leaf by leaf, and the order of the leaf data is constructed because the order of the ToC is important. 

<span class="para" id="e30c0a1"></span>So the code in the template block can call 


```
$tmpl.globals.helper<add-to-toc>(
    :caption<...>, :target<...>, :level(1)
)
```


### Calling another defined template<div id="Calling_another_defined_template"> </div>
<span class="para" id="4dc802d"></span>The block registered with key `aaa` can be called inside another template block, with or without parameters. 

<span class="para" id="3b2f9fc"></span>*Without parameters*, eg `$tmpl<aaa>` or **$tmpl('aaa')** the other template block is called with the same parameters, eg 


```
page => -> %prm, $tmpl {
    $tmpl<header> ~ $tmpl<body> ~ $tmpl<footer>
}
```
<span class="para" id="33bdd01"></span>where `header`, `body`, and `footer` are all registered in the *RR* processor. 

<span class="para" id="a388872"></span>*With parameters*, eg. `$tmpl('aaa', %( :attr(1), :new-attr<some string> ) )`, the block registered with the key `aaa` is called with the new set of parameters specified in the Hash. It can be used to provide a subset of parameters, or to rename the parameters for a different template. 


----

## Template information and debugging<div id="Template_information_and_debugging"> </div>
<span class="para" id="ef7381f"></span>Four attributes can be set on a `Template-directory` object to aid with debugging templates, especially when templates have content that is derived from other templates: 



&nbsp;&nbsp;• <span class="para" id="64be8b8"></span>**debug** 

  
&nbsp;&nbsp;• <span class="para" id="81a043b"></span>**verbose** 

  
&nbsp;&nbsp;• <span class="para" id="652e542"></span>**test** 

  
&nbsp;&nbsp;• <span class="para" id="3695f4e"></span>**pretty** 

  


### <span class="para" id="71d192b"></span>`.debug` attribute 

<div id="<span_class="para"_id="71d192b"></span>`.debug`_attribute"> </div>
<span class="para" id="6df5498"></span>When set to True, eg 


```
my Template-directory %template-dir;
# assign some templates to %template-dir
%template-dir.debug = True;
```
<span class="para" id="1491ac1"></span>information about the name of the template being used, and the source of the template is sent to STDOUT via `say`. This is used by the `debug(Templates)` command in a `Rakudoc::Processor` object. 

<span class="para" id="ca14fb0"></span>The information generated is for the registered template, not to be confused with the `.test` or `.pretty` attributes. 



### Verbose output of one template<div id="Verbose_output_of_one_template"> </div>
<span class="para" id="bc6e72f"></span>The `Template-directory` class has a `.verbose` attribute. When set to a string corresponding to the name of a template, eg. 


```
my Template-directory %template-dir = %(
    one => -> %prm, $tml { 'Hello world' },
    two => -> %prm, $tml { 'Not again' },
);
# later ...
%template-dir.verbose = 'one';
```
<span class="para" id="15b5744"></span>the verbose result of that template (eg. 'one') will be sent to STDOUT via `say`. 

<span class="para" id="7467f30"></span>The output of only one template at a time is supported at the moment. 



### <span class="para" id="2aad8a1"></span>The `.test` attribute 

<div id="<span_class="para"_id="2aad8a1"></span>The_`.test`_attribute"> </div>
<span class="para" id="7428fee"></span>When this attribute is set for the Template-directory object, eg. 


```
my Template-directory %template-dir;
# assign some templates to %template-dir
%template-dir = %(
    aaa => -> %prm, $tmpl {
        'orig: ' ~ %prm<contents>;
    },
    ggg =. -> %prm, $tmpl {
        %prm<contents> = 'Chapter ' ~ %prm<contents>
    }
);
%template-dir.test = True;
```
<span class="para" id="24396e2"></span>In order to test the template with a set of unit tests, it is important for the results of the template to be uniform and predictable. 

<span class="para" id="bcd7449"></span>Also the renderer will call the template with options defined at run time, eg., because of a `=config` directive. 

<span class="para" id="bdf6cb5"></span>The output from a template when `test` is True does not depend on the block registered with the template. Instead, all the options (which may include the output from other templates) are returned in alphabetical order. 

<span class="para" id="d0ece4e"></span>For example, the result of calling the templates defined above, with `test=True`, where the output from one template is contained in another, will be: 


```
say %template-dir<aaa>(%(
    :contents<something>,
    ggg => %template-dir<ggg>(%(:contents<more stiff>,)),
));
# output
<aaa>
contents: ｢something｣
ggg: ｢<ggg>
contents: ｢more stiff｣
</ggg>
｣
</aaa>
```
<span class="para" id="67ac437"></span>It does not matter *how* the templates were defined, but it does matter that they **were** defined. Calling a template that is not registered in the **Templated-directory** object will cause an error. 



### <span class="para" id="00a6e3c"></span>The `.pretty` attribute 

<div id="<span_class="para"_id="00a6e3c"></span>The_`.pretty`_attribute"> </div>
<span class="para" id="7428fee"></span>When this attribute is set for the Template-directory object, eg. 


```
my Template-directory %template-dir;
# assign some templates to %template-dir
%template-dir = %(
    aaa => -> %prm, $tmpl {
        'orig: ' ~ %prm<contents>;
    },
    ggg =. -> %prm, $tmpl {
        %prm<contents> = 'Chapter ' ~ %prm<contents>
    }
);
%template-dir.pretty = True;
```
<span class="para" id="fe9e68f"></span>the output is similar to the `.test` attribute, which it overrides, but white space is added to make the content structure clearer. 

<span class="para" id="c976c61"></span>For example, 


```
say %template-dir<aaa>(%(
    :contents<something>,
    array => <one two three four>,
    hash => ( <eight nine ten> Z=> 1..* ).hash,
));
# output produced
<aaa>
  array: ｢List=(
        "one",
        "two",
        "three",
        "four"
  )｣
  contents: ｢something｣
  hash: ｢Hash={
        :eight(1),
        :nine(2),
        :ten(3)
  }｣
</aaa>
```
<div id="Credits"> </div>

----  

## AUTHOR<div id="AUTHOR"> </div>
Richard Hainsworth aka finanalyst



<div id="Placement"> </div>

----  

## VERSION<div id="VERSION"> </div>
v0.2.1







----

----

Rendered from docs/docs/Templates.rakudoc at 23:08 UTC on 2024-07-14

Source last modified at 20:48 UTC on 2024-07-06


