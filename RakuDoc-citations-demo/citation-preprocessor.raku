#! /usr/bin/env raku
use v6.d;

use JSON::Fast;
use YAMLish;
use LibXML;

# Cmdline interface...
sub MAIN (
    $rakudoc-file where .IO.r & /'.' raku[doc]? $/,         # Requires a RakuDoc or Raku file
    $output-file?,                                          # Optional output RakuDoc file
    :style($DEFAULT-STYLE)   = 'ieee',   # Optional style file
    :locale($DEFAULT-LOCALE) = 'en-US',  # Optional locale file
);

# Grab the document...
my $document = slurp $rakudoc-file;

# Extract the =citation blocks and prep them for eventual replacement...
my %citations = extract-citation-data($document);

# Identify the Q<> codes...
my @Q-codes = extract-Q-codes($document);

# Identify and simulate any missing citation datasets...
for @Q-codes {
    for .<cit-indic> {
        state $next-missing = 1;
        my $indicator = S:g/ '\\' (.) /$0/ given .<indic>.Str.trim;
        %citations<data>{$indicator} //= {
            id              => $indicator,
            type            => "article",
            title           => "NO SUCH CITATION ID: $indicator",
            author          => { family => "Unknown", given => "Reference" },
            container-title => "Did you misspell <$indicator>?",
            issued          => { date-parts => [[$next-missing++]] }
        };
    }
}

# Generate all bibliographic markers and replace the corresponding Q<> codes with them...
# (Also sets up 'cited' and 'uncited' categories in %citations)...
my ($markers, $biblist-all) = build-bibliography(@Q-codes, %citations, :categorize);

# Update replacements for Q-codes...
for @Q-codes.reverse -> $loc {
    $document.substr-rw($loc.from, $loc.chars) = $markers.pop;
}

# Set up the universal bibliographic list (there maybe others later)...
my %biblist = ('*' => $biblist-all );

# Extract and process the relevant =place directives...
my @places = extract-place-citations($document);

for @places.reverse -> $placement {
    given $placement<categories> -> $cat {
        %biblist{$cat} //= build-bibliography(@Q-codes, %citations, :categories[$cat.split(',')])[1];
        $document.substr-rw($placement.from, $placement.chars) = %biblist{$cat};
    }
}

my $output = qq:to<END>;
    =begin rakudoc
    $document
    =end rakudoc
    END

if $output-file { $output-file.IO.spurt($output) }
else            {                   say $output  }

#=====[ Utility subroutines ]====================================================

# NOTE: In real life this info would be extracted from the AST (clearly this approach is a hack!)...
sub extract-Q-codes ($document) {
    # What the tag in a Q<> looks like...
    my token indic ($ldel, $rdel) {
                         [ $ldel <.indic> $rdel                        # nested balanced delimiters
                         | [<!before $ldel | $rdel | <[,;|\\]> > .]+   # or non-special characters
                         ]+
                            %%                                         #   interspersed with
                         [ '\\' [ $ldel | $rdel | <[,;|\\]> ] ]        # quoted special characters
                    }

    # What the optional suffix in a Q<> looks like...
    my token suffix ($ldel, $rdel) {
                         # Same pattern as above, except raw commas are allowed...
                         [ $ldel <.suffix> $rdel | [<!before $ldel | $rdel | <[;|\\]> > .]+ ]*
                         % [ '\\' [ $ldel | $rdel | <[;|\\]> ] ]
                    }

    # What the entire contents of a Q<> looks like...
    my rule cit-indic ($ldel, $rdel) { <indic: $ldel, $rdel> [ ',' <suffix: $ldel, $rdel> ]? }

    # Only bother with a few common delimiter forms, but allow multiple tags in any Q code...
    $document ~~ m:g{ Q [ '<'   <cit-indic: '<',   '>'>+  %  ';'   '>'
                        | '<<'  <cit-indic: '<<', '>>'>+  %  ';'  '>>'
                        | '«'   <cit-indic: '«',   '»'>+  %  ';'   '»'
                        ]
                    }
}

