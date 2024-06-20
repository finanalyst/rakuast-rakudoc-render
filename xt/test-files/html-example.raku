%(
    head-block => -> %prm, $tmpl {
        q[<meta
            name="description"
            content="A Customised description"
        />] ~
        $tmpl.prev
    }
)