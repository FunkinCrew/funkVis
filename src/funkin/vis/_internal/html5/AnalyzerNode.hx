package funkin.vis._internal.html5;

import funkin.vis.AudioClip;
#if lime_howlerjs
import lime.media.howlerjs.Howl;
import lime.media.howlerjs.Howler;
import js.html.audio.AnalyserNode as AnalyseWebAudio;
#end

// note: analyze and analyse are both correct spellings of the word, 
// but "AnalyserNode" is the correct class name in the Web Audio API
// and we use the Z variant here...
class AnalyzerNode
{   
    #if lime_howlerjs
    public var analyzer:AnalyseWebAudio;
    public var maxDecibels:Float = -30;
    public var minDecibels:Float = -100;
    public var fftSize:Int = 2048;
    var howl:Dynamic;
    var ctx:Dynamic;
    #end

    var audioClip:AudioClip;

    // #region yoooo
    public function new(?audioClip:AudioClip)
    {
        trace("Loading audioClip");
        this.audioClip = audioClip;

        #if lime_howlerjs
        howl = audioClip.source;
        ctx = howl._sounds[0]._node.context;

        analyzer = new AnalyseWebAudio(ctx);
        howl.on("play", onHowlPlay);

        getFloatFrequencyData();
        #end
    }

    public function cleanup():Void
    {
        #if lime_howlerjs
        howl.off("play", onHowlPlay);
        #end
    }

    public function getFloatFrequencyData():Array<Float>
    {
        #if lime_howlerjs
        var array:js.lib.Float32Array = new js.lib.Float32Array(analyzer.frequencyBinCount);
        analyzer.fftSize = fftSize;
        analyzer.minDecibels = minDecibels;
        analyzer.maxDecibels = maxDecibels;
        analyzer.getFloatFrequencyData(array);
        return cast array;
        #end
        return [];
    }

    #if lime_howlerjs
    function reconnectAnalyzer(audioClip:AudioClip):Void
    {
        var gainNode = howl._sounds[0]._node;
        var bufferSrc = gainNode.bufferSource;

        // Disconnect all previous outputs from the gain node and analyser
        gainNode.disconnect();
        analyzer.disconnect();

        if (bufferSrc != null)
        {
            // Disconnect all previous outputs from the source 
            // so we can mess with the order of nodes ourselves
            bufferSrc.disconnect();

            // Connect the source directly to the analyser
            // This way the analyser can get audio data that's not affected by the volume
            bufferSrc.connect(analyzer);

            // Connect the analyser to the gain node so we can control the audio's volume
            analyzer.connect(cast gainNode);
        }
        else 
        {
            // If for whatever reason we can't get the source node,
            // fall back to connecting the gain node to the analyser as done before
            gainNode.connect(analyzer);
        }

        // Finally, connect the gain node back to the destination
        gainNode.connect(ctx.destination);
    }

    function onHowlPlay():Void
    {
        reconnectAnalyzer(audioClip);
    }
    #end
}
