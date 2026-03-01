package funkin.vis;

/**
 * Represents a currently playing audio clip
 */
interface AudioClip
{
    public var channels(get, never):Int;
    public var sampleRate(get, never):Int;
    public function getTimeDomainData(fftN:Int):Array<Float>;
}