        # Templates in default-text-templates
>Auto generated from `lib/RakuDoc/Render.rakumod`


## Table of Contents
[Table](#table)  

----
| **Name** | **Description**  |
| --- | ---  |
| **defn**| renders the numeration part for a toc |
|  - | renders =defn block |
| **markup-A**| A< DISPLAY-TEXT &#124; METADATA = ALIAS-NAME > |
|  - | Alias to be replaced by contents of specified V<=alias> directive |
| **markup-B**| B< DISPLAY-TEXT > |
|  - | Basis/focus of sentence (typically rendered bold) |
| **markup-C**| C< DISPLAY-TEXT > |
|  - | Code (typically rendered fixed-width) |
| **markup-D**| D< DISPLAY-TEXT &#124; METADATA = SYNONYMS > |
|  - | Definition inline ( D<term being defined&#124;synonym1; synonym2> ) |
| **markup-E**| E< DISPLAY-TEXT &#124; METADATA = HTML/UNICODE-ENTITIES > |
|  - | Entity (HTML or Unicode) description ( E<entity1;entity2; multi,glyph;...> ) |
| **markup-F**| F< DISPLAY-TEXT &#124; METADATA = LATEX-FORM > |
|  - | Formula inline content ( F<ALT&#124;LaTex notation> ) |
| **markup-H**| H< DISPLAY-TEXT > |
|  - | High text (typically rendered superscript) |
| **markup-I**| I< DISPLAY-TEXT > |
|  - | Important (typically rendered in italics) |
| **markup-J**| J< DISPLAY-TEXT > |
|  - | Junior text (typically rendered subscript) |
| **markup-K**| K< DISPLAY-TEXT > |
|  - | Keyboard input (typically rendered fixed-width) |
| **markup-L**| L< DISPLAY-TEXT &#124; METADATA = TARGET-URI > |
|  - | Link ( L<display text&#124;destination URI> ) |
| **markup-M**| M< DISPLAY-TEXT &#124; METADATA = WHATEVER > |
|  - | Markup extra ( M<display text&#124;functionality;param,sub-type;...>) |
| **markup-N**| N< DISPLAY-TEXT > |
|  - | Note (not rendered inline, but visible in some way: footnote, sidenote, pop-up, etc.)) |
| **markup-O**| O< DISPLAY-TEXT > |
|  - | Overstrike or strikethrough |
| **markup-P**| P< DISPLAY-TEXT &#124; METADATA = REPLACEMENT-URI > |
|  - | Placement link |
| **markup-R**| R< DISPLAY-TEXT > |
|  - | Replaceable component or metasyntax |
| **markup-S**| S< DISPLAY-TEXT > |
|  - | Space characters to be preserved |
| **markup-T**| T< DISPLAY-TEXT > |
|  - | Terminal output (typically rendered fixed-width) |
| **markup-U**| U< DISPLAY-TEXT > |
|  - | Unusual (typically rendered with underlining) |
| **markup-V**| V< DISPLAY-TEXT > |
|  - | Verbatim (internal markup instructions ignored) |
| **markup-X**| X< DISPLAY-TEXT &#124; METADATA = INDEX-ENTRY > |
|  - | Index entry ( X<display text&#124;entry,subentry;...>) |
| **markup-Δ**| Δ< DISPLAY-TEXT &#124; METADATA = VERSION-ETC > |
|  - | Delta note ( Δ<visible text&#124;version; Notification text> ) |






----
Rendered from default-text-templates at 2024-06-04T22:21:32Z