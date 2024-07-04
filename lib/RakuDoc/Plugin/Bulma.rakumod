use v6.d;
use RakuDoc::Templates;
use RakuDoc::Render;

unit class RakuDoc::Plugin::Bulma;
has %.config =
    :name-space<bulma>,
	:license<Artistic-2.0>,
	:credit<https://https://bulma.io , MIT License>,
	:version<0.1.0>,
	:css-link(['rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@1.0.1/css/bulma.min.css"',1],)
;
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates );
    $rdp.add-data( %!config<name-space>, %!config );
}
method templates {
    %(
        final => -> %prm, $tmpl {
            qq:to/PAGE/
            <!DOCTYPE html>
            <html { $tmpl<html-root> } >
                <head>
                <meta charset="UTF-8" />
                <meta name="viewport" content="width=device-width, initial-scale=1">
                { $tmpl<head-block> }
                </head>
                <body>
                { $tmpl<top-of-page> }
                { $tmpl<main-content> }
                { $tmpl<footer> }
            </body>
            </html>
            PAGE
        },
        #| the first section of body, including navigation
        top-of-page => -> %prm, $tmpl {
            my $rv = q:to/TOP/;
                <section class="section">
                  <div class="container">
                TOP
            if %prm<title-target>:exists and %prm<title-target> ne '' {
                $rv ~= qq[<div id="{
                    $tmpl('escaped', %( :contents(%prm<title-target>), ))
                }"></div>]
            }
            $rv ~= '<h1 class="title">' ~ %prm<title> ~ "</h1>\n\n" ~
            (%prm<subtitle> ?? ( '<p class="subtitle">' ~ %prm<subtitle> ~ "</p>\n" ) !! '') ~
            q:to/END/
                  </div>
                </section>
                END
        },
        #| the main section of body
        main-content => -> %prm, $tmpl {
            q:to/TOP/ ~
                <section class="section">
                  <div class="container">
                TOP
            %prm<body>.Str ~
            %prm<footnotes>.Str ~ "\n" ~
            q:to/END/
                  </div>
                </section>
                END
        },
        #| the last section of body
        footer => -> %prm, $tmpl {
            qq:to/FOOTER/;
            \n<div class="footer">
                Rendered from <span class="footer-field">{%prm<source-data><path>}/{%prm<source-data><name>}</span>
            <span class="footer-field">{sprintf( " at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<modified>.DateTime }</span>
            <span class="footer-line">Source last modified {(sprintf( "at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<source-data><modified>.DateTime)}</span>
            { qq[<div class="warnings">%prm<warnings>\</div>] if %prm<warnings> }
            </div>
            FOOTER
        },
        html-root => -> %prm, $tmpl {
           'class="theme-light"'
        }
    )
}