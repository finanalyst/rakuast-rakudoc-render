use experimental :rakuast;
use RakuDoc::Templates;
use RakuDoc::PromiseStrings;
use RakuDoc::Render;

unit class RakuDoc::Plugin::Bulma;
has %.config = %(
    :name-space<bulma>,
	:license<Artistic-2.0>,
	:credit<https://https://bulma.io , MIT License>,
	:author<Richard Hainsworth, aka finanalyst>,
	:version<0.1.0>,
	:css-link(['href="https://cdn.jsdelivr.net/npm/bulma@1.0.1/css/bulma.min.css"',1],),
	:js-link(['src="https://rawgit.com/farzher/fuzzysort/master/fuzzysort.js"',1],),
    :js([self.js-text,2],), # 1st element is replaced in TWEAK
    :scss([self.chyron-scss,1], [ self.toc-scss, 1],),
);
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates, :source<Bulma plugin>);
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
            $tmpl<navigation-bar> ~
            $tmpl<page-navigation>
        },
        #| navigation bar at top of page
        navigation-bar => -> %prm, $tmpl {
            qq:to/BLOCK/
            <nav class="navbar is-fixed-top" role="navigation" aria-label="main navigation">
                <div class="navbar-brand">
                    <figure class="navbar-item is-256x256">
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
                        <label class="chyronToggle">
                          <input id="navbar-toc-toggle" type="checkbox" />
                          <span class="checkmark"> </span>
                        </label>
                    </div>
                    <div class="navbar-end">
                        <div class="navbar-item">
                            <button id="changeTheme" class="button">Change theme</button>
                        </div>
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
                    { $tmpl<title-section> }
                    <div class="content px-4">
                    { %prm<body> }
                    </div>
                    <div class="content px-4">
                    { %prm<footnotes>.Str }
                    </div>
                </div>
            </div>
            END
        },
        #| title and subtitle
        title-section => -> %prm, $tmpl {
            my $rv = q:to/TOP/;
                <section class="section">
                  <div class="container">
                TOP
            if %prm<title-target>:exists and %prm<title-target> ne '' {
                $rv ~= qq[<div id="{
                    $tmpl.globals.escape.( %prm<title-target> )
                }"></div>]
            }
            $rv ~= '<h1 class="title is-centered">' ~ %prm<title> ~ "</h1>\n\n" ~
            (%prm<subtitle> ?? ( '<p class="subtitle">' ~ %prm<subtitle> ~ "</p>\n" ) !! '') ~
            q:to/END/
                  </div>
                </section>
                END
        },
        #| Side bar to hold ToC and Index
        sidebar => -> %prm, $tmpl { '' },
        page-navigation => -> %prm, $tmpl {
            qq:to/SIDEBAR/;
            <nav class="panel" id="page-nav">
              <div class="panel-block">
                <p class="control has-icons-left">
                  <input class="input" type="text" placeholder="Search" id="page-nav-search"/>
                  <span class="icon is-left">
                    <i class="fas fa-search" aria-hidden="true"></i>
                  </span>
                </p>
              </div>
              <p class="panel-tabs">
                <a id="toc-tab">Table of Contents</a>
                <a id="index-tab">Index</a>
              </p>
                <aside id="toc-menu" class="panel-block">
                { %prm<rendered-toc>
                    ?? %prm<rendered-toc>
                    !! '<p>No Table of contents for this page</p>'
                }
                </aside>
                <aside id="index-menu" class="panel-block is-hidden">
                { %prm<rendered-index>
                    ?? %prm<rendered-index>
                    !! '<p>No Index for this page</p>'
                }
                </aside>
            </nav>
            SIDEBAR
        },
        #| special template to render the toc list
        toc => -> %prm, $tmpl {
            if %prm<toc-list>:exists && %prm<toc-list>.elems {
                PStr.new: qq[<div class="toc">] ~
#                ( "<h2 class=\"toc-caption\">$_\</h2>" with  %prm<caption> ) ~
                ([~] %prm<toc-list>) ~
                "</div>\n"
            }
            else {
                PStr.new: ''
            }
        },
        #| special template to render the index data structure
        index => -> %prm, $tmpl {
#            my $cap = %prm<caption>:exists ?? qq[<h2 class="index-caption">{%prm<caption>}</h2>] !! '';
            my @inds = %prm<index-list>.grep({ .isa(Str) || .isa(PStr) });
            if @inds.elems {
                PStr.new: '<div class="index">' ~ "\n" ~
                ([~] @inds ) ~ "\n</div>\n"
            }
            else { 'No indexed items' }
        },
        #| the last section of body
        footer => -> %prm, $tmpl {
            qq:to/FOOTER/;
            <footer class="footer main-footer">
                <div class="container px-4">
                    <nav class="level">
                        <div class="level-item">
                            Rendered from <span class="footer-field">{%prm<source-data><path>}/{%prm<source-data><name>}
                        </div>
                        <div class="level-item">
                            { sprintf( "Rendered at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<modified>.DateTime }
                        </div>
                        <div class="level-item">
                            Source last modified {(sprintf( "at %02d:%02d UTC on %s", .hour, .minute, .yyyy-mm-dd) with %prm<source-data><modified>.DateTime)}
                        </div>
                    </nav>
                </div>
                { qq[<div class="section"><div class="container px-4 warnings">{%prm<warnings>}</div></div>] if %prm<warnings> }
            </footer>
            FOOTER
        },
        html-root => -> %prm, $tmpl {
           'class="theme-light" style="scroll-padding-top:var(--bulma-navbar-height)"'
        },
        #| adapt head for Bulma by adding class
        #| renders =head block
        head => -> %prm, $tmpl {
            my $del = %prm<delta> // '';
            %prm<classes> = "heading {'delta' if $del} py-2";
            $tmpl.prev(%prm)
        },
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
                document.getElementById("page-nav").classList.remove('is-hidden');
                persist_tocState( 'open');
            }
            else {
                document.getElementById("TOC").classList.add('is-hidden');
                document.getElementById("page-nav").classList.add('is-hidden');
                persist_tocState( 'closed' );
            }
        }
        var setTocState = function ( state ) {
            if ( state === 'closed') {
                document.getElementById("TOC").classList.add('is-hidden');
                document.getElementById("page-nav").classList.add('is-hidden');
                document.getElementById("navbar-toc-toggle").checked = false;
            }
            else {
                document.getElementById("TOC").classList.remove('is-hidden');
                document.getElementById("page-nav").classList.remove('is-hidden');
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
        var TOC = document.getElementById('toc-menu');
        var Index = document.getElementById('index-menu');
        var originalTOC = TOC.getHTML();
        var originalIndex = Index.getHTML();
        document.getElementById("page-nav-search").addEventListener('keyup', function (event) {
            TOC.innerHTML = originalTOC;
            Index.innerHTML = originalIndex;
            var searchText = event.srcElement.value.toLowerCase();
            if (searchText.length === 0) return;
            var menuListElements = document.getElementById('page-nav').querySelectorAll('.toc-item, .index-section');
            var matchingListElements = Array.from(menuListElements).filter(function (item) {
                var el;
                if ( item.classList.contains('toc-item') ) {
                    el = item.querySelector('a');
                } else {
                    el = item.querySelector('.index-entry')
                }
                var listItemHTML = el.innerHTML;
                var fuzzyRes = fuzzysort.go(searchText, [listItemHTML])[0];
                if (fuzzyRes === undefined || fuzzyRes.score <= 0) {
                    return false;
                }
                var res = fuzzyRes.highlight('<b>','</b>');
                if (res !== null) {
                    el.innerHTML = res;
                    return true;
                } else {
                    return false;
                }
            });
        menuListElements.forEach(function(elem){elem.classList.add('is-hidden')});
        matchingListElements.forEach(function(elem){elem.classList.remove('is-hidden')});
        });
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
method chyron-scss {
    q:to/CHYRON/;
    // Chyron Toggle checkbox
    label.chyronToggle input#navbar-toc-toggle {
        opacity: 0;
        height: 0;
        width: 0;
    }
    label.chyronToggle span.checkmark {
        top: 1rem;
        position: relative;
        cursor: pointer;
    }
    label.chyronToggle input[type="checkbox"]{
        position: absolute;
        opacity: 0;
        cursor: pointer;
        height: 0;
        width: 0;
    }
    label.chyronToggle span.checkmark::before {
        content: '[\21e8';
        color: grey;
        font-weight: 800;
        line-height: 0.5rem;
        font-size: 1.75rem;
        margin-right: 0.25rem;
    }
    label.chyronToggle:hover span.checkmark::before {
        content: '[ \21e8';
    }
    label.chyronToggle input[type="checkbox"]:checked + .checkmark::before {
        content: '[ \21e6';
    }
    label.chyronToggle:hover input[type="checkbox"]:checked + .checkmark::before {
        content: '[\21e6';
    }
    CHYRON
}
method toc-scss {
    q:to/TOC/;
    #page-nav {
        width: 25%;
        position: fixed;
    }
    #page-nav .panel-block .toc {
        overflow-y:scroll;
        height:65vh;
    }
    #page-nav .panel-block .index {
        overflow-y:scroll;
        height:65vh;
    }
    .main-footer {
        z-index: 1;
        position: relative;
    }
    TOC
}