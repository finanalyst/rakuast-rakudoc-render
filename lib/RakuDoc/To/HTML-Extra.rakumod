use v6.d;
use RakuDoc::To::HTML;

class RakuDoc::To::HTML-Extra is RakuDoc::To::HTML {
    #| keys reserved for assets in HTML page, so Plugins may not claim any as a name-space.
    has @!reserved = <css css-link js js-link>;

    submethod TWEAK {
        my $rdp := self.rdp;
        # templates are attached first as plugins may over-ride base templates
        $rdp.add-templates(self.templates, :source<HTML-Extra>);

        #| the plugins to be attached to the processor
        #| the order of the plugins matters as templates names
        #| attached last are used first
        my @HTML-Extra-plugins = <LeafletMaps Latex Graphviz Bulma FontAwesome ListFiles Hilite SCSS>;
        if 'rakudoc-config.raku'.IO ~~ :e & :f {
            @HTML-Extra-plugins = EVALFILE('rakudoc-config.raku');
            note 'Plugins required are: ', @HTML-Extra-plugins;
        }
        $rdp.add-plugins( 'RakuDoc::Plugin::HTML::' «~« @HTML-Extra-plugins );
        # run the scss to css conversion after all plugins have been enabled
        # makes SCSS position independent
        if $rdp.templates.data<SCSS>:exists {
            $rdp.templates.data<SCSS><run-sass>.( $rdp )
        }
        else { $rdp.gather-flatten( 'css', :@!reserved) }
        $rdp.gather-flatten(<css-link js-link js>, :@!reserved )
    }

    method render($ast) {
        my $fn = $*PROGRAM;
        my %source-data =
            name     => ~$fn,
            modified => $fn.modified,
            path     => $fn.dirname,
        ;
        self.new.rdp.render( $ast, :%source-data  )
    }
    method templates {
        %( # replace the template that governs where CSS and JS go
            #| head-block, what goes in the head tab
            head-block => -> %prm, $tmpl {
                my %g-data := $tmpl.globals.data;
                # handle css first
                qq:to/HEAD/
                <title>{%prm<title>}</title>
                { $tmpl<favicon> }
                {%g-data<css>:exists && %g-data<css>.elems ??
                    [~] %g-data<css>.map({ '<style>' ~ $_ ~ "</style>\n" })
                !! ''
                }
                {%g-data<css-link>:exists && %g-data<css-link>.elems ??
                    [~] %g-data<css-link>.map({ '<link rel="stylesheet" ' ~ $_ ~ "/>\n" })
                !! ''
                }
                {%g-data<js-link>:exists && %g-data<js-link>.elems ??
                    [~] %g-data<js-link>.map({ '<script ' ~ $_ ~ "></script>\n" })
                !! ''
                }
                {%g-data<js>:exists && %g-data<js>.elems ??
                    [~] %g-data<js>.map({ '<script>' ~ $_ ~ "</script>\n" })
                !! ''
                }
                HEAD
            },
            #| download the Camelia favicon
            favicon => -> %prm, $tmpl {
                q[<link rel="icon" href="https://irclogs.raku.org/favicon.ico">]
            },
        )
    }
}
