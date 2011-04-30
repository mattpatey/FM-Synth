(
SynthDef("fm-op", { |out_bus=0, mod_bus, freq|
    Out.ar(out_bus, SinOsc.ar(In.ar(mod_bus) * freq, 0, 1));
}).send(s);

// Add 1 to the DC offset of a sine wave so we can
// use it to multiply another signal by one. Used
// for FM operators that should not be modulated.
SynthDef("dc-offset", { |out_bus|
    Out.ar(out_bus, DC.ar(1.0));
}).send(s);
)

(
var dc_offset_bus = Bus.control(s, 1);
var op1_mod_bus = Bus.control(s, 1);
var op2_mod_bus = Bus.control(s, 1);
var op3_mod_bus = Bus.control(s, 1);
var op4_mod_bus = Bus.control(s, 1);

var dc_offset = Synth.new("dc-offset", [\out_bus, [op4_mod_bus]]);
var op4 = Synth.after(dc_offset, "fm-op", [\freq, 5, \mod_bus, op4_mod_bus, \out_bus, op3_mod_bus]);
var op3 = Synth.after(op4, "fm-op", [\freq, 1200, \mod_bus, op3_mod_bus, \out_bus, op2_mod_bus]);
var op2 = Synth.after(op3, "fm-op", [\freq, 5.3, \mod_bus, op2_mod_bus, \out_bus, op1_mod_bus]);
var op1 = Synth.after(op2, "fm-op", [\freq, 300, \mod_bus, op1_mod_bus]);

var algos = [
  [0, op1_mod_bus, op2_mod_bus, op3_mod_bus],
  [0, op1_mod_bus, op1_mod_bus, op1_mod_bus],
  [0, op1_mod_bus, op2_mod_bus, op1_mod_bus],
  [0, op1_mod_bus, 0, op3_mod_bus],
  [0, 0, 0, 0]
];

var set_algo = {|algo_num|
    var algo = algos[algo_num];
    op1.set("out_bus", algo[0]);
    op2.set("out_bus", algo[1]);
    op3.set("out_bus", algo[2]);
    op4.set("out_bus", algo[3]);
};
)
