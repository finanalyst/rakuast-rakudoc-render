
# The RakuDoc to HTML-Extra renderer

	Based on RakuAST-RakuDoc-Render engine, HTML with plugins and Bulma CSS

----

## Table of Contents
<a href="#SYNOPSIS">SYNOPSIS</a>   
<a href="#Overview">Overview</a>   
&nbsp;&nbsp;- <a href="#Plugins_and_their_sources">Plugins and their sources</a>   
<a href="#RakuDoc::Render_plugins">RakuDoc::Render plugins</a>   
<a href="#Credits">Credits</a>   


----  

## SYNOPSIS<div id="SYNOPSIS"> </div>
<span class="para" id="2c0848f"></span>In a *clean* directory containing only a RakuDoc source, eg `wp.rakudoc` use the terminal command 


```
RAKUDO_RAKUAST=1 raku -MRakuDoc::Render -MRakuDoc::To::HTML --rakudoc=HTML-Extra wp.rakudoc > wp.html
```
<span class="para" id="256c897"></span>Easier (once the distribution has been installed, see [README](README.md)) 


```
RakuDoc wp
```
<span class="para" id="e912ae0"></span>Both will cause the file `wp.html` to be generated in the current working directory, together with a new subdirectory *assets/* in which other CSS and Javascript files will be placed. 

<span class="para" id="1998dac"></span>To view this file, see [small Cro app](#Small_Cro_app). 




----

## Overview<div id="Overview"> </div>
<span class="para" id="176fea2"></span>This renderer allows for more customisability than the [minimal HTML renderer](RakuDoc-To-HMTL.md) in this distribution. 

<span class="para" id="e4ab360"></span>By default, the following plugins are provided, and more can be added by the user (see [Plugins](Extra-HTML-Plugins.md)). 



### Plugins and their sources<div id="Plugins_and_their_sources"> </div>
 | **Plugin** | **Source** | **Use** | **License** |
| :---: | :---: | :---: | :---: |
 | Bulma CSS | <span class="para" id="bbdd707"></span>[Bulma Home](https://bulma.io) | The output page is styled into panels, is responsive, has themes | MIT |
 | Leaflet Maps | <span class="para" id="c73e3fe"></span>[Home page](https://leafletjs.com/) | Puts a map in a web page, with tiles from multiple providers | 2-clause BSD |
 | Leaflet providers | <span class="para" id="ae50787"></span>[Github repo](https://github.com/leaflet-extras/leaflet-providers) | Easy way to access tile providers | 2-clause BSD |

----

## RakuDoc::Render plugins<div id="RakuDoc::Render_plugins"> </div>
<span class="para" id="210874c"></span>Customisation is provided by plugins. These are essentially classes of the form `RakuDoc::Plugins::XXX`, where **XXX** is the name of a plugin. 

<span class="para" id="120f3cc"></span>The plugin class **does** the *RakuDoc::Plugin* role. 

<span class="para" id="cbba75e"></span>Each RP class must have a `%.config` attribute containing the information needed for the plugin. These are divided into mandatory keys, which will be tested for, and plugin-specific. 

<span class="para" id="ab374e8"></span>The mandatory key-value Pairs are: 



&nbsp;&nbsp;• <span class="para" id="c1fa930"></span>**license**, typically Artistic-2.0 (same as Raku), but may need to change if the plugin relies on software that has another license. 

  
&nbsp;&nbsp;• <span class="para" id="2ee0c4f"></span>**credits**, a source for the software, and the license its developers use. 

  
&nbsp;&nbsp;• <span class="para" id="f7ab4b4"></span>**version**, a version number for the plugin. 

  
&nbsp;&nbsp;• <span class="para" id="6505c7c"></span>**authors**, the author(s) of the plugin. 

  
&nbsp;&nbsp;• <span class="para" id="375cd71"></span>**name-space**, the name of the plugin's name-space within the RakuDoc-Processor instance. 

  
<span class="para" id="55397fa"></span>Some typical config fields are 



&nbsp;&nbsp;• block-name, the custom block that activates the plugin (a plugin may need only replace existing templates)  
&nbsp;&nbsp;• <span class="para" id="7d34ac2"></span>js-link, a list of `Str, Int $order` arrays. The string is placed in script tag in the head container of the web-page, the order is to ensure that when one js library must appear before another, that relation is created. Libraries with the same order appear in alphabetic order. 

  
&nbsp;&nbsp;• <span class="para" id="24929c6"></span>css-link, a list of `Str, Int $order` arrays. As above, but for CSS. Typically, CSS files must appear before the JS files they are associated with. All CSS files appear in head before JS files. 

  
<span class="para" id="667ac96"></span>All the elements of %.config are transferred to the RakuDoc::Processor object, and can be accessed in a template or callable, as `$tmpl.globals.data<plugin-name-space> ` (assuming that the plugin's config has `namespace =` plugin-name-space>). 

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

Rendered from docs/docs/RakuDoc-To-HTML-Extra.rakudoc at 23:08 UTC on 2024-07-14

Source last modified at 20:48 UTC on 2024-07-06


