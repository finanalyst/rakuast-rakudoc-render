
# Rendering RakuDoc v2 to HTML

	<span class="para" id="15d0810"></span>RakuDoc v2 is rendered to minimal HTML. `RakuAST::RakuDoc::Render` on which this module is based uses the RakuAST parser. A rendering of the [compliance](#Compliance_testing) document can be [found online](https://htmlpreview.github.io/?https://github.com/finanalyst/rakuast-rakudoc-render/blob/main/resources/compliance-rendering/rakudociem-ipsum.html). 



----

## Table of Contents
<a href="#SYNOPSIS">SYNOPSIS</a>   
<a href="#Vanilla_HTML_and_CSS">Vanilla HTML and CSS</a>   
<a href="#Credits">Credits</a>   


----  

## SYNOPSIS<div id="SYNOPSIS"> </div>


<span class="para" id="30eb8e2"></span>Currently, the module is difficult to install using *zef*, so the instructions below are relative to local repo of [RakuDoc::Render repo](https://github.com/finanalyst/rakuast-rakudoc-render.git). 

<span class="para" id="e47ab22"></span>Use the utility **force-recompile** with the current working directory being the root of the `RakuDoc::Render` repo bin/force-recompile 

<span class="para" id="915319d"></span>Assuming (the assumptions are for clarity and can be changed): 



&nbsp;&nbsp;• <span class="para" id="4991088"></span>there is a RakuDoc source `new-doc.rakudoc` in the current working directory, 

  
&nbsp;&nbsp;• <span class="para" id="0418014"></span>the current working directory is the root directory of the repo, `/home/me/rakuast-rakudoc-render` 

  
&nbsp;&nbsp;• <span class="para" id="e818663"></span>the distribution has been tested on Ubuntu **6.5.0-35-generic #35~22.04.1-Ubuntu** 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ [feedback of testing on other OS, and tweaks to improve, would be appreciated !]  
&nbsp;&nbsp;• <span class="para" id="2bfd9b9"></span>a recent Rakudo build is needed; **v2024.05-34-g5dd0ad6f5** works. 

  
<span class="para" id="54f7ea1"></span>Then: RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=HTML new-doc.rakudoc > new-doc.html 

<span class="para" id="7d4d562"></span>generates **new-doc.html** in the current working directory. 


----

## Vanilla HTML and CSS<div id="Vanilla_HTML_and_CSS"> </div>
<span class="para" id="679a6d0"></span>The aim of `RakuDoc::To::HTML` is to produce a minimal HTML output with minimal styling, and that the file can be directly viewed in a modern browser with the URL `file:///home/me/rakuast-rakudoc-render/new-doc.html`. 

> Unfortunately some systems for opening HTML files in a browser will HTML-escape Unicode characters used for delimiting texts. So, just open the file in a browser.

<span class="para" id="24461c8"></span>The styling is generated from `resources/scss/vanilla.scss` to produce `resources/css/vanilla.css`, which is slurped into the HTML output file (eg. new-doc.html). 

<span class="para" id="83cd7c7"></span>By the design of the `RakuDoc::Render` module, all output is generated using templates. The module `RakuDoc::To::HTML` attaches a minimum set of templates. It is possible to override any or all of the templates by adding the `MORE_HTML` environment variable. Assuming the file `my_new_html.raku` exists in the current working directory, and the file follows the [Template specification](Templates.md), then MORE_HTML=my_new_html.raku RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=HTML new-doc.rakudoc > new-doc.html 

<span class="para" id="1512028"></span>will utilise the new templates. An example can be seen in `xt/600-R-2-HTML.rakutest`. The intention of each template can be found in the comments within `lib.RakuDoc/To/HTML.rakumod`. 

<span class="para" id="4638f6f"></span>To tweak the styling: 



&nbsp;&nbsp;• <span class="para" id="90829df"></span>install [sass is available](https://sass-lang.com/guide/) 

  
&nbsp;&nbsp;• <span class="para" id="84ba3a3"></span>copy the file `/home/me/rakuast-rakudoc-render/resources/scss/vanilla.scss` to a new file, eg. `~/tweaks/strawberry.scss` 

  
&nbsp;&nbsp;• tweak the styling (many classes used in the HTML output have zero styling)  
&nbsp;&nbsp;• <span class="para" id="4458d47"></span>run `sass ~/tweaks/strawberry.scss` to generate `~/tweaks/strawberry.css` 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span class="para" id="58fb44d"></span>the `sass` command is usefully run as `--update -s compressed ~/tweaks/strawberry.scss` 

  
&nbsp;&nbsp;• <span class="para" id="a4d2021"></span>use the `ALT_CSS` environment variable to load the new CSS. 

  

```
ALT_CSS=~/tweaks/strawberry.sss RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=HTML new-doc.rakudoc > new-doc.html
```
<span class="para" id="1683933"></span>Both `ALT_CSS` and `MORE_HTML` can be used, adding new HTML tags, or changing class names, then including CSS definitions in the file accessed by `ALT_CSS`. 

<span class="para" id="818d78b"></span>Note that there is a difference between how the CSS and Template files are used. 



&nbsp;&nbsp;• <span class="para" id="0e27b56"></span>By design, new Raku closure templates, eg, those defined in files given to `MORE_HTML`, are placed at the head of a chain of templates, and so are *in addition* to those previously defined. 

  
&nbsp;&nbsp;• <span class="para" id="62fe5cd"></span>The alternate CSS file (eg ~/tweaks/strawberry.css) is used **instead** of the default `vanilla.css`. 

  
<div id="Credits"> </div>

｢semantic-schema_AUTHOR UNAVAILABLE｣

<div id="Placement"> </div>

----  

## VERSION<div id="VERSION"> </div>
v0.1.0







----

----

Rendered from docs/docs/RakuDoc-To-HTML.rakudoc at 23:08 UTC on 2024-07-14

Source last modified at 20:48 UTC on 2024-07-06


