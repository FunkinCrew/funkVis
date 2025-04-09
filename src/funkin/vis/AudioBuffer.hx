package funkin.vis;

import lime.utils.UInt16Array;

class AudioBuffer
{
    public var data(default, null):UInt16Array;
    public var sampleRate(default, null):Float;
    public var length(default, null):Int;
    public var bitsPerSample(default, null):Int;
    public var channels(default, null):Int;

    public function new(data:UInt16Array, sampleRate:Float, length:Int, bitsPerSample:Int, channels:Int)
    {
        this.data = data;
        this.sampleRate = sampleRate;
        this.length = length;
        this.bitsPerSample = bitsPerSample;
        this.channels = channels;
    }
}