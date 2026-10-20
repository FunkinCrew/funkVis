package funkin.vis;

import lime.utils.Int16Array;

class AudioBuffer
{
    public var data(default, null):Int16Array;
    public var sampleRate(default, null):Float;

    public function new(data:Int16Array, sampleRate:Float)
    {
        this.data = data;
        this.sampleRate = sampleRate;
    }
}