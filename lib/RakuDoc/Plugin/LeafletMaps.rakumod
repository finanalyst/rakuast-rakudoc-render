use v6.d;
use RakuDoc::Templates;

unit class RakuDoc::Plugin::LeafletMaps;
has %.config =
    :block-name('LeafletMap'),
	:license<Artistic-2.0>,
	:credit<https://leafletjs.com/ & https://github.com/leaflet-extras/leaflet-providers, both use BSD-2>,
    :js-link(q:to/DATA/),
		src="https://unpkg.com/leaflet@1.8.0/dist/leaflet.js"
		integrity="sha512-BB3hKbKWOc9Ez/TAwyWxNXeoV9c1v6FIeYiBieIWkpLjauysF18NzgR1MBNBXf8/KABdlkX68nAhlwcDFLGPCQ=="
		crossorigin=""
		DATA
	:js-script( [ "leaflet-providers.js", 1 ] ),
	:lat(51.4816),
	:long(-3.1807),
	:provider<OpenStreetMap>,
	:zoom(16)
;