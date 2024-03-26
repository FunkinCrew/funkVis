package funkVis._internal.native.bindings;

@:ammer.lib.includePath("../pffft")
@:ammer.lib.headers.include("pffft.h")
class PFFFT extends ammer.def.Library<"pffft">
{
    public static function pffft_next_power_of_two(N:Int):Int;
}