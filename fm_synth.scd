(
SynthDef.new("fm-op",
             { |freq, amp=1, mod_bus, out_bus|
               Out.ar(out_bus, SinOsc.ar(freq * In.kr(mod_bus), 0, amp));
             }).send(s);
)
(
SynthDef.new("fm-op-nomod",
             { |freq, amp=1, out_bus|
               Out.kr(out_bus, SinOsc.kr(freq, 0, amp));
             }).send(s);
)              
(
var op1_mod_bus = Bus.control(s, 1);
var op_1 = Synth.new("fm-op", ["freq", 440,
                               "mod_bus", op1_mod_bus,
                               "out_bus", 0]);
var op_2 = Synth.new("fm-op-nomod", ["freq", 7,
                                     "out_bus", op1_mod_bus]);
                                     "out_bus", op1_mod_bus]);                  
)