package ammertest;

import funkVis._internal.native.bindings.PFFFT;

class Test
{
    public static function main()
    {
        trace(PFFFT.pffft_next_power_of_two(1000));
    }
}