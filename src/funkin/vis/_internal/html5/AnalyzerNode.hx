package funkin.vis._internal.html5;

import lime.utils.Float32Array;
import funkin.vis.audioclip.frontends.LimeAudioClip;

#if lime_howlerjs
import lime.media.howlerjs.Howl;
import js.html.audio.AudioNode;
import js.html.audio.AnalyserNode as JSAnalyserNode;
import js.html.audio.BaseAudioContext;
#end

// note: analyze and analyse are both correct spellings of the word, 
// but "AnalyserNode" is the correct class name in the Web Audio API
// and we use the Z variant here...
class AnalyzerNode
{   
    #if lime_howlerjs
    public var analyser:JSAnalyserNode;
    public var maxDecibels:Float = -30;
    public var minDecibels:Float = -100;
    public var fftSize:Int = 2048;

    public var limeAudioClip:LimeAudioClip;

    var audioNode:AudioNode;
    var array:Float32Array;
    #end

    // #region yoooo
    public function new(?limeAudioClip:LimeAudioClip)
    {
        #if lime_howlerjs
        this.limeAudioClip = limeAudioClip;
        #end
    }

    public function getFloatFrequencyData():Float32Array
    {
        #if lime_howlerjs
        var desiredLength = fftSize >> 1;
        if (array == null || array.length != desiredLength) array = new Float32Array(desiredLength);

        // really a crime to read this code but this gets the audioNode.
        var previousAudioNode = audioNode;
        @:privateAccess
        {
            #if lime_funkin
            var howlSound = limeAudioClip.audioSource.__backend.howlSound;
            if (howlSound != null)
            #else
            var howl = limeAudioClip.audioSource.buffer.__srcHowl;
            if (howl == null) return cast array;

            var howlSound = untyped limeAudioClip.audioSource.buffer.__srcHowl._soundById(limeAudioClip.audioSource.__backend.id);
            if (!(untyped howlSound)) howlSound = untyped limeAudioClip.audioSource.buffer.__srcHowl._sounds[0];

            if (untyped howlSound)
            #end
            {
                if (untyped howlSound._node)
                {
                    if (untyped howlSound._node.bufferSource)
                    {
                        audioNode = untyped howlSound._node.bufferSource;
                    }
                    else
                    {
                        audioNode = untyped howlSound._node;
                    }
                }
                else
                {
                    audioNode = null;
                }
            }
            else
            {
                audioNode = null;
            }
        }

        if (audioNode == null) return cast array;

        if (previousAudioNode != audioNode)
        {
            var context:BaseAudioContext = audioNode.context;
            if (analyser == null || context != analyser.context) analyser = new JSAnalyserNode(context);
            else analyser.disconnect();

            audioNode.connect(analyser);
        }

        analyser.smoothingTimeConstant = 0.1;
        analyser.fftSize = fftSize;
        analyser.maxDecibels = maxDecibels;
        analyser.minDecibels = minDecibels;

        analyser.getFloatFrequencyData(array);
        return array;
        #else
        return new Float32Array(0);
        #end
    }
}