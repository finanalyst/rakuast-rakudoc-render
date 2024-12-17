use v6.d;
use RakuDoc::To::HTML;

#| the plugins to be attached to the processor
#| the order of the plugins matters as templates names
#| attached last are used first
our @HTML-Extra-plugins = <LeafletMaps Latex Graphviz Bulma FontAwesome ListFiles Hilite SCSS>;

class RakuDoc::To::HTML-Extra is RakuDoc::To::HTML {
    #| keys reserved for assets in HTML page, so Plugins may not claim any as a name-space.
    has @!reserved = <css css-link js js-link>;

    submethod TWEAK {
        my $rdp := self.rdp;
        $rdp.add-templates(self.templates, :source<HTML-Extra>);
        if 'rakudoc-config.raku'.IO ~~ :e & :f {
            @HTML-Extra-plugins = EVALFILE('rakudoc-config.raku');
            note 'Plugins required are: ', @HTML-Extra-plugins;
        }
        for @HTML-Extra-plugins -> $plugin {
            require ::("RakuDoc::Plugin::HTML::$plugin");
            CATCH {
                note "RakuDoc::Plugin::HTML::$plugin is not installed";
                .resume
            }
            try {
                ::("RakuDoc::Plugin::HTML::$plugin").new.enable( $rdp )
            }
            with $! {
                note "Could not enable RakuDoc::Plugin::HTML::$plugin\. Error: ", .message;
            }
        }
        for <css-link js-link js css> {
            # prevent duplication of CSS if both css and scss are provided in a plugin
            next if $_ eq 'css' and ( 'SCSS' (elem) @HTML-Extra-plugins ) and $rdp.templates.data<scss>:exists;
            self.gather-flatten($rdp, $_)
        }
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
    #| plugins provide config information about css/js & cdn as arrays of Str/order arrays
    #| This needs to be gathered from all plugins, and processed for templates
    method gather-flatten( $rdp, $key ) {
        my %d := $rdp.templates.data;
        my %valid = %d.pairs
            .grep({ .key ~~ none(@!reserved) })
            .grep({ .value.{ $key } ~~ Positional })
            .map( { .key => .value.{ $key } });
        my @p-tuples;
        for %valid.kv -> $plugin, $tuple-list {
            if $tuple-list ~~ Positional {
                for $tuple-list.list {
                    if .[0] ~~ Str && .[1] ~~ Int {
                        @p-tuples.push: $_
                    }
                    else { note "Element ｢$_｣ of config attribute ｢$key｣ for plugin ｢$plugin｣ not a [Str, Int] tuple"}
                }
            }
            else { note "Config attribute ｢$key｣ for plugin ｢$plugin｣ must be a Positional, but got ｢$tuple-list｣"}
        }
        if %d{ $key }:exists { # this is true for css from HTML, add it with zero order.
            @p-tuples.push: [ %d{ $key }, 0]
        }
        %d{ $key } = @p-tuples.sort({ .[1], .[0] }).map( *.[0] ).list;
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