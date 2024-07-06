use v6.d;
use RakuDoc::Templates;
use RakuDoc::Render;

unit class RakuDoc::Plugin::ListFiles;
has %.config =
    :name-space<listfiles>,
	:version<0.1.0>,
    :block-name('ListFiles'),
	:license<Artistic-2.0>,
	:credit<finanalyst>,
	:authors<finanalyst>,
    :css(['',1],),
;
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates );
    $rdp.add-data( %!config<name-space>, %!config );
}
method templates {
    my regex s-pair {
        (\S+?) \s* \= \s* (\S+)
    };
    my regex select {
        ^ <s-pair>+ % [\,\s] $
    };
    %(
        ListFiles => => sub (%prm, $tmpl) {
            return qq:to/ERROR/ unless %prm<select>:exists;
                <div class=\"listf-error\">ListFiles needs :select key with criteria.
                </div>
                ERROR

            my $sel = %prm<select>;
            my %criteria;
            if $sel ~~ / <select> / {
                for $/<select><s-pair> { %criteria{~$_[0]} = ~$_[1] }
            }
            else {
                return qq:to/ERROR/
                    <div class="listf-error">
                    ListFiles :select key does not parse, must be one pair of form ｢\\S+ \\s* = \\s* \\S+｣
                    or a comma-separated list of such pairs. Got
                    { %prm<select> }
                    </div>
                    ERROR

                 }
            # check meta data exists
            return q:to/ERROR/ unless %prm<listfiles><meta>:exists;
                <div class="listf-error">ListFiles has no collected data
                </div>
                ERROR

            my @sel-files;
            for %prm<listfiles><meta>.kv -> $fn, %data {
                # data is config, title, desc
                my Bool $ok;
                for %criteria.kv -> $k, $v {
                    if $v eq '!' {
                        $ok = ! %data<config>{$k}:exists;
                    }
                    else {
                        $ok = (%data<config>{$k}:exists and ?(%data<config>{$k} ~~ / <$v> /));
                    }
                    last unless $ok
                }
                next unless $ok;
                @sel-files.push: [
                    ((%data<title> eq '' or %data<title> eq 'NO_TITLE') ?? $fn !! %data<title> ),
                    (%data<subtitle> ?? %data<subtitle> !! 'No description found'),
                    $fn
                ];
            }
            my $rv = qq:to/FIRST/;
                    <div class="listf-container" { %prm<target> ?? ('id="' ~ $tmpl<escaped>( %( :contents(%prm<target>),)) ~ '"') !! '' }>
                    FIRST
            my $cap = qq:to/CAP/;
                    <p class="listf-caption">{ %prm<raw> // '' }</p>
                    CAP
            for  @sel-files.sort(*.[0]) -> ($nm, $desc, $path) {
                $rv ~= '<div class="listf-file">'
                        ~ ($cap // '')
                        ~ '<a class="listf-link" href="' ~ $path ~ '">' ~ $nm ~ '</a>'
                        ~ $desc ~ '</div>';
                $cap = Nil;
            }
            unless +@sel-files {
                $rv ~= '<div class="listf-file">'
                        ~ ($cap // '')
                        ~ (%prm<no-files> ?? %prm<no-files> !! ('No files meet the criteria: ' ~ %criteria.raku ))
                        ~ '</div>';
                $cap = Nil;
            }
            $rv ~= '</div>'
        },
    )
}