# NOTE: In real life this info would be extracted from the AST (this approach is another hack!)...
sub extract-citation-data ($document is rw) {

    # Accumulate the data, indexed by ID...
    my %citations;

    # What abbreviated and =for block contents look like...
    my regex data-line     { \h* <!before '='<ident> > \N* \S \N* [\n|$] }

    # What the closing delimiter for a =begin block looks like...
    my regex end-citation  { \h* '=end' \h+ 'citation' >> \h* [\n|$] }

    # Extract (and remove) all the =citation blocks...
    my @citation-blocks
        = $document ~~ s:g/
            ^^ \h*  '=' [           citation >>                  $<data>=[ \N* \n <&data-line>* ]
                        | for   \h+ citation >> $<opts>=[\N*] \n $<data>=[ <&data-line>* ]
                        | begin \h+ citation >> $<opts>=[\N*] \n $<data>=[.*?] \n <&end-citation>
                        ]

          /\n/;

    # Convert each citation block's data into CSL-Raku...
    for @citation-blocks -> $block {

        # Reify metaoptions...
        my %opt = $block<opts> ?? safe-eval($block<opts>.Str, :desc<citation block option>) // {} !! {};

        # Categorize data...
        my @categories = (%opt<category> // []).values;

        # Extract the block contents...
        my $content = $block<data>.Str;

        # Allocate unique IDs for entries that lack them...
        state $noIDcount = 1;

        # Does the block specify a style or locale???
        with %opt<style>  { %citations<style>  = %opt<style>  }
        with %opt<locale> { %citations<locale> = %opt<locale> }

        # Does the citation block load data from elsewhere???
        with %opt<load> {

            # Loading external content while also specifying internal content is confusing...
            if $content ~~ /\S/ {
                note '=citation blocks with :load<URL> and in-document data';
                note 'are better written as two separate blocks';
            }

            # Load and convert external data to internal Raku format, categorizing as well...
            with curl(%opt<load>) -> $external-content {
                for convert-to-CSL-Raku($external-content) -> $entry {
                    $entry<id> //= $entry<DOI> // "Missing-ID-{$noIDcount++}";
                    %citations<categories>{ @categories }».push($entry<id>);
                    %citations<data>{ $entry<id> } = $entry.&convert-dates;
                }
            }
            else {
                note "Could not load citation data from %opt<load>";
            }
        }

        # Convert citation block data to CSL-Raku and store it under its ID (or one we made up)...
        if $block<data>.Str ~~ /\S/ {
            for convert-to-CSL-Raku($block<data>.Str) -> $entry {
                $entry<id> //= $entry<DOI> // "Missing-ID-{$noIDcount++}";
                %citations<categories>{ @categories }».push($entry<id>);
                %citations<data>{ $entry<id> } = $entry.&convert-dates;
            }
        }
    }

    # Ensure defaults are in place..
    %citations<style>  //= $DEFAULT-STYLE;
    %citations<locale> //= $DEFAULT-LOCALE;

    return %citations;
}

# Extract every =place citation: directive...
sub extract-place-citations ($document) {
    $document ~~ m:g{ ^^ \h* '=place' \h+ 'citation:'
                         $<categories>=[ '*' | <ident> ]+ %% ','
                         \h* $$
                  }
}

# Build the complete list of bibliographic markers to replace Q<> codes...
sub build-bibliography (@Q-codes, %citations, :@categories, :$categorize) {
    # Prepare formatting...
    my $STYLE  = %citations<style>  // $DEFAULT-STYLE;
    my $LOCALE = %citations<locale> // $DEFAULT-LOCALE;

    # Start building citeproc data...
    my $data = q:to<END>;
        ---
        nocite: |
          @*
        references:
        END

    # Convert citation list to CSL-YAML...
    my $yaml = do {
        if @categories {
            my @IDs = %citations<categories>{@categories}».values.flat;
            save-yaml(%citations<data>{@IDs});
        }
        else {
            save-yaml(%citations<data>.values);
        }
    }
    $data ~= $yaml.subst(/^ '---' \N* \n/, '').subst(/^^ <!before '...'> /,'  ',:g);

    # Convert citation indicators to Markdown format and remember that we cited them...
    my %cited;
    my @indicators = gather for @Q-codes {
        my @md-citations = gather for .<cit-indic> {
            my $indic  = .<indic>.trim.subst(/<before '{' | '}' >/, '\\', :g);
            my $suffix = .<suffix> ?? ', ' ~ .<suffix>.trim !! q{};
            %cited{$indic} = True;
            take "\@\{$indic\}$suffix";
        }
        take '[' ~ @md-citations.join(';') ~ ']';
    }
    $data ~= qq{\n@indicators.join("\n\n")\n\nEND\n};

    # Create the 'cited' and 'uncited' categories in %citations<categories>...
    for %citations<data>.keys -> $ID {
        if %cited{$ID} { %citations<categories><cited>.push($ID) }
        else           { %citations<categories><uncited>.push($ID) }
    }

    # Run the pandoc --citeproc to generate the final renderings...
    my $citeproc = citeproc($data, :$STYLE, :$LOCALE);

    # Retrieve and translate the markers back to RakuDoc...
    my ($markers, $biblist) = $citeproc.split(/^^END\n/);
    my @markers = $markers.trim.comb(/[^^ \N*? \S \N* [\n|$]]+/).map({ markdown-to-rakudoc($_, :noblock) });

    # Retrieve and translate the bibliographic list back to RakuDoc...
    my @biblist = $biblist.trim.split(/[^^ \h* \n]+/).map({ markdown-to-rakudoc($_) });

    return @markers, @biblist.join("\n\n");
}


# Use the appropriate external utility or utilities to convert any supported format to CSL-Raku...
sub convert-to-CSL-Raku ( $data ) {

    # What kind of citation data is it???
    my $data-format = sniff-test($data);

    # Whatever it is, convert it to CSL-JSON...
    my $csl-json = do given $data-format {

        # Already Raku data, so just reify it, check it, and return it (skipping the de-JSON-ification)...
        # (Note: must add an empty dummy hash at the beginning of the list, then strip it after conversion
        #        because EVAL sometimes gets muddled on single-hash '[{...}]' source data)...
        when 'CSL-Raku'   { my $csl-raku = safe-eval("[\%(),$data]", :desc<CSL-Raku citation data>);
                            return $csl-raku.values.tail(*-1)
                                if $csl-raku ~~ Array && all($csl-raku) ~~ Hash;
                            '[]';
                          }

        # Already CSL data, so just de-YAML-ize it, and return it (skipping the de-JSON-ification)...
        when 'CSL-YAML'   { my $csl-raku = try load-yaml($data).values;
                            return $csl-raku.values if $csl-raku ~~ Array|List|Seq && all($csl-raku) ~~ Hash;
                            '[]';
                          }

        # Already CSL-JSON data, so just send it back through the de-JSON-ifier...
        when 'CSL-JSON'   { $data }

        # Pandoc can directly translate these formats to CSL-JSON...
        when 'RIS'        { pandoc :from<ris>,      left-justify $data }
        when 'BibLaTeX'   { pandoc :from<biblatex>,              $data }
        when 'BibTeX'     { pandoc :from<bibtex>,                $data }

        # for BibTeXML:   BibTeXML ––(internal conversion)––> BibTeX ––(pandoc)––> CSL-JSON...
        when 'BibTeXML'   { pandoc :from<bibtex>,  bibtexml-to-bibtex $data }

        # for PubMedNBIB: NBIB ––(nbib2xml)––> MODS ––(xml2biblatex)––> BibLaTeX ––(pandoc)––> CSL-JSON...
        when 'PubMedNBIB' { pandoc :from<biblatex>,  xml2biblatex  nbib2xml  left-justify $data }

        # for PubMedXML:  PMXML ––(med2xml)––> MODS ––(xml2biblatex)––> BibLaTeX ––(pandoc)––> CSL-JSON...
        when 'PubMedXML'  { pandoc :from<biblatex>,  xml2biblatex  med2xml $data }

        # for MODS:       MODS ––(xml2biblatex)––> BibLaTeX ––(pandoc)––> CSL-JSON...
        when 'MODS'       { pandoc :from<biblatex>,  xml2biblatex $data }

        # No data or bad data...
        default           { '[]' }
    }

    # No convertible data??? Warn and return nothing...
    if ($csl-json eq '[]' && $data ~~ /\S/) {
        note "Could not understand $data-format citation data\n", ~($! // q{}, $data);
        return ();
    }

    # Convert valid JSON and return, or warn that something went wrong...
    with try from-json $csl-json -> $csl-raku {
        return $csl-raku.values;
    }
    else {
        note "Could not understand $data-format citation data\n", ~($! // q{});
        return ();
    }
}

# Work out what kind of data a =citation block contains or loads, via a quick-and-dirty test.
# (This should probably be achieved via grammar matches and/or validation against XML schemas,
#  but that would be much slower and we don't have the grammars for it anyway)...
#
sub sniff-test ($citation-data, :$filename) {

    # Start by inferring from the filename, if any...
    with $filename -> $_ {
        when / '.' json  $ /  { 'CSL-JSON'   }
        when / '.' yaml  $ /  { 'CSL-YAML'   }
        when / '.' raku  $ /  { 'CSL-Raku'   }
        when / '.' bib   $ /  { 'BibLaTeX'   }
        when / '.' mods  $ /  { 'MODS'       }
        when / '.' nbib  $ /  { 'PubMedNBIB' }
        when / '.' ris   $ /  { 'RIS'        }
    }

    # Otherwise, fall back on the "first few characters" heuristic...
    return do given $citation-data.trim {
        when / ^ '['                 /  { 'CSL-JSON'   }
        when / ^ '-'                 /  { 'CSL-YAML'   }
        when / ^ ['(' | '{']         /  { 'CSL-Raku'   }
        when / ^ '@'                 /  { 'BibLaTeX'   }
        when / ^ '<bibtex'           /  { 'BibTeXML'   }
        when / ^ '<mods'             /  { 'MODS'       }
        when / ^ '<PubmedArticleSet' /  { 'PubMedXML'  }
        when / ^ ['PMID-' | 'UI']    /  { 'PubMedNBIB' }
        when / ^ 'TY  -'             /  { 'RIS'        }
        default                         { 'unknown'    }
    }
}

# pandoc requires tagged-format RIS or NBIB data to be left-justified...
sub left-justify ($data) {
    return $data.subst(/^^ \h+/, q{}, :g);
}

# Support for using external cmdline apps as data filters...
sub filter (:$data, :$fail = Nil, *@command) {
    # Spawn the process...
    my $proc = run |@command, :in, :out, :err;

    # Feed in the data (if any)...
    with $data {
        sink so $proc.in.print($data);
        sink so $proc.in.close;
    }

    # Handle failures...
    if !$proc || $proc.exitcode != 0 {
        note "Call to @command[0] failed:";
        note $proc.err.slurp;
        return $fail;
    }

    # Handle successes...
    return $proc.out.slurp: :close;
}

# Load URLs (mostly via curl, but short-circuit files and handle a wider range of filepaths)...
sub curl ($URL ) {
    given $URL {
        when /^ file ':' ['//']? (.*) / { return slurp ~$0 }
        default                         { return filter 'curl', '-LsSf', $URL }
    }
}

# Useful external translation apps for citation data...
sub pandoc       ($data, :$from) { filter :fail<[]> :$data, 'pandoc', « -f $from -t csljson » }
sub xml2biblatex ($data)         { filter :fail()   :$data, 'xml2biblatex'                    }
sub med2xml      ($data)         { filter :fail()   :$data, 'med2xml'                         }
sub nbib2xml     ($data)         { filter :fail()   :$data, 'nbib2xml'                        }

# Format indicators and citation data into a set of markers and a bibliographic list...
sub citeproc     ($data, :$STYLE, :$LOCALE) {
    filter :fail(Nil) :$data, 'pandoc', « --citeproc -t markdown_strict »,
           "--metadata=lang:$LOCALE", "--csl=$STYLE";
}

# Internal converter from BibTeX XML to classic BibTeX...
sub bibtexml-to-bibtex(Str $data) {

    # Parse the XML...
    my LibXML::Document $doc .= parse: :string($data);

    # BibTeXML usually wraps entries in an <entry> tag so use local-name() just in case....
    my @bibtex-entries = gather for $doc.findnodes('//*[local-name()="entry"]') -> $entry {

        # BibTeX format always starts with the ID, so grab that first...
        my $id = $entry.getAttribute('id') // 'unknown_id';

        # The first child element under <entry> is usually the BibTeX type (book, article, etc.)...
        my $type-node = $entry.findnodes('*').first;
        my $type      = $type-node ?? $type-node.localName !! 'misc';

        # Iterate through the children of the type node (i.e. the actual metadata fields)...
        my @fields = gather for $type-node.findnodes('*') -> $field {
            my $key   = $field.localName;
            my $value = $field.textContent.trim;

            # Escape internal braces to keep BibTeX valid
            $value ~~ s:g/ '{' /\\\{/;
            $value ~~ s:g/ '}' /\\\}/;

            # Accumulate the field, in classic BibTeX format...
            take "  $key = \{$value\}";
        }

        # Construct and accumulate the full standard BibTeX string...
        take "\@$type\{$id,\n" ~ @fields.join(",\n") ~ "\n\}";
    }

    # Concatenate and return the full sequence of entries...
    return @bibtex-entries.join("\n\n");
}

# We sometimes need to reify Raku source...
sub safe-eval ($source, :$desc) {
    use MONKEY-SEE-NO-EVAL;
    return EVAL $source;
    CATCH { note "Invalid $desc\n$_"; return Nil; }
}

# Convert bibliographic list returned by pandoc --citeproc from Markdown to RakuDoc...
sub markdown-to-rakudoc ($text is copy, :$noblock) {

    # Select the appropriate number of <<<...>>> delimiters for the contents...
    sub delimit ($text) {
        my @embedded_delims = $text ~~ m:g{ <[<>]>+ };
        my $len = 1 + max( 0, |@embedded_delims».chars );
        return ('<' x $len) ~ $text ~ ('>' x $len);
    }

    # Minimize whitespace...
    $text ~~ tr/\n/ /;
    $text.=trim;

    # Handle prefix marker (if any)...
    $text ~~ s/ '<span' \h+ 'class="csl-left-margin">'  (.*?)  '</span>' /=for item :bullet('$0.trim()')\n/
        or
    !$noblock and $text ~~ s/ ^ /=para /;

    # Simulate small-caps formatting (with special-casing of links)...
    $text ~~ s:g/ '<span' \h+ 'class="smallcaps">' \h* '[' (.*?) ']' '(' (.*?) ')' \h* '</span>'
                /L<<<<{small-caps(~$0)} | $1>>>>/;
    $text ~~ s:g/ '<span' \h+ 'class="smallcaps">'  (.*?)  '</span>' /{small-caps(~$0)}/;

    # Convert other links...
    $text ~~ s:g/ <!after '\\'> '[' (.*?) <!after '\\'> ']' '(' (.*?) ')' /L{delimit("$0|$1")}/;

    # Remove other spans...
    $text ~~ s:g/ '<span' >> .*? '>' | '</span>' //;

    # Convert Markdown formatting to RakuDoc...
    $text ~~ s:g/ '<sup>'  (.*?)  '</sup>' /H$0.trans('\\'=>'').&delimit()/;
    $text ~~ s:g/ '<sub>'  (.*?)  '</sub>' /J$0.trans('\\'=>'').&delimit()/;
    $text ~~ s:g/    '**'  (.*?)  '**'     /B$0.trans('\\'=>'').&delimit()/;
    $text ~~ s:g/     '*'  (.*?)  '*'      /I$0.trans('\\'=>'').&delimit()/;

    # Remove escaped brackets...
    $text ~~ s:g/ '\\[' /[/;
    $text ~~ s:g/ '\\]' /]/;

    return $text;
}


# Some bibliographic styles use Sᴍᴀʟʟ Cᴀᴘs ꜰᴏʀ Nᴀᴍᴇs, so we need to be able to convert accordingly
# (Note: unaccountably, there's no Unicode SMALL CAPITAL Q, so we cheat with ǫ)...
sub small-caps ($text) {
   $text.trans: 'abcdefghijklmnopqrstuvwxyzàáâãäåçèéêëìíîïñòóôõöùúûüýÿ'
             => 'ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀsᴛᴜᴠᴡxʏᴢᴀ̀ᴀ́ᴀ̂ᴀ̃ᴀ̈ᴀ̊ᴄ̧ᴇ̀ᴇ́ᴇ̂ᴇ̈ɪ̀ɪ́ɪ̂ɪ̈ɴ̃ᴏ̀ᴏ́ᴏ̂ᴏ̃ᴏ̈ᴜ̀ᴜ́ᴜ̂ᴜ̈ʏ́ʏ̈',
                'āăąćĉċčďēĕėęěĝğġģĥĩīĭįıĵķĸĺļľńņňōŏőŕŗřśŝşšţťũūŭůűųŵŷźżž'
             => 'ᴀ̄ᴀ̆ᴀ̨ᴄ́ᴄ̂ᴄ̇ᴄ̌ᴅ̌ᴇ̄ᴇ̆ᴇ̇ᴇ̨ᴇ̌ɢ̂ɢ̆ɢ̇ɢ̧ʜ̂ɪ̃ɪ̄ɪ̆ɪ̨ıᴊ̂ᴋ̧ĸʟ́ʟ̧ʟ̌ɴ́ɴ̧ɴ̌ᴏ̄ᴏ̆ᴏ̋ʀ́ʀ̧ʀ̌śŝşšᴛ̧ᴛ̌ᴜ̃ᴜ̄ᴜ̆ᴜ̊ᴜ̋ᴜ̨ᴡ̂ʏ̂ᴢ́ᴢ̇ᴢ̌',
                'ǎǐǒǔǖǘǚǜǟǡǧǩǫǭǰǵǹǻȁȃȅȇȉȋȍȏȑȓȕȗșțȥȧȩȫȭȯȱȳḁḃḅḇḉḋḍḏḑḓḕḗḙḛḝḟḡ'
             => 'ᴀ̌ɪ̌ᴏ̌ᴜ̌ᴜ̈̄ᴜ̈́ᴜ̈̌ᴜ̈̀ᴀ̈̄ᴀ̇̄ɢ̌ᴋ̌ᴏ̨ᴏ̨̄ᴊ̌ɢ́ɴ̀ᴀ̊́ᴀ̏ᴀ̑ᴇ̏ᴇ̑ɪ̏ɪ̑ᴏ̏ᴏ̑ʀ̏ʀ̑ᴜ̏ᴜ̑șᴛ̦ȥᴀ̇ᴇ̧ᴏ̈̄ᴏ̃̄ᴏ̇ᴏ̇̄ʏ̄ᴀ̥ʙ̇ʙ̣ʙ̱ᴄ̧́ᴅ̇ᴅ̣ᴅ̱ᴅ̧ᴅ̭ᴇ̄̀ᴇ̄́ᴇ̭ᴇ̰ᴇ̧̆ꜰ̇ɢ̄',
                'ḣḥḧḩḫḭḯḱḳḵḷḹḻḽḿṁṃṅṇṉṋṍṏṑṓṕṗṙṛṝṟṡṣṥṧṩṫṭṯṱṳṵṷṹṻṽṿẁẃẅẇẉẋẍẏẑẓẕ'
             => 'ʜ̇ʜ̣ʜ̈ʜ̧ʜ̮ɪ̰ɪ̈́ᴋ́ᴋ̣ᴋ̱ʟ̣ʟ̣̄ʟ̱ʟ̭ᴍ́ᴍ̇ᴍ̣ɴ̇ɴ̣ɴ̱ɴ̭ᴏ̃́ᴏ̃̈ᴏ̄̀ᴏ̄́ᴘ́ᴘ̇ʀ̇ʀ̣ʀ̣̄ʀ̱ṡṣṥṧṩᴛ̇ᴛ̣ᴛ̱ᴛ̭ᴜ̤ᴜ̰ᴜ̭ᴜ̃́ᴜ̄̈ᴠ̃ᴠ̣ᴡ̀ᴡ́ᴡ̈ᴡ̇ᴡ̣ẋẍʏ̇ᴢ̂ᴢ̣ᴢ̱',
                'ẖẗẘẙạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹœɠæðłɔɹʒγλπρψлɨǝꝵɯ'
             => 'ʜ̱ᴛ̈ᴡ̊ʏ̊ᴀ̣ᴀ̉ᴀ̂́ᴀ̂̀ᴀ̂̉ᴀ̂̃ᴀ̣̂ᴀ̆́ᴀ̆̀ᴀ̆̉ᴀ̆̃ᴀ̣̆ᴇ̣ᴇ̉ᴇ̃ᴇ̂́ᴇ̂̀ᴇ̂̉ᴇ̂̃ᴇ̣̂ɪ̉ɪ̣ᴏ̣ᴏ̉ᴏ̂́ᴏ̂̀ᴏ̂̉ᴏ̂̃ᴏ̣̂ᴏ̛́ᴏ̛̀ᴏ̛̉ᴏ̛̃ᴏ̛̣ᴜ̣ᴜ̉ᴜ̛́ᴜ̛̀ᴜ̛̉ᴜ̛̃ᴜ̛̣ʏ̀ʏ̣ʏ̉ʏ̃ɶʛᴁᴆᴌᴐᴚᴣᴦᴧᴨᴩᴪᴫᵻⱻꝶꟺ';

}


# Change the structure of date-like fields to pacify pandoc --citeproc...
sub convert-dates ($csl-raku-data) {

    # Convert all of these...
    constant @DATE-LIKE-FIELDS = < issued released accessed original-date event-date submitted >;

    # For each potential field...
    my %converted;
    for @DATE-LIKE-FIELDS -> $field {

        # Does the date-like field use 'date-parts'???
        with $csl-raku-data{$field}<date-parts> {

            # For each part, convert to the format --citeproc requires...
            for .values -> $date {
                my ($year, $month, $day) = $date.values;
                %converted{$field}.push: { :$year, |(:$month if $month), |(:$day if $day) };
            }
        }

        # Does the date-like field use 'raw' (in ISO format)???
        # (This could be extended to handle other 'raw' formats, but that way madness lies! :-)
        orwith $csl-raku-data{$field}<raw> {
            if / $<YYYY>=[\d\d\d\d] [ '-' $<MM>=[\d\d] [ '-' $<DD>=[\d\d] ]? ]? / {
                %converted{$field}.push: {  :year(~$<YYYY>),
                                         |(:month(~$<MM>  ) if $<MM>),
                                         |(  :day(~$<DD>  ) if $<DD>)
                                         };
            }
        }
    }

    # Insert converted fields back into the hash for the bibliographic entry...
    return %( |$csl-raku-data.pairs, |%converted );
}
