package funkVis;

/**
 * Represents a currently playing audio clip
 */
interface AudioClip
{
    public var audioBuffer(default, null):AudioBuffer;
    public var currentFrame(get, never):Int;
}