
# ProcessState and RakuDoc::Processed

----

## Table of Contents
<a href="#Purpose">Purpose</a>   
  - <a href="#Attributes_of_ProcessedState_object">Attributes of ProcessedState object</a>   
    - <a href="#`PStr_$.body_is_rw_`">`PStr $.body is rw `</a>   
    - <a href="#`Hash_@.toc_`">`Hash @.toc `</a>   
    - <a href="#`Array_@.head-numbering_`">`Array @.head-numbering `</a>   
    - <a href="#`%.index_`">`%.index `</a>   
    - <a href="#`@.footnotes_`">`@.footnotes `</a>   
    - <a href="#`Array_%.semantics_`">`Array %.semantics `</a>   
    - <a href="#`@.warnings_`">`@.warnings `</a>   
    - <a href="#`@.items_`">`@.items `</a>   
    - <a href="#`@.defns_`">`@.defns `</a>   
    - <a href="#`@.numitems_`">`@.numitems `</a>   
    - <a href="#`@.numdefns_`">`@.numdefns `</a>   
    - <a href="#`%.definitions_`">`%.definitions `</a>   
    - <a href="#`@.inline-defns_`">`@.inline-defns `</a>   
  - <a href="#Attributes_of_RakuDoc::Processed">Attributes of RakuDoc::Processed</a>   
    - <a href="#`_%.source-data_`">` %.source-data `</a>   
    - <a href="#`_$!output-format_=_'txt'_`">` $!output-format = 'txt' `</a>   
    - <a href="#`_Str_$.front-matter_is_rw_=_'preface'_`">` Str $.front-matter is rw = 'preface' `</a>   
    - <a href="#`_Str_$.name_is_rw_`">` Str $.name is rw `</a>   
    - <a href="#`_Str_$.title_is_rw_=_'NO_TITLE'_`">` Str $.title is rw = 'NO_TITLE' `</a>   
    - <a href="#`_Str_$.title-target_is_rw_=_'___top'_`">` Str $.title-target is rw = '___top' `</a>   
    - <a href="#`_Str_$.subtitle_is_rw_=_''_`">` Str $.subtitle is rw = '' `</a>   
    - <a href="#`_Str_$.modified_is_rw_=_now.DateTime.utc.truncated-to('seconds').Str_`">` Str $.modified is rw = now.DateTime.utc.truncated-to('seconds').Str `</a>   
    - <a href="#`_SetHash_$.targets_`">` SetHash $.targets `</a>   
    - <a href="#`_Hash_%.links_`">` Hash %.links `</a>   
    - <a href="#`_Str_$.rendered-toc_is_rw_`">` Str $.rendered-toc is rw `</a>   
    - <a href="#`_Str_$.rendered-index_is_rw_`">` Str $.rendered-index is rw `</a>   
<a href="#Credits">Credits</a>   


----

## Purpose<div id="Purpose"> </div>
When a RakuDoc source is being processed, data is collected about numerous items, such as the Table of Contents, the Index, list and definition entries. 

Many RakuDoc blocks allow for recursion, with blocks being embedded within each other. A ProcessState object is therefore created to contain all the intermediary data. 

One ProcessState object can be added to another, and so once one block has been processed, it can be 'added' to the ProcessState object of the containing block. 

Finally, when an entire RakuDoc source has been fully rendered, it is useful to retain all the intermediary data structures as well. 

The overall RakuDoc::Processed object contains data related to the source as well as the rendered data. 

By keeping track of the timestamps of the source file and the rendering, it will be possible to determine whether to render a source again, or not. 



### Attributes of ProcessedState object<div id="Attributes_of_ProcessedState_object"> </div>


#### `PStr $.body is rw `<div id="`PStr_$.body_is_rw_`"> </div>
String of rendered source, may contain Promises during rendering 



#### `Hash @.toc `<div id="`Hash_@.toc_`"> </div>

```
Table of Contents data Ordered array of { :level, :text, :target, :is-heading } level - in heading hierarchy, text - to be shown in TOC target - of item in text, is-heading - used for Index placing
```


#### `Array @.head-numbering `<div id="`Array_@.head-numbering_`"> </div>

```
heading numbering data Ordered array of [ $id, $level ] $id is the PCell id of where the numeration structure is to be placed level - in heading hierarchy
```


#### `%.index `<div id="`%.index_`"> </div>

```
Index (from <span id="index-entry-"><span style="color:green; background-color: antiquewhite;"></span></span> markup) Hash entry => Hash of :refs, :sub-index :sub-index (maybe empty) is Hash of sub-entry => :refs, :sub-index :refs is Array of (Hash :target, :place, :is-header) :target is for link, :place is section name :is-header because <span id="index-entry-_0"><span style="color:green; background-color: antiquewhite;"></span></span> in headings treated differently to ordinary text
```


#### `@.footnotes `<div id="`@.footnotes_`"> </div>

