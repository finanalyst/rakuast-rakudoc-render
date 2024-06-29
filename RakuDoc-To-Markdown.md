
# Rendering RakuDoc v2 to MarkDown

	Simple and customisable module for rendering RakuDoc v2 to Markdown.

----

## Table of Contents
<a href="#SYNOPSIS">SYNOPSIS</a>   
<a href="#Overview">Overview</a>   
<a href="#Customising_templates">Customising templates</a>   
<a href="#RenderDocs_utility">RenderDocs utility</a>   
<a href="#Credits">Credits</a>   


----  

## SYNOPSIS<div id="SYNOPSIS"> </div>
<span class="para" id="9ce3ef6"></span>To render a RakuDoc source, eg. *some-docs.rakudoc*, into *some-docs.md*, either use the terminal command 


```
RAKUDO_RAKUAST=1 raku --rakudoc=Markdown some-docs.rakudoc > some-docs.md
```
<span class="para" id="7d095b1"></span>or (see [below for more detail](#RenderDocs_utility)) 


```
bin/RenderDocs some-docs
```
<span class="para" id="5beec09"></span>There is a section on Troubleshooting in the [general README file](README.md) if this fails. 




----

## Overview<div id="Overview"> </div>
<span class="para" id="5324901"></span>Markdown representation of documentation is widespread, so a simple conversion (rendering) of the RakuDoc v2 into Markdown is useful, even though Markdown is intended to be viewed as HTML. 

<span class="para" id="372c900"></span>The module can be customised by setting an Environment variable to a template file. [More detail on customising](Customising templates.md). 

<span class="para" id="3454017"></span>The general [README file should be read first](README.md). 

<span class="para" id="e581a66"></span>For this description, it is assumed that the *RakuAST::RakuDoc::Render* distribution is **NOT** installed using zef, although it can be. Consequently, all commands are assumed to be inside the repo directory root. 


----

## Customising templates<div id="Customising_templates"> </div>
<span class="para" id="bffb7ca"></span>All output from *Rakuast::RakuDoc::Render* modules is generated through templates. These templates can be added to, without overriding the previous templates, ([see Templates for detail](Templates.md)). 

<span class="para" id="9b20e8e"></span>If a file exists in the local directory called *new-temp.raku* and conforms to the requirements described in [Templates](Templates.md), then the templates in it will be added to the generic Markdown templates as follows: 


```
MORE_MARKDOWN=new-temp.raku RAKUDO_RAKUAST=1 raku --rakudoc=Markdown some-docs.rakudoc > store.md
```
<span class="para" id="3cb3c43"></span>For instance if the contents of *new-temp.raku* is 


```
%(
        final => -> %prm, $tmpl { "# Customisation message\n\n" ~ $tmpl.prev }
    )
```
<span class="para" id="2b90223"></span>Then after running the command above, **store.md** will contain a new title at the top, followed by the remainder of the Markdown as rendered before the new template was added. 

<span class="para" id="d4da3b3"></span>Some notes: 



&nbsp;&nbsp;• <span class="para" id="3e7a71d"></span>The template `final` is the last one that *glues* all the documentation together into a string. 

  
&nbsp;&nbsp;• <span class="para" id="20e9363"></span>`$tmpl.prev` is call to the previous version of `final` with all the parameters passed on. 

  
&nbsp;&nbsp;• <span class="para" id="c1ac060"></span>All the generic templates are [tabulated with comments](default-text-templates.md). 

  

----

## RenderDocs utility<div id="RenderDocs_utility"> </div>
<span class="para" id="3881f89"></span>A utility called **RenderDocs** accompanies the distribution. It is assumed that documentation sources in RakuDoc are contained in the sub-directory `docs/` and that Markdown versions are required in the working directory. If any RakuDoc source has a modified date later than the current version of the Markdown output, then the Markdown file is updated. 

<span class="para" id="773bcc7"></span>Usage 


```
bin/RenderDocs
```
<span class="para" id="a78f96c"></span>More granularity can be obtained by specifying a single file and a *to* destination, eg. 


```
bin/RenderDocs --to=README docs/README
```
<span class="para" id="4e993d8"></span>Here, there must be a file `docs/README.rakudoc`, which is rendered to the current working directory as *README.md*. 

<div id="Credits"> </div>

----  

## AUTHOR<div id="AUTHOR"> </div>
Richard Hainsworth, aka finanalyst



<div id="Placement"> </div>

----  

## VERSION<div id="VERSION"> </div>
v0.1.0







----

----

Rendered from ./docs/./docs/RakuDoc-To-Markdown.rakudoc at 22:06 UTC on 2024-06-29

Source last modified at 22:06 UTC on 2024-06-29


