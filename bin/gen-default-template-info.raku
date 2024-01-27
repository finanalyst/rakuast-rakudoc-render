#!/usr/bin/env raku
use v6.d;

sub MAIN(:$module = 'lib/RakuDoc/Render.rakumod', :$method, :$dest="docs") {
    exit note "Could not find $module" unless $module.IO ~~ :e & :f;
    exit note "No directory $dest" unless $dest.IO ~~ :e & :d;
    with $method {
        process(:$module, :$method, :$dest )
    }
    else {
        for <test-text-templates default-text-templates > {
            process( :$module, :$dest, :method($_) )
        }
    }

}
sub process(:$module, :$method, :$dest ) {
    my %data;
    my Bool $code = False;
    my $ln;
    my $start = False;
    for $module.IO.lines {
        if m/ 'method' \s+ $method / {
            $start = ! $start;
            next
        }
        next unless $start;
        next if m/ ^ \h* '%(' \h* $ /; # skip start of template hash defn
        next if m/ ^ \s* $ /; # skip blank line
        next if m/ ^ \s* '##' /; # skip template comment
        last if m/ ^ \h* '); # END OF TEMPLATES' /; # stop at end of template hash defn
        if $code and m/ ^ \h+ '},' $ / {
            $code = False;
        }
        else {
            $ln ~= $_.trim ~ "\n"; # add all valid non-code lines
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
            $desc = ($desc[0].subst(/ '|' /, '&#124;', :g) ,) ;
            my $params = $pst ~~ m/ [.+? '%prm<' (.+?) '>']+ / ?? $/>>.Str>>.unique[0] !! [['no parameters',],];
            %data{$name} = %( :$desc, :$params);
        }
    }
    my $rakudoc = qq:to/HEAD/;
        =begin rakudoc
        =TITLE Templates in C\<{ $method }>
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
            $desc-part = "=cell V\«{ %row<desc>[0] }»";
            $param-part = "=cell { %row<params> }";
        }
        elsif $params == $descs {
            $name-part = "=column\n\t\t\t=for cell \:label \:row-span($span)\n\t\t\t$name";
            $desc-part = "=column\n\t\t\t" ~ (gather for %row<desc>.list { take "=cell V\«$_»" }).join("\n\t\t\t");
            $param-part = "=column\n\t\t\t" ~ (gather for %row<params>.list { take "=cell $_" }).join("\n\t\t\t");
        }
        elsif $span > $descs {
            $name-part = "=column\n\t\t\t=for cell \:label \:row-span($span)\n\t\t\t$name";
            $desc-part = "=column\n\t\t\t" ~ (gather for %row<desc>.list { take "=cell V\«$_»" }).join("\n\t\t\t")
                    ~ "\n\t\t\t=for cell \:row-span({ $span - $descs })\n\t\t\t-";
            $param-part = "=column\n\t\t\t" ~ (gather for %row<params>.list { take "=cell $_" }).join("\n\t\t\t");
        }
        else {
            $name-part = "=column\n\t\t\t=for cell \:label \:row-span($span)\n\t\t\t$name";
            $desc-part = "=column\n\t\t\t" ~ (gather for %row<desc>.list { take "=cell V\«$_»" }).join("\n\t\t\t");
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