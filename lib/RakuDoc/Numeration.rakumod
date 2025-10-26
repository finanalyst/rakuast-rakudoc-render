use v6.d;
use RakuDoc::PromiseStrings;

# based on code by Damian Conway
# some revision by Elizabeth Mattijsen

# Enumeration values must be positive integers...
subset PosInt   of Int   where     * > 0;
subset PosArray of Array where { .all ~~ (1..*)|'' };


# Mark each :form component by type...
role FieldType { has $.field-type }

#| Class for numeration of headings, defns and items
class Numeration {

    has Int @.counters is default(1);
    has @.warnings;

    submethod TWEAK( :@init ) {
        @!counters = @init if +@init
    };

    multi method Str () {
        @!counters.join('.') ~ '.'
    }
    multi method Str ( $n ) {
        @!counters[^$n].join('.') ~ '.'
    }
    multi method inc (Int() $level) {
        if @!counters[$level - 1]:exists {
            @!counters[$level - 1]++
        }
        else { # need to check that lower levels are also set to 1
            (@!counters[$_] = 1 unless @!counters[$_]:exists)
            for ^$level
        }
        @!counters.splice($level);
        self
    }
    multi method inc () {
        self.inc(1)
    }
    method reset () {
        @!counters = Nil;
        self
    }
    multi method set (Int() $level, $value ) {
        @!counters[$level - 1] = $value;
        self
    }
    multi method parts( --> Array) {
        @!counters.clone;
    }
    multi method parts( Int $level --> Positional ) {
        self.parts[^$level]
    }
    method part( Int $level --> Int ) { @!counters[$level - 1] }
    method set-counters(@counters) {
        @!counters := @counters;
        self
    }
    multi method clone(Numeration:D:) {
        callsame.set-counters(self.parts)
    }

