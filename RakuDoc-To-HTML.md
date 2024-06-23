
# Rendering RakuDoc v2 to HTML

	<span id="506b2f3ea9c2ce5b60471bdf0b07f2316343fc79"></span>RakuDoc v2 is rendered to minimal HTML. `RakuAST::RakuDoc::Render` on which this module is based uses the RakuAST parser. A rendering of the [compliance](Compliance_testing) document can be [found online](https://htmlpreview.github.io/?https://github.com/finanalyst/rakuast-rakudoc-render/blob/main/resources/compliance-rendering/rakudociem-ipsum.html). 



----

## Table of Contents
<a href="#SYNOPSIS">SYNOPSIS</a>   
<a href="#Vanilla_HTML_and_CSS">Vanilla HTML and CSS</a>   
<a href="#Credits">Credits</a>   


----

## SYNOPSIS<div id="SYNOPSIS"> </div>


<span id="528904e32fdac24900b98d3b23e9e666130eb8e2"></span>Currently, the module is difficult to install using *zef*, so the instructions below are relative to local repo of [RakuDoc::Render repo](https://github.com/finanalyst/rakuast-rakudoc-render.git). 

<span id="41683912915d606e7c065baae2242edf6e47ab22"></span>Use the utility **force-recompile** with the current working directory being the root of the `RakuDoc::Render` repo bin/force-recompile 

<span id="431b673bca92a794ea48a91b929ac2c10915319d"></span>Assuming (the assumptions are for clarity and can be changed): 



&nbsp;&nbsp;• <span id="1a27ea2e495608ba67089bd1a31efafee4991088"></span>there is a RakuDoc source `new-doc.rakudoc` in the current working directory, 

  
&nbsp;&nbsp;• <span id="db77de79af9a897eee35ae09272ea4b610418014"></span>the current working directory is the root directory of the repo, `/home/me/rakuast-rakudoc-render` 

  
&nbsp;&nbsp;• <span id="da50c45f60c573e8d4845a69aa807f536e818663"></span>the distribution has been tested on Ubuntu **6.5.0-35-generic #35~22.04.1-Ubuntu** 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ [feedback of testing on other OS, and tweaks to improve, would be appreciated !]  
&nbsp;&nbsp;• <span id="36405eda9a5680b1a62cc6fe74aac06602bfd9b9"></span>a recent Rakudo build is needed; **v2024.05-34-g5dd0ad6f5** works. 

  
<span id="06d17a009e5228b84551055ed5ca85e2c54f7ea1"></span>Then: RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=HTML new-doc.rakudoc > new-doc.html 

<span id="e3c06c02661f8b964187bbc97ac8304297d4d562"></span>generates **new-doc.html** in the current working directory. 

----

## Vanilla HTML and CSS<div id="Vanilla_HTML_and_CSS"> </div>
<span id="6796444e237a03bce9e95c0aa965cb1df679a6d0"></span>The aim of `RakuDoc::To::HTML` is to produce a minimal HTML output with minimal styling, and that the file can be directly viewed in a modern browser with the URL `file:///home/me/rakuast-rakudoc-render/new-doc.html`. 

> Unfortunately some systems for opening HTML files in a browser will HTML-escape Unicode characters used for delimiting texts. So, just open the file in a browser.

<span id="bf1b1aa499b175e9a7c9aeb6cf6a0e1de24461c8"></span>The styling is generated from `resources/scss/vanilla.scss` to produce `resources/css/vanilla.css`, which is slurped into the HTML output file (eg. new-doc.html). 

<span id="728afe1eb3ca0917c05522a7c02af5b9f83cd7c7"></span>By the design of the `RakuDoc::Render` module, all output is generated using templates. The module `RakuDoc::To::HTML` attaches a minimum set of templates. It is possible to override any or all of the templates by adding the `MORE_HTML` environment variable. Assuming the file `my_new_html.raku` exists in the current working directory, and the file follows the [Template specification](Templates.md), then MORE_HTML=my_new_html.raku RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=HTML new-doc.rakudoc > new-doc.html 

<span id="d3ec056475a6fde26e76c6ac55ceb1bc61512028"></span>will utilise the new templates. An example can be seen in `xt/600-R-2-HTML.rakutest`. The intention of each template can be found in the comments within `lib.RakuDoc/To/HTML.rakumod`. 

<span id="2ac1dd3a597be6a901f8a098e9c49618c4638f6f"></span>To tweak the styling: 



&nbsp;&nbsp;• <span id="9f6708fe6a6611590032410b7dffef36d90829df"></span>install [sass is available](https://sass-lang.com/guide/) 

  
&nbsp;&nbsp;• <span id="347780be6ac8d40948fbf0f03078e346e84ba3a3"></span>copy the file `/home/me/rakuast-rakudoc-render/resources/scss/vanilla.scss` to a new file, eg. `~/tweaks/strawberry.scss` 

  
&nbsp;&nbsp;• tweak the styling (many classes used in the HTML output have zero styling)  
&nbsp;&nbsp;• <span id="4d6a97b8336a6bb645807365e1b15208e4458d47"></span>run `sass ~/tweaks/strawberry.scss` to generate `~/tweaks/strawberry.css` 

  
&nbsp;&nbsp;&nbsp;&nbsp;▹ <span id="d777ed304fc402ec7e1741579b013fd7958fb44d"></span>the `sass` command is usefully run as `--update -s compressed ~/tweaks/strawberry.scss` 

  
&nbsp;&nbsp;• <span id="26969e949f2d88dea5685bb1be2694dc8a4d2021"></span>use the `ALT_CSS` environment variable to load the new CSS. 

  

```
<span id="8618e26f94484888a049bd6f7bc57b5aeca6e2d2"></span>ALT_CSS=~/tweaks/strawberry.sss RAKUDO_RAKUAST=1 raku -I. -MRakuDoc::Render --rakudoc=HTML new-doc.rakudoc > new-doc.html 


```
<span id="bdc792873927a49cb052c71a7f476eedd1683933"></span>Both `ALT_CSS` and `MORE_HTML` can be used, adding new HTML tags, or changing class names, then including CSS definitions in the file accessed by `ALT_CSS`. 

<span id="52684719883f11e1e81eaf4a9544d455f818d78b"></span>Note that there is a difference between how the CSS and Template files are used. 



&nbsp;&nbsp;• <span id="6e8f4751028030b4320b223f4754a65360e27b56"></span>By design, new Raku closure templates, eg, those defined in files given to `MORE_HTML`, are placed at the head of a chain of templates, and so are *in addition* to those previously defined. 

  
&nbsp;&nbsp;• <span id="a26344813dd0cdb16fc43864814f20c6162fe5cd"></span>The alternate CSS file (eg ~/tweaks/strawberry.css) is used **instead** of the default `vanilla.css`. 

  

----
<div id="Credits"> </div>
｢semantic-schema_AUTHOR UNAVAILABLE｣


----
<div id="Placement"> </div>
----

## VERSION<div id="VERSION"> </div>
v0.1.0





----

----

Rendered from docs/docs/RakuDoc-To-HTML.rakudoc at 11:20 UTC on 2024-06-23

Source last modified at 10:55 UTC on 2024-06-23



----

----

## WARNINGS

1: Still waiting for ｢semantic-schema_AUTHOR｣ to be expanded.


