use v6.d;
use RakuDoc::Templates;
use RakuDoc::Render;

unit class RakuDoc::Plugin::LeafletMaps;
has %.config =
    :name-space<leafletmap>,
    :block-name('LeafletMap'),
	:license<Artistic-2.0>,
	:credit<https://leafletjs.com/ & https://github.com/leaflet-extras/leaflet-providers, both use BSD-2>,
	:version<0.1.0>,
    :js-link([q:to/DATA/, 1],[q:to/DATA2/, 2]),
        src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
        integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
        crossorigin=""
        DATA
        src="https://unpkg.com/leaflet-providers@latest/leaflet-providers.js"
        DATA2
	:css-link( [ q:to/DATA3/, 1 ], ),
        href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
        integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
        crossorigin=""
        DATA3
	:lat(51.4816),
	:long(-3.1807),
	:provider<OpenStreetMap>,
	:zoom(16),
	:map-id<html-extra-leaflet-map>,
;
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates );
    $rdp.add-data( %!config<name-space>, %!config );
}
method templates {
    %(
        LeafletMap => sub (%prm, $tmpl) {
            my $proc = run <ping -c 1 unpkg.com>, :err, :out;
            unless $proc.out.slurp(:close) { # if ping does not give output can't reach libraries
                return q:to/RSP/
                <div style="color: red">
                    Internet access to ｢unpkg.com｣ is needed for map libraries, so map cannot be shown.
                </div>
                RSP
            }
            my %leaflet := $tmpl.globals.data<leafletmap>;
            my $map-id = %prm<map-id> // %leaflet<map-id>;
            my $var-name = 'v' ~ $map-id.trans('-' => '_');
            my $lat = %prm<lat> // %leaflet<lat>;
            my $long = %prm<long> // %leaflet<long>;
            my $zoom = %prm<zoom> // %leaflet<zoom>;
            my $height = %prm<height> // %leaflet<height>;
            my $width = %prm<width>; # should do this in CSS, but sometimes ...
            my $provider = %prm<provider> // %leaflet<provider>;
            my $apikey = %leaflet<api-key> // ''; # only put secret info in config file
            qq:to/MAP/;
            <div id="$map-id"
            style="height: { $height // '200px' }; { "width: $width;" if $width }"
            >
            </div>
            <script>
                var $var-name = L.map('$map-id').setView([$lat, $long], $zoom);
                  L.tileLayer.provider('$provider' { ', { apikey: \'' ~ $apikey ~ '\' }' if $apikey }).addTo($var-name);
            </script>
            MAP
        },
        LeafMarker => sub (%prm, $tmpl) {
            my %leaflet := $tmpl.globals.data<leafletmap>;
            my $map-id = 'v' ~ (%prm<map-id> // %leaflet<map-id>).trans('-' => '_');
            my $lat = %prm<lat>;
            my $long = %prm<long>;
            my $icon;
            my $name;
            with %prm<fa-icon> {
                $name = [~](('a'..'z').pick(9)); # random variable name
                $icon = qq:to/ICO/
                    const $name = L.divIcon(\{
                        html: '<span class="fa $_"></span>',
                        iconSize: [20, 20],
                        className: 'myDivIcon'
                    });
                    ICO
            }
            my $popup = %prm<popup>;
            my $title = %prm<title>;
            qq:to/MARKER/;
            <script>
            { $icon if $icon }

            L.marker(\[$lat, $long], \{ {
                ("icon: $name" if $icon)
                ~ (',' if ($icon and $title))
                ~ ("title: '$title'" if $title)
            } }).addTo($map-id)
            { ".bindPopup('$popup')" if $popup }
            </script>
            MARKER
        },
    )
}