    multi method numform (
            Str :$form,
            # The format string (contents of the :form<...>)
            Str:D :$contents,
            # The contents contained in the block
            Str :$type = q{},
            # The type of the block
            Str :$caption = q{}
            # The caption to be shown
                          ) {
        self.numform(:$form, :contents( PStr.new( $contents )), :$type, :$caption)
    }
    multi method numform (
            Str :$form is copy,
            # The format string (contents of the :form<...>)
            PStr :$contents = PStr.new,
            # The contents contained in the block
            Str :$type = q{},
            # The type of the block
            Str :$caption = q{}
            # The caption to be shown
                          ){
        # What a :form<> format consists of...
        grammar Format {
            token TOP {
                ^ <verbatim>* %% <field> $
            }
            token field {
                \% [ <literal> | <fieldname> <options>* ]
            }
            token literal { \% | \: }
            token fieldname { <:Letter> }
            token options { \:uc | \:lc | \:tc | \:tclc | \:sc | \:pc | \:ord | \:lang\< <lang> \> }
            token lang {
                <[a..z]><[a..z]>
            }
            token verbatim { <-[%]>* }
        }
        my @nums = @!counters;
        # The hierarchical enumeration values of the block
        # e.g. 3rd head3 of 1st head2 of 5th head1 -> :nums[5,1,3]
        # How to generate representations of cardinal numbers in different languages...
        state %num
                is default( { $^num }) # Default is to just use Indo-Arabic numerals
        = :hi( { $^num.trans('0123456789' => '०१२३४५६७८९') }),
          :bn( { $^num.trans('0123456789' => '০১২৩৪৫৬৭৮৯') }),
          :zh( &to-zh),
          :ja( &to-ja),
          :la( &to-roman);

        # How to generate representations of ordinal numbers (from cardinals) in different languages...
        state %ord
                is default({ $^no-op }) # Default is no change to number
        = :en( { $_ ~ ( /<!after 1> (<[1..3]>) $/ ?? ["", "st", "nd", "rd"][$0] !! 'th') }),
          :sv( { $_ ~ ( /<!after 1>  <[1..2]>  $/ ?? ':a' !! ':e') }),
          :nl( { $_ ~ 'e' }),
          :ga( { $_ ~ 'ú' }),
          :zh( { "第$_" }),
          :ko( { "제$_" }),
          :ja( { # if ordinary numbers...             append "-banme"   else prepend "dai-"
              /<[〇一二三四五六七八九十百千万]>/ ?? $_ ~ '番目' !! '第' ~ $_;
          }),

          # Welsh is extravagantly random in its ordinal suffixes (I'm not sure this is even right!)...
          :cy( {
              my @ôl-sayodiaid is default('ain')
              = « '' af il ydd ydd ed ed fed fed fed fed eg fed eg eg fed eg eg fed eg fed »;
              $_ ~ @ôl-sayodiaid[$_];
          }),

          # Languages with gendered ordinal suffixes generally seem to default to masculine
          # (I'm not happy about this, but I can't find a better rule: suggestions welcome)...
          |(< gl it > »=>» { $_ ~ 'º' }),
          |(< es pt > »=>» { $_ ~ '.º' }),
          :fr( { $_ ~ ( $_ == 1 ?? 'ᵉʳ' !! 'ᵉ') }),
          :ro( { $_ ~ '-lea' }),

          # Languages that use a trailing period for ordinals...
          |(< ue sr hr cs da et fo fi de hu is lv no sk sl tr > »=>» { "$_." }),
          ;

        # Special cases of casing for Mandarin Chinese and Japanese...
        state %lc
                is default(&lc) # Default is just the built-in case lower-er
        = :zh({ $^numstr.trans('零壹貳叁肆伍陸柒捌玖拾佰仟' => '〇一二三四五六七八九十百千') }),
          :ja({
              $^numstr.trans(
                      '零壱弐貳参參肆伍陸漆柒質捌玖拾佰仟萬' => '〇一二二三三四五六七七七八九十百千万',
                      '廿' => '二十',
                      '卅' => '三十',
                      ).subst(/^ 一 <before <[十百千]>>/, '');
              # Remove formal leading 1
          });

        state %uc
                is default(&uc) # Default is built-in case upper-er
        = :zh({ $^numstr.trans('〇一二三四五六七八九十百千' => '零壹貳叁肆伍陸柒捌玖拾佰仟') }),
          :ja({
              $^numstr.trans(
                      '〇一二二三三四五六七七七八九十百千万' => '零壱弐貳参參肆伍陸漆柒質捌玖拾佰仟萬',
                      ).subst(/^ <before <[拾佰仟]>>/, '壱');
              # Add formal leading 1
          });

        # "Proper case" .tclc's each word (but honours ALLCAP abbreviations: NATO, ISO_639-1, PEBCAK, etc.)...
        state %pc is default({ $^str.subst: /\S+/, { /<lower>/ ?? .tclc !! .uc }, :g });

        # "Sentence case" tclc's after a Unicode sentence terminator (and also preserves ALLCAPS words)...
        sub make-sc-for ($uc-required) {
            sub ($str) {
                my $new-sentence = True;
                $str.subst: /\S+/, {
                    LEAVE $new-sentence = ?/ <:SentenceTerminal> $ /;
                    $_ ~~ $uc-required ?? .uc
                    !! $new-sentence ?? .tclc
                    !! .lc
                }, :g;
            }
        }
        state %sc is default(make-sc-for({ !/<lower>/ }))
        = :en( make-sc-for({ !/<lower>/ || /^<[io]><-:Letter>*$/ }));
        # Also capitalize "I" and "O"

        # No special cases (ahem!) for any of these yet...
        state %tc is default(&tc);
        state %tclc is default(&tclc);
        state %no-case is default(*.Str);

        state %case-handler = :%lc, :%uc, :%tc, :%tclc, :%sc, :%pc, q{} => %no-case;

        # Fields that implicitly specify a language...
        state %field-to-lang = :Z<zh>, :H<hi>, :B<bn>, :J<ja>, :R<la>,
                               :大<zh>, :ह<hi>, :ব<bn>, :業<ja>,
                               :小<zh>, :並<ja>;
        state $is-lang-field = any keys %field-to-lang;

        # Track any warnings...
        sub warn (*@msg) {
            @.warnings.unshift: @msg.join(q{ })
        }

        # Handle the various components a format may contain...
        multi handle (:$verbatim where q{}) {
            () but FieldType('null')
        }
        multi handle (:$verbatim) {
            "$verbatim" but FieldType('verbatim')
        }
        multi handle (:field($_)) {
            # Is it a literal marker???
            return .<literal>.Str but FieldType('verbatim') if .<literal>;

            # Unpack and normalize the field name...
            my $fieldname = .<fieldname>.uc.Str;
            my $raw-fieldname = '%' ~ .<fieldname>;

            # Unpack, check, and resolve any language option...
            my $implied-lang = %field-to-lang{$fieldname};
            my     $opt-lang = .<options>.first(*.<lang>).<lang>;
            if $implied-lang && $opt-lang && $implied-lang ne $opt-lang {
                warn "Can't specify :lang<$opt-lang> on field $raw-fieldname",
                        "(which implies :lang<$implied-lang>). Ignoring :lang<$opt-lang>";
            }
            my $lang = $implied-lang // $opt-lang // 'en';

            # Unpack ordinality and case options, and resolve any conflicts...
            my @options = .<options>;
            my $ord = @options.any ~~ ':ord';
            my %case = %case-handler.keys.grep({ @options.any ~~ ":$^case" }) »=>» True;
            my $implied-lc = $raw-fieldname ~~ / <lower> | 並 | 小 /;
            if %case > 1 || $implied-lc && %case == 1 && !%case<lc> {
                if $implied-lc && %case<uc tc tclc sc pc>.any {
                    warn "Can't specify { ':' «~« %case.keys.sort } on field $raw-fieldname",
                            "(which implies :lc). Using :lc";
                    %case = :lc;
                }
                else {
                    warn "Can't specify { ':' «~« %case.keys.sort } on $raw-fieldname. Using :uc";
                    %case = :uc;
                }
            }
            elsif !%case && $implied-lc {
                %case = :lc;
            }
            my $case-handler = %case-handler{%case.keys.first // q{}}{$lang};

            # Interpolate the field from the appropriate argument...
            my $value = do given $fieldname {
                when 'C' { $caption // q{} }
                when 'D' { $contents.clone // PStr.new }
                when 'T' { $type.tclc }
                when 'A' {
                    my $n = @nums.pop;
                    !$n ?? q{} !! ('', 'A' ... 'ZZZZZZZZZ')[$n]
                }
                when 'N' {
                    my $n = @nums.pop;
                    !$n ?? q{} !! %num{$lang}($n)
                }
                when $is-lang-field {
                    my $n = @nums.pop;
                    !$n ?? q{} !! %num{$lang}($n)
                }
                default {
                    warn "Field $raw-fieldname is reserved for future use";
                    $raw-fieldname;
                }
            }

            # Apply the various options...
            # (This looks odd, I know, but we really do need to change case both beforehand and afterwards.
            #  Beforehand because some langs use different ordinal markers for
            #  formal and informal numbers; Afterwards because some langs add
            #  ordinal markers that can then be upper- or lower-cased)
            if $ord {
                $value = $case-handler($value);
                $value = %ord{$lang}($value);
            }
            $value = $case-handler($value);
            # Mark the result with its fieldtype and we're done...
            return $value but FieldType($fieldname);
        }

        # Now process the entire format in a single pretty pipeline
        # (The twin reverses around the map ensures we interpolate just the last X numbers, left-to-right)...
        return Format.parse($form).caps.reverse.map({ handle |$^cap }).grep(*.so).reverse;
    }

    # Generate Roman numerals...
    # [Adapted from the Perl module Unicode::Roman by brian d foy]
    sub to-roman(PosInt() $n is copy) {

        # Create static translation tables for Arabic-to-Roman...
        state %roman-digits = 1 => 'ⅠⅤ', 10 => 'ⅩⅬ', 100 => 'ⅭⅮ', 1000 => 'Ⅿↁ', 10000 => 'ↂↇ', 100000 => 'ↈↈↈↈ';
        state @order = reverse sort keys %roman-digits;
        once %roman-digits{$_} = %roman-digits{$_}.comb.[0 .. 1] for @order;

        # This sub only works on a limited range (1..400_000)...
        return $n if $n <= 0 || $n > 4 * %roman-digits.keys.max;

        # Start accumulating the Roman translation, while tracking the current uppermost Roman numeral...
        my ($roman, $x) = ( '', '');

        # Iterate through decreasing powers of ten...
        for @order -> $order {
            # Get the actual Arabic digit and the current Roman unit and quintal numerals...
            my ($digit, $i, $v) = ($n / $order).Int, |%roman-digits{$order};

            # Append the appropriate Roman numeral...
            $roman ~= do given $digit {
                when 0 { '' }
                when 1 .. 3 { $i x $digit }
                when 4 { $i ~ $v }
                when 5 { $v }
                when 6 .. 8 { $v ~ $i x ($digit - 5) }
                when 9 { $i ~ $x }
            };

            # Remove that amount from the original number...
            $n -= $digit * $order;

            # Adjust the uppermost numeral for the next lower order...
            $x = $i;
        }

        # And we're done...
        return $roman;
    }

    # Generate Mandarin Chinese numerals (in the most international style and the most formal notation)...
    # [Adapted from the Perl module Lingua::ZH::Numbers by Audrey Tang]
    sub to-zh( Int() $num is copy ) {

        # The traditional glyphs for various magnitudes (10000s), orders (1000/100/10), and digits...
        constant @mag = « '' 萬 億 兆 京 垓 秭 穰 溝 澗 正 載 極 恆河沙 阿僧祇 那由他 不可思議 無量大數 »;
        constant @ord = « '' 拾 佰 仟 »;
        constant @dig = « 零 壹 貳 叁 肆 伍 陸 柒 捌 玖 拾 »;
        constant $zero = '零';
        constant $final-zero = /零$/;

        # Just look up small numbers directly...
        return @dig[$num] if $num <= 10;

        # Otherwise break number into 4-digit chunks (i.e. one chunk per 10000 magnitude)...
        my @chunks = $num.flip.comb(4)».flip.reverse;

        # Starting magnitude is determined by number of chunks...
        my $mag = @chunks.end;

        # Accumulate a translation result...
        my $result = '';
        for @chunks -> $num {

            # Accumulate translation of next chunk...
            my $chunk-trans = '';

            # For the thousands, hundreds, tens, and units...
            for 3 ... 0 -> $ord {

                # Extract the digit, skipping leading zeros...
                my $n = ($num / (10 ** $ord)).Int % 10;
                next unless $chunk-trans or $n;

                # Translate the digit as <digit-glyph> then <order-glyph>...
                $chunk-trans ~= @dig[$n] unless ($n == 0 and $chunk-trans ~~ $final-zero)
                        or ($ord == 1 and $n == 1 and !$chunk-trans);
                $chunk-trans ~= @ord[$ord] if $n;
            }

            # Remove any unnecessary trailing zero (if it's just zero, it's necessary)...
            $chunk-trans .= subst($final-zero, '') if $chunk-trans ne $zero;

            # Add the magnitude (10000) indicator...
            $chunk-trans ~= @mag[$mag] if $chunk-trans;

            # Add a zero, if required...
            $chunk-trans = $zero ~ $chunk-trans if $num < 1000 and $mag != @chunks.end
                    and $result !~~ $final-zero;

            # Add this chunk to the partially translated result...
            $result ~= $chunk-trans;

            # The next chunk will be for the next smaller magnitude...
            $mag--;
        }

        # Remove any unnecessary trailing zero...
        $result .= subst($final-zero, '') if $result ne $zero;

        # Return the result (or zero on failure)...
        return $result || $zero;
    }

    # General formal/business Japanese numbers...
    # [Heavily adapted from the Perl module Lingua::ZH::Numbers by Audrey Tang]
    sub to-ja( Int() $num is copy ) {

        # The traditional glyphs for various magnitudes (10000s), orders (1000,100,10), and digits...
        constant @mag = « '' 万 億 兆 京 垓 𥝱 穣 溝 澗 正 載 極 恒河沙 阿僧祇 那由他 不可思議 無量大数 »;
        constant @ord = « '' 拾 百 千 »;
        constant @dig = « 零 壱 弐 参 四 五 六 七 八 九 拾 »;

        # Just look up small numbers directly...
        return @dig[$num] if $num <= 10;

        # Otherwise break number into 4-digit chunks (i.e. one chunk per 10000 magnitude)...
        my @chunks = $num.flip.comb(4)».flip.reverse;

        # Starting magnitude is determined by number of chunks...
        my $mag = @chunks.end;

        # Accumulate a translation result...
        my $result = '';
        for @chunks -> $num {

            # Accumulate the translation of the next chunk...
            my $chunk-trans = '';

            # For the thousands, hundreds, tens, and units...
            for 3 ... 0 -> $ord {

                # Extract the digit, skipping leading zeros...
                my $n = ($num / (10 ** $ord)).Int % 10;
                next unless $n;

                # Translate the digit as <digit-glyph> then <order-glyph>...
                $chunk-trans ~= @dig[$n]  if $n !== 1 || !$ord || $mag == @chunks.end;
                $chunk-trans ~= @ord[$ord];
            }

            # Add the magnitude (10000) indicator...
            $chunk-trans ~= @mag[$mag] if $chunk-trans;

            # Add this chunk to the partially translated result...
            $result ~= $chunk-trans;

            # The next chunk will be for the next smaller magnitude...
            $mag--;
        }

        # A leading 1 is only necessary above 10000...
        $result .= subst(/^壱/, '') if $num < 10000;

        # Return the result...
        return $result;
    }
}