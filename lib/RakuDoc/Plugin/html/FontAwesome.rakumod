use experimental :rakuast;
use RakuDoc::Templates;
use RakuDoc::Render;

unit class RakuDoc::Plugin::HTML::FontAwesome;
has %.config = %(
    :name-space<fontawesom>,
	:license<Artistic-2.0>,
	:credit<https://fontawesome.com/>,
	:author<Richard Hainsworth, aka finanalyst>,
	:version<0.1.0>,
	:js-link(['defer src="https://use.fontawesome.com/releases/v5.15.4/js/all.js" integrity="sha384-rOA1PnstxnOBLzCLMcre8ybwbTmemjzdNlILg8O7z1lUkLXozs4DHonlDtnE7fpc" crossorigin="anonymous"',1],),
);
method enable( RakuDoc::Processor:D $rdp ) {
    $rdp.add-templates( $.templates, :source<FontAwesome plugin> );
    $rdp.add-data( %!config<name-space>, %!config );
}
method templates {
    %(
        'markup-ℱ' => -> %prm, $tmpl {
            "<span class=\"fa { %prm<contents> // 'fa-question-circle-o'}\"></span>"
        },
    )
}
