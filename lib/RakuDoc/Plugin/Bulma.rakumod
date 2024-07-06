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
	:css-link(['href="https://cdn.jsdelivr.net/npm/bulma@1.0.1/css/bulma.min.css"',1],),
    :js(['',1],),
);
submethod TWEAK {
    %!config<js>[0][0] = self.js-text;
}
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
                <body class="has-navbar-fixed-top">
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
            <nav class="navbar is-fixed-top" role="navigation" aria-label="main navigation">
            <div class="navbar-brand">
                <figure class="navbar-item is-128x128">
                    <a href="/index.html">
                    <img class="is-rounded" src="https://avatars.githubusercontent.com/u/58170775">
                    </a>
                </figure>
                <a role="button" class="navbar-burger" aria-label="menu" aria-expanded="false" data-target="pageNavigation">
                  <span aria-hidden="true"></span>
                  <span aria-hidden="true"></span>
                  <span aria-hidden="true"></span>
                  <span aria-hidden="true"></span>
                </a>
            </div>
            <div id="pageNavigation" class="navbar-menu">
                <div class="navbar-start">
                    <label class="checkbox">
                      <input id="navbar-toc-toggle" type="checkbox" />
                      Show contents
                    </label>
                </div>
                <div class="navbar-end">
                    <div class="navbar-item">
                        <button id="changeTheme" class="button">Change theme</button>
                    </div>
                </div>
            </nav>
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
method js-text {
    q:to/SCRIPT/;
    // BulmaHelper.js
    var change_theme = function (theme) {
        document.querySelector('html').className = '';
        document.querySelector('html').classList.add('theme-' + theme);
    };
    var persisted_theme = function () { return localStorage.getItem('theme') };
    var persist_theme = function (theme) { localStorage.setItem('theme', theme) };

    var persisted_tocState = function () { return localStorage.getItem('tocOpen') };
    var persist_tocState = function (tocState) { localStorage.setItem('tocOpen', tocState ) };

    document.addEventListener('DOMContentLoaded', function () {
        // set up functions needing document variables.
        var matchTocState = function ( state ) {
            if ( state ) {
                document.getElementById("TOC").classList.remove('is-hidden');
                persist_tocState( 'open');
            }
            else {
                document.getElementById("TOC").classList.add('is-hidden');
                persist_tocState( 'closed' );
            }
        }
        var setTocState = function ( state ) {
            if ( state === 'closed') {
                document.getElementById("TOC").classList.add('is-hidden');
                document.getElementById("navbar-toc-toggle").checked = false;
            }
            else {
                document.getElementById("TOC").classList.remove('is-hidden');
                document.getElementById("navbar-toc-toggle").checked = true;
            }
        };
        // initialise if localStorage is set
        let theme = persisted_theme();
        if ( theme ) {
            theme = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
            change_theme(theme);
            persist_theme(theme);
        }
        let tocState = persisted_tocState();
        if ( tocState ) {
            setTocState( tocState );
            persist_tocState( tocState );
        }

        // Add listeners
        // Get all "navbar-burger" elements
        const $navbarBurgers = Array.prototype.slice.call(document.querySelectorAll('.navbar-burger'), 0);
        // Check if there are any navbar burgers
        if ($navbarBurgers.length > 0) {
            // Add a click event on each of them
            $navbarBurgers.forEach(el => {
                el.addEventListener('click', () => {
                    // Get the target from the "data-target" attribute
                    const target = el.dataset.target;
                    const $target = document.getElementById(target);
                    // Toggle the "is-active" class on both the "navbar-burger" and the "navbar-menu"
                    el.classList.toggle('is-active');
                    $target.classList.toggle('is-active');
                });
            });
        };
        // initialise window state
        document.getElementById('changeTheme').addEventListener('click', function () {
            let theme = persisted_theme() === 'light' ? 'dark' : 'light';
            change_theme(theme);
            persist_theme(theme);
        });
        document.getElementById("navbar-toc-toggle").addEventListener('change', function() {
            matchTocState( this.checked )
        });
        document.getElementById('toc-tab').addEventListener('click', function () { swap_toc_index('toc') });
        document.getElementById('index-tab').addEventListener('click', function () { swap_toc_index('index') });
        // copy code block to clipboard adapted from solution at
        // https://stackoverflow.com/questions/34191780/javascript-copy-string-to-clipboard-as-text-html
        // if behaviour problems with different browsers add stylesheet code from that solution.
    //    $('.copy-code').click( function() {
    //        var codeElement = $(this).next().next(); // skip the label and get the div
    //        var container = document.createElement('div');
    //        container.innerHTML = codeElement.html();
    //        container.style.position = 'fixed';
    //        container.style.pointerEvents = 'none';
    //        container.style.opacity = 0;
    //        document.body.appendChild(container);
    //        window.getSelection().removeAllRanges();
    //        var range = document.createRange();
    //        range.selectNode(container);
    //        window.getSelection().addRange(range);
    //        document.execCommand("copy", false);
    //        document.body.removeChild(container);
    //    });
    });
    function swap_toc_index(activate) {
        let disactivate = (activate == 'toc') ? 'index' : 'toc';
        document.getElementById( activate + '-tab').classList.add('is-active');
        document.getElementById( disactivate + '-menu').classList.add('is-hidden');
        document.getElementById( disactivate + '-tab').classList.remove('is-active');
        document.getElementById( activate + '-menu').classList.remove('is-hidden');
    }
    SCRIPT
}