```
Footnotes (from <a id="N<>" href="#fn_target_N<>"><sup>[ 1 ]</sup></a> markup) Ordered Array of :$text, :$retTarget, :$fnNumber, :$fnTarget text is content of footnote, fnNumber is footNote number fnTarget is link to rendered footnote retTarget is link to where footnote is defined to link back form footnote
```


#### `Array %.semantics `<div id="`Array_%.semantics_`"> </div>
Semantic blocks (which includes TITLE & SUBTITLE) can be hidden Hash of SEMANTIC => [ PStr | Str ] 



#### `@.warnings `<div id="`@.warnings_`"> </div>
An array of warnings is generated and then rendered by the warnings template The warning template, by default is called by the wrap-source template RakuDoc warnings are generated as specified in the RakuDoc v2 document. 



#### `@.items `<div id="`@.items_`"> </div>
An array of accumulated rendered items, added to body when next non-item block encountered 



#### `@.defns `<div id="`@.defns_`"> </div>
An array of accumulated rendered definitions, added to body when next non-defn block encountered 



#### `@.numitems `<div id="`@.numitems_`"> </div>
An array of accumulated rendered numbered items, added to body when next non-item block encountered 



#### `@.numdefns `<div id="`@.numdefns_`"> </div>
An array of accumulated rendered numbered definitions, added to body when next non-defn block encountered 



#### `%.definitions `<div id="`%.definitions_`"> </div>
Hash of definition => rendered value for definitions 



#### `@.inline-defns `<div id="`@.inline-defns_`"> </div>
Array to signal when one or more inline defn are made in a Paragraph 



### Attributes of RakuDoc::Processed<div id="Attributes_of_RakuDoc::Processed"> </div>
All of the ProcessState attributes, and the following. 



#### ` %.source-data `<div id="`_%.source-data_`"> </div>
Information about the RakuDoc source, eg file name, path, modified, language 



#### ` $!output-format = 'txt' `<div id="`_$!output-format_=_'txt'_`"> </div>
The output format that the source has been rendered into 



#### ` Str $.front-matter is rw = 'preface' `<div id="`_Str_$.front-matter_is_rw_=_'preface'_`"> </div>
Text between =TITLE and first header, used for <span id="index-entry-_0"><span style="color:green; background-color: antiquewhite;"></span></span> place before first header 



#### ` Str $.name is rw `<div id="`_Str_$.name_is_rw_`"> </div>

```
Name to be used in titles and files name can be modified after creation of Object name can be set when creating object if name is not set, then it is taken from source name + format
```


#### ` Str $.title is rw = 'NO_TITLE' `<div id="`_Str_$.title_is_rw_=_'NO_TITLE'_`"> </div>
String value of TITLE. 



#### ` Str $.title-target is rw = '___top' `<div id="`_Str_$.title-target_is_rw_=_'___top'_`"> </div>
Target of Title Line 



#### ` Str $.subtitle is rw = '' `<div id="`_Str_$.subtitle_is_rw_=_''_`"> </div>
String value of SUBTITLE, provides description of file 



#### ` Str $.modified is rw = now.DateTime.utc.truncated-to('seconds').Str `<div id="`_Str_$.modified_is_rw_=_now.DateTime.utc.truncated-to('seconds').Str_`"> </div>
When RakuDoc Processed Object modified (source-data<modified> should be earlier than RPO.modified) 



#### ` SetHash $.targets `<div id="`_SetHash_$.targets_`"> </div>
target data generated from block names and :id metadata A set of unique targets inside the file, new targets must be unique 



#### ` Hash %.links `<div id="`_Hash_%.links_`"> </div>
Links (from [link-label](destination.md) markup) Hash of destination => :target, :type, :place, :link-label target = computed URL (for local files), place = anchor inside file type has following values: 



&nbsp;&nbsp;• Internal are of the form '#this is a heading' and refer to anchors inside the file  
&nbsp;&nbsp;• Local are of the form 'some-type#a heading there', where 'some-type' is a file name in the same directory  
&nbsp;&nbsp;• External is a fully qualified URL  


#### ` Str $.rendered-toc is rw `<div id="`_Str_$.rendered-toc_is_rw_`"> </div>
Rendered version of the ToC 



#### ` Str $.rendered-index is rw `<div id="`_Str_$.rendered-index_is_rw_`"> </div>
Rendered version of the Index 


----
<div id="Credits"> </div>
----

## AUTHOR<div id="AUTHOR"> </div>
Richard Hainsworth aka finanalyst




----
<div id="Placement"> </div>
----

## VERSION<div id="VERSION"> </div>
v0.2.1



----

## Footnotes
1<a id=".<fnTarget>" href="#N<>"> |^| </a>


----

## Index
<span style="background-color: antiquewhite; font-weight: 600;"></span>:  <a href="#index-entry-">`%.index `</a>, <a href="#index-entry-_0">`%.index `</a>, <a href="#index-entry-_0">` Str $.front-matter is rw = 'preface' `</a>




----

----

Rendered from docs/docs/Processed.rakudoc at 15:33 UTC on 2024-06-19

Source last modified at 15:32 UTC on 2024-06-19


