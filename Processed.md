
# ProcessState and RakuDoc::Processed

	Collecting data to be used for rendering

----

## Table of Contents

<a href="#Purpose">Purpose</a>   
<a href="#Credits">Credits</a>   



----

## Purpose<div id="Purpose"> </div>
<span class="para" id="7dd26db"></span>When a RakuDoc source is being processed, data is collected about numerous items, such as the Table of Contents, the Index, list and definition entries. 

<span class="para" id="caf8c99"></span>Many RakuDoc blocks allow for recursion, with blocks being embedded within each other. A ProcessState object is therefore created to contain all the intermediary data. 

<span class="para" id="0a3e7a9"></span>One ProcessState object can be added to another, and so once one block has been processed, it can be 'added' to the ProcessState object of the containing block. 

<span class="para" id="1427915"></span>Finally, when an entire RakuDoc source has been fully rendered, it is useful to retain all the intermediary data structures as well. 

<span class="para" id="7c3ecf8"></span>The overall RakuDoc::Processed object contains data related to the source as well as the rendered data. 

<span class="para" id="228a2c4"></span>By keeping track of the timestamps of the source file and the rendering, it will be possible to determine whether to render a source again, or not. 



### Attributes of ProcessedState object<div id="Attributes_of_ProcessedState_object"> </div>


#### <span class="para" id="fc85fc9"></span>`PStr $.body is rw ` 

<div id="<span_class="para"_id="fc85fc9"></span>`PStr_$.body_is_rw_`"> </div>
<span class="para" id="58c42ef"></span>String of rendered source, may contain Promises during rendering 



#### <span class="para" id="37b55ea"></span>`Hash @.toc ` 

<div id="<span_class="para"_id="37b55ea"></span>`Hash_@.toc_`"> </div>

```
Table of Contents data
Ordered array of { :level, :text, :target, :is-heading }
level - in heading hierarchy, text - to be shown in TOC
target - of item in text, is-heading - used for Index placing
```


#### <span class="para" id="6415c40"></span>`Array @.head-numbering ` 

<div id="<span_class="para"_id="6415c40"></span>`Array_@.head-numbering_`"> </div>

```
heading numbering data
Ordered array of [ $id, $level ]
$id is the PCell id of where the numeration structure is to be placed
level - in heading hierarchy
```


#### <span class="para" id="3b4a333"></span>`%.index ` 

<div id="<span_class="para"_id="3b4a333"></span>`%.index_`"> </div>

```
Index (from X&lt;&gt; markup)
Hash entry => Hash of :refs, :sub-index
 :sub-index (maybe empty) is Hash of sub-entry => :refs, :sub-index
 :refs is Array of (Hash :target, :place, :is-header)
 :target is for link, :place is section name
 :is-header because <span id="index-entry-"><span style="color:green; background-color: antiquewhite;"></span></span> in headings treated differently to ordinary text
```


#### <span class="para" id="759022e"></span>`@.footnotes ` 

<div id="<span_class="para"_id="759022e"></span>`@.footnotes_`"> </div>

```
Footnotes (from N&lt;&gt; markup)
Ordered Array of :$text, :$retTarget, :$fnNumber, :$fnTarget
text is content of footnote, fnNumber is footNote number
fnTarget is link to rendered footnote
retTarget is link to where footnote is defined to link back form footnote
```


#### <span class="para" id="56ed6f5"></span>`Array %.semantics ` 

<div id="<span_class="para"_id="56ed6f5"></span>`Array_%.semantics_`"> </div>
<span class="para" id="3ffaa5d"></span>Semantic blocks (which includes TITLE & SUBTITLE) can be hidden Hash of SEMANTIC => [ PStr | Str ] 



#### <span class="para" id="adbfe90"></span>`@.warnings ` 

<div id="<span_class="para"_id="adbfe90"></span>`@.warnings_`"> </div>
<span class="para" id="4960b15"></span>An array of warnings is generated and then rendered by the warnings template The warning template, by default is called by the wrap-source template RakuDoc warnings are generated as specified in the RakuDoc v2 document. 



#### <span class="para" id="b1e72b5"></span>`@.items ` 

<div id="<span_class="para"_id="b1e72b5"></span>`@.items_`"> </div>
<span class="para" id="a5b5846"></span>An array of accumulated rendered items, added to body when next non-item block encountered 



#### <span class="para" id="a671a57"></span>`@.defns ` 

<div id="<span_class="para"_id="a671a57"></span>`@.defns_`"> </div>
<span class="para" id="943df73"></span>An array of accumulated rendered definitions, added to body when next non-defn block encountered 



#### <span class="para" id="672e1c0"></span>`@.numitems ` 

<div id="<span_class="para"_id="672e1c0"></span>`@.numitems_`"> </div>
<span class="para" id="877174c"></span>An array of accumulated rendered numbered items, added to body when next non-item block encountered 



#### <span class="para" id="2259bc7"></span>`@.numdefns ` 

<div id="<span_class="para"_id="2259bc7"></span>`@.numdefns_`"> </div>
<span class="para" id="7b0e777"></span>An array of accumulated rendered numbered definitions, added to body when next non-defn block encountered 



#### <span class="para" id="35befe0"></span>`%.definitions ` 

<div id="<span_class="para"_id="35befe0"></span>`%.definitions_`"> </div>
<span class="para" id="19cd8a1"></span>Hash of definition => rendered value for definitions 



