use experimental :rakuast;
use RakuDoc::Templates;
use RakuDoc::Render;

unit class RakuDoc::Plugin::Bulma;
has %.config = %(
    :name-space<bulma>,
	:license<Artistic-2.0>,
	:credit<https://https://bulma.io , MIT License>,
	:author<Richard Hainsworth, aka finanalyst>,
	:version<0.1.0>,
	:css-link(['rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@1.0.1/css/bulma.min.css"',1],)
);
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
                { $tmpl<favicon> }
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
            my $rv = $tmpl<navigation-bar> ~ q:to/TOP/;
                <section class="section">
                  <div class="container">
                TOP
            if %prm<title-target>:exists and %prm<title-target> ne '' {
                $rv ~= qq[<div id="{
                    $tmpl('escaped', %( :contents(%prm<title-target>), ))
                }"></div>]
            }
            $rv ~= '<h1 class="title is-centered">' ~ %prm<title> ~ "</h1>\n\n" ~
            (%prm<subtitle> ?? ( '<p class="subtitle">' ~ %prm<subtitle> ~ "</p>\n" ) !! '') ~
            q:to/END/
                  </div>
                </section>
                END
        },
        #| navigation bar at top of page
        navigation-bar => -> %prm, $tmpl {
            qq:to/BLOCK/
              <div id="navMenu" class="navbar-menu">
                <div class="navbar-start">
                    <img src="https://irclogs.raku.org/camelia.png" style="width:28%; vspace:2%; hspace:2%; align:left;">
                </div>
                <div class="navbar-item">
                    <button id="changeTheme" class="button">Change theme</button>
                </div>
              </div>
            BLOCK
        },
        #| the main section of body
        main-content => -> %prm, $tmpl {
            qq:to/END/
            <div class="columns">
                <div id="TOC" class="column is-one-quarter">
                    { $tmpl<sidebar> }
                </div>
                <div class="column">
                    <div class="container px-4">
                    { %prm<body> }
                    </div>
                    <div class="container px-4">
                    { %prm<footnotes>.Str }
                    </div>
                </div>
            </div>
            END
        },
        #| Side bar to hold ToC and Index
        sidebar => -> %prm, $tmpl {
            qq:to/SIDEBAR/;
                <div class="container px-4">
                    <div class="tabs" id="tabs">
                        <ul>
                            <li class="is-active" id="toc-tab">
                                <a>Table of Contents</a>
                            </li>
                            <li id="index-tab">
                                <a>Index</a>
                            </li>
                        </ul>
                    </div>
                    <div class="container">
                        <aside id="toc-menu" class="menu">
                        { %prm<rendered-toc>
                            ?? %prm<rendered-toc>
                            !! '<p>No Table of contents for this page</p>'
                        }
                        </aside>
                        <aside id="index-menu" class="menu is-hidden">
                        { %prm<rendered-index>
                            ?? %prm<rendered-index>
                            !! '<p>No Index for this page</p>'
                        }
                        </aside>
                    </div>
                </div>
            SIDEBAR
        },
        #| the last section of body
        footer => -> %prm, $tmpl {
            qq:to/FOOTER/;
            <footer class="footer main-footer">
                <div class="container px-4">
                    <nav class="level">
                        <div class="level-item">
                            Rendered from <span class="footer-field">{%prm<source-data><path>}/{%prm<source-data><name>}</span>
                        </div>
                        <div class="level-item">
                            { sprintf( "Rendered at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<modified>.DateTime }</span>
                        </div>
                        <div class="level-item">
                            Source last modified {(sprintf( "at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<source-data><modified>.DateTime)}</span>
                        </div>
                    </nav>
                </div>
                { qq[<div class="section"><div class="container px-4 warnings">{%prm<warnings>}</div></div>] if %prm<warnings> }
            </footer>
            FOOTER
        },
        html-root => -> %prm, $tmpl {
           'class="theme-light"'
        }
    )
}