use v6.d;
use JSON::Fast;
use YAMLish;
use XML;

# Adapted from Damian Conway's prototype

unit module RakuDoc::Citations;

# Use the appropriate external utility or utilities to convert any supported format to CSL-Raku...
sub convert-to-CSL-Raku ( $data, @warnings ) is export {

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
        @warnings.push: "Could not understand $data-format citation data\n", ~($! // q{}, $data);
        return ();
    }

    # Convert valid JSON and return, or warn that something went wrong...
    with try from-json $csl-json -> $csl-raku {
        return $csl-raku.values;
    }
    else {
        @warnings.push: "Could not understand $data-format citation data\n", ~($! // q{});
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

# Useful external translation apps for citation data...
sub pandoc       ($data, :$from) { filter :fail<[]> :$data, 'pandoc', « -f $from -t csljson » }
sub xml2biblatex ($data)         { filter :fail()   :$data, 'xml2biblatex'                    }
sub med2xml      ($data)         { filter :fail()   :$data, 'med2xml'                         }
sub nbib2xml     ($data)         { filter :fail()   :$data, 'nbib2xml'                        }

# Format indicators and citation data into a set of markers and a bibliographic list...
sub citeproc     ($data, :$STYLE, :$LOCALE) is export {
    filter :fail(Nil) :$data, 'pandoc', « --citeproc -t markdown_strict »,
            "--metadata=lang:$LOCALE", "--csl=$STYLE";
}

# Internal converter from BibTeX XML to classic BibTeX...
sub bibtexml-to-bibtex(Str $data) {
    use XML;

    # Extract data from XML tags...
    my $doc = from-xml($data);

    # Helper sub to locate nested entries by name...
    sub find-elements-by-local-name($node, $local-name) {
        my @found;
        for $node.elements -> $el {
            # Match 'entry' or 'bibtex:entry'
            if $el.name ~~ / [ ':' | ^ ] $local-name $/ {
                @found.push: $el;
            }
            @found.append: find-elements-by-local-name($el, $local-name);
        }
        return @found;
    }

    # Find entries...
    my @entries = find-elements-by-local-name($doc.root, 'entry');

    # Translate entries...
    my @bibtex-output = gather for @entries -> $entry {
        # Get the ID attribute...
        my $id = $entry.attribs<id>.Str // 'unknown_id';

        # Find the type node (e.g. <bibtex:book>)...
        my $type-node = $entry.elements.first;
        next unless $type-node;

        # Remove the leading bibtex: from the name...
        my $type = $type-node.name.split(':').tail;

        # Collect other fields...
        my @fields = gather for $type-node.elements -> $field {
            my $key   = $field.name.split(':').tail;

            # Extract value (using .text if available, otherwise fallback to node mapping)...
            my $value = $field.can('text')
                    ?? $field.text
                    !! $field.nodes.grep(* ~~ XML::Text).map(*.text).join;

            $value = $value.trim;

            # Escape internal braces...
            $value ~~ s:g/ '{' /\\\{/;
            $value ~~ s:g/ '}' /\\\}/;

            take "  $key = \{$value\}";
        }

        take "\@$type\{$id,\n" ~ @fields.join(",\n") ~ "\n\}";
    }

    return @bibtex-output.join("\n\n");
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
sub convert-dates ($csl-raku-data) is export {

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