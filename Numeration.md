        # Numeration module
>
## Table of Contents
[Purpose](#purpose)  
[method inc( $level ) Increment the given level, resetting higher levels. Returns a string of the result.](#method-inc-level--increment-the-given-level-resetting-higher-levels-returns-a-string-of-the-result)  
[method reset Reset the counters for all levels.](#method-reset-reset-the-counters-for-all-levels)  

----
# Purpose
RakuDoc gives a standard way to number headers and items.

In addition, numerations can be continued.

When a level is incremented in a multilevel numeration, the next level down is not changed.

When a level is incremented, higher levels start again.

This module can be sub-classed in order to provide different numbers / behaviours.

## method inc( $level ) Increment the given level, resetting higher levels. Returns a string of the result.
## method reset Reset the counters for all levels.






----
Rendered from Numeration at 2024-06-04T22:22:56Z