#### <span class="para" id="16822a7"></span>`@.inline-defns ` 

<div id="<span_class="para"_id="16822a7"></span>`@.inline-defns_`"> </div>
<span class="para" id="9e0ecf0"></span>Array to signal when one or more inline defn are made in a Paragraph 



### Attributes of RakuDoc::Processed<div id="Attributes_of_RakuDoc::Processed"> </div>
<span class="para" id="a1a36bd"></span>All of the ProcessState attributes, and the following. 



#### <span class="para" id="97a239b"></span>` %.source-data ` 

<div id="<span_class="para"_id="97a239b"></span>`_%.source-data_`"> </div>
<span class="para" id="e3abda9"></span>Information about the RakuDoc source, eg file name, path, modified, language 



#### <span class="para" id="e74e751"></span>` $!output-format = 'txt' ` 

<div id="<span_class="para"_id="e74e751"></span>`_$!output-format_=_'txt'_`"> </div>
<span class="para" id="c077417"></span>The output format that the source has been rendered into 



#### <span class="para" id="b4bfea5"></span>` Str $.front-matter is rw = 'preface' ` 

<div id="<span_class="para"_id="b4bfea5"></span>`_Str_$.front-matter_is_rw_=_'preface'_`"> </div>
<span class="para" id="4113f99"></span>Text between =TITLE and first header, used for <span id="index-entry-_0"><span style="color:green; background-color: antiquewhite;"></span></span> place before first header 



#### <span class="para" id="39732e7"></span>` Str $.name is rw ` 

<div id="<span_class="para"_id="39732e7"></span>`_Str_$.name_is_rw_`"> </div>

```
Name to be used in titles and files
name can be modified after creation of Object
name can be set when creating object
if name is not set, then it is taken from source name + format
```


#### <span class="para" id="0200a11"></span>` Str $.title is rw = 'NO_TITLE' ` 

<div id="<span_class="para"_id="0200a11"></span>`_Str_$.title_is_rw_=_'NO_TITLE'_`"> </div>
<span class="para" id="b207d5d"></span>String value of TITLE. 



#### <span class="para" id="d6774e3"></span>` Str $.title-target is rw = '___top' ` 

<div id="<span_class="para"_id="d6774e3"></span>`_Str_$.title-target_is_rw_=_'___top'_`"> </div>
<span class="para" id="77bfcf9"></span>Target of Title Line 



#### <span class="para" id="67ced52"></span>` Str $.subtitle is rw = '' ` 

<div id="<span_class="para"_id="67ced52"></span>`_Str_$.subtitle_is_rw_=_''_`"> </div>
<span class="para" id="52a4608"></span>String value of SUBTITLE, provides description of file 



#### <span class="para" id="f9c2a5f"></span>` Str $.modified is rw = now.DateTime.utc.truncated-to('seconds').Str ` 

<div id="<span_class="para"_id="f9c2a5f"></span>`_Str_$.modified_is_rw_=_now.DateTime.utc.truncated-to('seconds').Str_`"> </div>
<span class="para" id="deb5920"></span>When RakuDoc Processed Object modified (source-data<modified> should be earlier than RPO.modified) 



#### <span class="para" id="680cf03"></span>` SetHash $.targets ` 

<div id="<span_class="para"_id="680cf03"></span>`_SetHash_$.targets_`"> </div>
<span class="para" id="51e7f52"></span>target data generated from block names and :id metadata A set of unique targets inside the file, new targets must be unique 



#### <span class="para" id="5b3bafb"></span>` Hash %.links ` 

<div id="<span_class="para"_id="5b3bafb"></span>`_Hash_%.links_`"> </div>
<span class="para" id="65b0ac0"></span>Links (from [link-label](destination) markup) Hash of destination => :target, :type, :place, :link-label target = computed URL (for local files), place = anchor inside file type has following values: 



&nbsp;&nbsp;• Internal are of the form '#this is a heading' and refer to anchors inside the file  
&nbsp;&nbsp;• Local are of the form 'some-type#a heading there', where 'some-type' is a file name in the same directory  
&nbsp;&nbsp;• External is a fully qualified URL  


#### <span class="para" id="8267861"></span>` Str $.rendered-toc is rw ` 

<div id="<span_class="para"_id="8267861"></span>`_Str_$.rendered-toc_is_rw_`"> </div>
<span class="para" id="e064804"></span>Rendered version of the ToC 



#### <span class="para" id="ff304a1"></span>` Str $.rendered-index is rw ` 

<div id="<span_class="para"_id="ff304a1"></span>`_Str_$.rendered-index_is_rw_`"> </div>
<span class="para" id="10f5945"></span>Rendered version of the Index 


----

## Credits<div id="Credits"> </div>
Richard Hainsworth aka finanalyst




----

## VERSION<div id="VERSION_0"> </div>
v0.2.1




----

## Index

<span style="background-color: antiquewhite; font-weight: 600;"></span>: <a href="#index-entry-">Block # 2</a>, <a href="#index-entry-_0"><span class="para" id="b4bfea5"></span>` Str $.front-matter is rw = 'preface' ` 

</a>




----

----

Rendered from docs/docs/Processed.rakudoc at 15:53 UTC on 2024-08-08

Source last modified at 09:38 UTC on 2024-08-07


