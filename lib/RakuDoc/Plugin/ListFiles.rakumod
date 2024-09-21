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
    :scss([self.add-scss,1],),
;
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates, :source<ListFiles plugin> );
    $rdp.add-data( %!config<name-space>, %!config );
}
method templates {
    my regex s-pair {
        (<-[=]>+) \= (.+)
    };
    my regex select {
        ^ <s-pair>+ % [\,\s] $
    };
    %(
        ListFiles => sub (%prm, $tmpl) {
            return qq:to/ERROR/ unless %prm<select>:exists;
                <div class="listf-error">
                ListFiles needs :select key with criteria.
                </div>
                ERROR

            my $sel = %prm<select>;
            my %criteria;
            if $sel ~~ / <select> / {
                for $/<select><s-pair> { %criteria{~$_[0].trim} = ~$_[1] }
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
            return q:to/ERROR/ unless $tmpl.globals.data<listfiles><meta>:exists;
                <div class="listf-error">ListFiles has no collected data
                </div>
                ERROR

            my @sel-files;
            for $tmpl.globals.data<listfiles><meta>.kv -> $fn, %data {
                # data is config, title, desc
                my Bool $ok;
                for %criteria.kv -> $k, $v {
                    if $v eq '!' {
                        $ok = %data<config>{$k}:!exists;
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
                    <div class="listf-container" id="{ $tmpl('escaped', %( :contents(%prm<target>),)) }">
                    FIRST
            my $cap = qq:to/CAP/;
                    <p class="listf-caption">{ %prm<raw>.trim }</p>
                    CAP
            for  @sel-files.sort(*.[0]) -> ($nm, $desc, $path) {
                $rv ~= qq:to/NOFL/;
                    <div class="listf-file">
                    $cap
                    <a class="listf-link" href="$path">$nm\</a>
                    $desc\</div>
                    NOFL
                $cap = '';
            }
            unless +@sel-files {
                $rv ~= qq:to/NOFL/;
                    <div class="listf-file">
                    $cap
                    No files meet the criteria: {%criteria.raku}
                    </div>
                    NOFL
            }
            $rv ~= '</div>'
        },
    )
}
method add-scss {
    q:to/SCSS/;
    .listf-container {
      display: flex;
      flex-direction: column;
      margin-bottom: 1.25rem;
      font-size: 1rem;
      font-weight: 500;
      line-height: 1.5;
      border: 1px solid #cccccc;
      border-bottom: 5px solid #d9d9d9;
      box-shadow: 0 2px 3px 0 rgba(0, 0, 0, 0.07);
      .listf-caption {
          display: flex;
          justify-content: center;
          background: #f2f2f2;
          border-bottom: 1px solid #cccccc;
          color: #83858D;
      }
      .listf-file {
          display: inline-block;
          border-top: 1px solid #cccccc;
          border-bottom: 1px solid #cccccc;
          break-inside: avoid;
          .listf-link {
              display: inline-block;
              width: 100%;
              text-align: center;
              padding-top: 0.25rem;
          }
          p {
              padding-left: 0.5rem;
              padding-right: 0.5rem;
              margin-bottom: 0.25rem;
          }
      }
    }
    .listf-error {
      color: red;
      font-size: xlarge;
    }
    SCSS
}