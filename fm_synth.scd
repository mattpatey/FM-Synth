(
SynthDef("fm-op", { |freq, mod_bus, amp_bus, out_bus|
    Out.ar(out_bus, SinOsc.ar(In.ar(mod_bus) * freq, 0, 1 * In.kr(amp_bus)));
}).send(s);

SynthDef("dc-offset", { |out_bus|
    Out.ar(out_bus, DC.ar(1.0));
}).send(s);

SynthDef("lfo", { |out_bus, freq|
    Out.ar(out_bus, LFNoise0.ar(freq, 1, 0).cpsmidi);
}).send(s);

SynthDef("eg", { |out, atk=0.001, sus=0.2, peak=0.3, curve=2| 
    var eg = EnvGen.ar(Env.perc(Rand(0.0001, 0.001), Rand(0.01, 0.6), Rand(0.1, 0.6), curve), Impulse.kr(abs(LFNoise0.kr(1, 7, 0.5))));
    Out.kr(out, eg);
}).send(s);
)

(
var dc_offset_bus = Bus.control(s, 1);
var dc_offset = Synth.new("dc-offset", [\out_bus, dc_offset_bus]);

var op = { |freq=440|
    var mod_bus = Bus.control(s, 1);
    var amp_bus = Bus.control(s, 1);
    var amp_eg = Synth.new("eg", [\out, amp_bus]);
    var mod = Synth.after(amp_eg, "dc-offset", [\out, mod_bus]);
    var operator = Synth.after(mod, "fm-op", [\freq, freq, 
                                              \mod_bus, mod_bus, 
                                              \amp_bus, amp_bus,
                                              \out_bus, 0]);
};

var operators;

4.do({
    operators.add(op.value(rrand(200, 1200)));
});

/*
var algos = [
  [[0, op1_mod_bus, op2_mod_bus, op3_mod_bus], [op1_mod_bus, op2_mod_bus, op3_mod_bus, dc_offset_bus]],
  [[0, op1_mod_bus, op1_mod_bus, op1_mod_bus], [op1_mod_bus, dc_offset_bus, dc_offset_bus, dc_offset_bus]],
  [[0, op1_mod_bus, op2_mod_bus, op1_mod_bus], [op1_mod_bus, op2_mod_bus, dc_offset_bus, dc_offset_bus]],
  [[0, op1_mod_bus, 0, op3_mod_bus], [op1_mod_bus, dc_offset_bus, op3_mod_bus, dc_offset_bus]],
  [[0, 0, 0, 0], [dc_offset_bus, dc_offset_bus, dc_offset_bus, dc_offset_bus]]
];

var set_algo = {|algo_num|
    var algo = algos[algo_num];
    op1.set("out_bus", algo[0][0]);
    op1.set("mod_bus", algo[1][0]);    
    op2.set("out_bus", algo[0][1]);
    op2.set("mod_bus", algo[1][1]);        
    op3.set("out_bus", algo[0][2]);
    op3.set("mod_bus", algo[1][2]);        
    op4.set("out_bus", algo[0][3]);
    op4.set("mod_bus", algo[1][3]);
};

set_algo.value(3);
*/
)