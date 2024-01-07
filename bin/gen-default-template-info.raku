#!/usr/bin/env raku
use v6.d;

sub MAIN(:$module = 'lib/RakuDoc/Render.rakumod', :$method = 'default-text-templates', :$dest="docs") {
    exit note "Could not find $module" unless $module.IO ~~ :e & :f;
    my $tmpl-method = 'default-text-temps';
    my %data;
    my Bool $code = False;
    my $ln;
    my $start = False;
    my $end = False;
    for $module.IO.lines {
        my $t = m/ 'method' \s+ $tmpl-method /.so;
        if $t {
            $start |= $t;
            next
        }
        next unless $start;
        next if m/ ^ \h* '%(' \h* $ /;
        last if m/ ^ \h* ');' \s* '}' /;
        if $code and m/ ^ \h+ '},' $ / {
            $code = False;
        }
        else {
            $ln ~= $_.trim ~ "\n";
            $code = True
        }
        next if $code;
        $ln ~~ /
        $<name> = (<[\w] + [ \- ]>+ | '_name') \h*
        '=> -> %' 'prm'?
        ', $' 'tmpl'?
        \h* '{'
        /;
        $ln = '';
        next unless $/;
        my $name = ~$<name>.trim;
        my $pre = ~$/.prematch.trim;
        my $pst = ~$/.postmatch.trim;
        if $name eq '_name' {
            %data{$name} = %(
                :desc($pst.trim.subst(/ ^ \' /, '').subst(/ \' $ /, ''),),
                :params(())
            );
        }
        else {
            my $desc = $pre ~~ / ['#|' \h (.+?) \s*]+ $$ / ?? $/>>.Str !! [['no description',],];
            $desc = $desc[0].elems ?? $desc[0] !! ();
            my $params = $pst ~~ m/ [.+? '%prm<' (.+?) '>']+ / ?? $/>>.Str>>.unique[0] !! [['no parameters',],];
            %data{$name} = %( :$desc, :$params)
        }
    }
    my $rakudoc = qq:to/HEAD/;
        =begin rakudoc
        =TITLE Templates in C\<{ $tmpl-method }>
        =SUBTITLE Auto generated from C\<{ $module }>
        =begin table
            =row :header
                =cell Name
                =cell Description
                =cell Parameters used
        HEAD

    for %data.sort(*.key)>>.kv -> ($name, %row) {
        my $descs = +%row<desc>;
        my $params = +%row<params>;
        my $span = max(1, $descs, $params);
        my $name-part;
        my $desc-part;
        my $param-part;

        if $span == 1 {
            $name-part = "=for cell \:label\n\t\t$name";
            $desc-part = "=cell V\<{ %row<desc>[0] }>";
            $param-part = "=cell { %row<params> }";
        }
        elsif $params == $descs {
            $name-part = "=column\n\t\t\t=for cell \:label \:row-span($span)\n\t\t\t$name";
            $desc-part = "=column\n\t\t\t" ~ (gather for %row<desc>.list { take "=cell V<$_>" }).join("\n\t\t\t");
            $param-part = "=column\n\t\t\t" ~ (gather for %row<params>.list { take "=cell $_" }).join("\n\t\t\t");
        }
        elsif $span > $descs {
            $name-part = "=column\n\t\t\t=for cell \:label \:row-span($span)\n\t\t\t$name";
            $desc-part = "=column\n\t\t\t" ~ (gather for %row<desc>.list { take "=cell V<$_>" }).join("\n\t\t\t")
                    ~ "\n\t\t\t=for cell \:row-span({ $span - $descs })\n\t\t\t-";
            $param-part = "=column\n\t\t\t" ~ (gather for %row<params>.list { take "=cell $_" }).join("\n\t\t\t");
        }
        else {
            $name-part = "=column\n\t\t\t=for cell \:label \:row-span($span)\n\t\t\t$name";
            $desc-part = "=column\n\t\t\t" ~ (gather for %row<desc>.list { take "=cell V<$_>" }).join("\n\t\t\t");
            $param-part = "=column\n\t\t\t" ~ (gather for %row<params>.list { take "=cell $_" }).join("\n\t\t\t")
                    ~ "\n\t\t\t=for cell \:row-span({ $span - $params })\n\t\t\t-";
        }
        $rakudoc ~= qq:to/ROW/;
                =row
                    $name-part
                    $desc-part
                    $param-part
            ROW

    }
    $rakudoc ~= q:to/END/;
        =end table
        =end rakudoc
        END

    "$dest/$method.rakudoc".IO.spurt($rakudoc);
}