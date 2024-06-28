use v6.d;
#| Class for numeration of headings, defns and items
unit class Numeration;

has Int @!counters is default(0);
submethod TWEAK {
    @!counters = Nil
};
method Str () { @!counters>>.Str.join('.') ~ '.' }
method inc (Int() $level) {
    @!counters[$level - 1]++;
    @!counters.splice($level);
    self
}
method reset () {
    @!counters = Nil;
    self
}
method set (Int() $level, $value ) {
    @!counters[ $level - 1 ] = $value;
    self
}
