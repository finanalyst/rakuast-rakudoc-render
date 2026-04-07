use v6.d;
use JSON::Fast;
use YAMLish;
use XML;
# Adapted from Damian Conway's prototype

unit module RakuDoc::Citations;
constant CSL = '/home/richard/development/rakuast-rakudoc-render/RakuDoc-citations-demo/csl';
class X::BadCitation is Exception {
    has $.extra;
    method message { "A citeproc dependency failed. " ~ $.extra }
}

multi sub csl-json-to-rakudoc( Str $el ) { $el }
multi sub csl-json-to-rakudoc( Hash $el, :$bullet = '', :$id = '' ) {
    given $el<format> {
        when 'italics' { 'I«' ~ csl-json-to-rakudoc( $el<contents> ) ~ '»' }
        when 'bold' { 'B«' ~ csl-json-to-rakudoc( $el<contents> ) ~ '»' }
        when 'small-caps' { 'W«' ~ csl-json-to-rakudoc( $el<contents> ) ~ '»' }
        when 'div' {
            "=for item :id<$id>" ~
            (" :bullet\<$bullet>" if $bullet ) ~
            "\n" ~
            csl-json-to-rakudoc( $el<contents> ) ~
            "\n"
        }
        when 'link' {
            'L«' ~ csl-json-to-rakudoc( $el<contents> ) ~ '|' ~ $el<target> ~ '»'
        }
        default { '=for para :id<' ~ $id ~ ">\n" ~ $el.Str }
    }
}
multi sub csl-json-to-rakudoc( Array $el, :$id = '' ) {
    my $bullet = '';
    my $rv =
            [~] gather for $el.list {
                if .<class>:exists and .<class> eq 'csl-left-margin' {
                    $bullet = csl-json-to-rakudoc( .<contents> );
                }
                elsif .isa(Hash) {
                    take csl-json-to-rakudoc( $_, :$bullet, :$id )
                }
                else { take .Str }
            }
            ;
    $rv = "=for para :id<$id>\n$rv\n" if $id and !$bullet;
    $rv
}
sub csl-lint( $csl ) is export {
    my %rv = $csl.hash;
    for <author editor translator> {
        %rv{$_} = [%rv{$_}] if %rv{$_}:exists and %rv{$_}.isa(Hash);
    }
    for <container-title title note> {
        %rv{$_} = %rv{$_}.Str if %rv{$_}:exists and %rv{$_}.isa(Str).not;
    }
    convert-dates(%rv)
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
                %converted{$field} = { :$year, |(:$month if $month), |(:$day if $day) };
            }
        }

        # Does the date-like field use 'raw' (in ISO format)???
        # (This could be extended to handle other 'raw' formats, but that way madness lies! :-)
        orwith $csl-raku-data{$field}<raw> {
            if / $<YYYY>=[\d\d\d\d] [ '-' $<MM>=[\d\d] [ '-' $<DD>=[\d\d] ]? ]? / {
                %converted{$field} = {  :year(~$<YYYY>),
                                        |(:month(~$<MM>  ) if $<MM>),
                                        |(  :day(~$<DD>  ) if $<DD>)
                };
            }
        }
    }

    # Insert converted fields back into the hash for the bibliographic entry...
    return %( |$csl-raku-data.pairs, |%converted );
}
sub citation-placeholder( $id, $msg ) is export {
    %(
        :$id,
        type            => "article",
        title           => "$msg: $id",
        author          => [ { family => "Unknown", given => "?" }, ],
        container-title => "Check warnings for ｢$id｣"
    )
}
sub test-citation( @tuple , @warnings ) {
    my $proc = run ('citeproc', '--style='~CSL~'/ieee.csl' ),:in,:out,:err ;
    my ($id, $csl) = @tuple;

    my $input = to-json( %( references => [ $csl ] ) );
    sink so $proc.in.print( $input );
    sink so $proc.in.close;
    if !$proc or $proc.exitcode !=0 {
        @warnings.push: "For ｢$id｣:" ~ $proc.err.slurp(:close) ~ "Got: " ~ to-json($csl);
        $csl = citation-placeholder($id, "Citation doesn't match CSL standard, check warnings")
    };
    [$id, $csl];
}
#| convert raw citation data, detect entry type, convert to cls-json and an id
sub convert-to-id-cls( $data, @warnings --> Positional ) is export {
    state $noIDcount = 1;
    my $id;

    # What kind of citation data is it???
    my $data-format = sniff-test($data);

    # Whatever it is, convert it to CSL-JSON...
    my $csl = do given $data-format {

        # Already Raku data, so just reify it, check it, and return it (skipping the de-JSON-ification)...
        # (Note: must add an empty dummy hash at the beginning of the list, then strip it after conversion
        #        because EVAL sometimes gets muddled on single-hash '[{...}]' source data)...
        when 'CSL-Raku'   {
            use MONKEY-SEE-NO-EVAL;
            my $csl-raku = try EVAL "[\%(),$data]";
            CATCH {
                @warnings.push: "Invalid CSL-Raku citation data with\n$data" ;
                my $id = 'Invalid_' ~ $noIDcount++ ;
                $csl-raku = [ %(), citation-placeholder($id, "Invalid CSL-Raku, see warnings"), ];
            }

            $csl-raku.tail(*-1)
        }

        # Already CSL data, so just de-YAML-ize it, and return it (skipping the de-JSON-ification)...
        when 'CSL-YAML'   { load-yaml($data).values}

        # CSL-JSON data, convert to RakuCLS to extract id and verify
        when 'CSL-JSON'   { from-json($data).values }

        # Pandoc can directly translate these formats to CSL-JSON...
        when 'RIS'        { from-json(pandoc :from<ris>,      left-justify $data).values }
        when 'BibLaTeX'   { from-json(pandoc :from<biblatex>,              $data).values }
        when 'BibTeX'     { from-json(pandoc :from<bibtex>,                $data).values }

        # for BibTeXML:   BibTeXML ––(internal conversion)––> BibTeX ––(pandoc)––> CSL-JSON...
        when 'BibTeXML'   { from-json(pandoc :from<bibtex>,  bibtexml-to-bibtex $data).values }

        # for PubMedNBIB: NBIB ––(nbib2xml)––> MODS ––(xml2biblatex)––> BibLaTeX ––(pandoc)––> CSL-JSON...
        when 'PubMedNBIB' { from-json(pandoc :from<biblatex>,  xml2biblatex  nbib2xml  left-justify $data).values }

        # for PubMedXML:  PMXML ––(med2xml)––> MODS ––(xml2biblatex)––> BibLaTeX ––(pandoc)––> CSL-JSON...
        when 'PubMedXML'  { from-json(pandoc :from<biblatex>,  xml2biblatex  med2xml $data).values }

        # for MODS:       MODS ––(xml2biblatex)––> BibLaTeX ––(pandoc)––> CSL-JSON...
        when 'MODS'       { from-json(pandoc :from<biblatex>,  xml2biblatex $data).values }

        # No data or bad data...
        default           {
            @warnings.push: "Could not understand $data-format citation data\n", ~($! // q{}, $data);
            my $id = 'Bad_format_' ~ $noIDcount++ ;
            citation-placeholder($id, 'Bad format of citation' ),
        }
    }
    $csl
        .map({ csl-lint( $_ ) })
        .map({ if .<id>:!exists { .<id> = 'MissingID_' ~ $noIDcount++ }; $_ })
        .map({ [ .<id>, $_ ] })
        .map({ test-citation($_, @warnings ) })
        .Array
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
        X::BadCitation.new( :extra("Call to @command[0] failed:\n" ~ $proc.err.slurp ~ " using: $data") ).throw;
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
sub citeproc     ($data, $style, :$link = True) is export {
    filter :fail(Nil), :$data, 'citeproc', '--format=json', "--style={CSL}/$style.csl", ( '--link-citations' if $link );
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

# expects input to have keys of citations, lang, style, and references
# the keys point to data in form expe
sub process-citations( %input, @warnings, :$link = True) is export {
    my $style := %input<style>;
    my $input-json = to-json( %input );

    # Run citeproc to generate the final renderings...
    my $citeproc = citeproc($input-json, $style, :$link);
    CATCH {
        @warnings.push: "citeproc error, ignoring Q<> or citation listing: " ~ .message;
        return %( markers => [], bibliography => [] )
    }
    my %cit-output = from-json $citeproc;

    my @markers = %cit-output<citations>
        .map({ $_ = csl-json-to-rakudoc( $_ ) });
    my @bibliography = %cit-output<bibliography>
        .map({ $_ = csl-json-to-rakudoc( $_[1], :id( 'ref-' ~ $_[0] ) ) });
    %( :@markers, :@bibliography )
}