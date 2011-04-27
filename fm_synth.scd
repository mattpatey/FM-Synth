(
SynthDef.new("fm-op",
             { arg bus, freq = 440, mod = 1, amp = 0.2; 
               Out.ar(0, SinOsc.ar(In.kr(bus) * freq, 0, amp));
             }).send(s);
SynthDef.new("fm-mod",
             { arg freq = 440, bus;
               Out.kr(bus, SinOsc.kr(freq, 0, 1));
             }).send(s);
b = Bus.control(s, 1);
)
               
(
x = Synth.new("fm-op", [\bus, b]);
y = Synth.after(x, "fm-mod", [\bus, b, \freq, 50]);
)