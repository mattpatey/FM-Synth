(
Server.internal.options.device = "Soundflower (16ch)";
Server.local.options.device = "Soundflower (16ch)";
)

(
Server.local.boot;
Server.internal.boot;
)

(
SynthDef("motion_filter", {|in_bus, out_bus|
    var filter;
    filter = MoogFF.ar(SoundIn.ar(in_bus), LFNoise0.ar(abs(LFNoise1.ar(0.3, 0.3, 7)), 10000, 12000), 3.6);
    Out.ar(out_bus, filter);
}).send(s);

SynthDef("sin_osc", {|out_bus|
    Out.ar(out_bus, SinOsc.ar(440, 0, 0.7));
}).send(s);

SynthDef("passthru", {|in, out|
    Out.ar(out, In.ar(in));
}).send(s);
)

(
Synth.new("motion_filter", [\in_bus, 2, \out_bus, 3]);
)

(
// DEBUG
{Out.ar(3, SinOsc.ar(440, 0, 1))}.play;
{SoundIn.ar(2)}.scope(1, zoom:4);
)