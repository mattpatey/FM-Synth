(
SynthDef("fm_op", { |freq, fmod, abase, amod, out|
    Out.ar(out, SinOsc.ar(In.ar(fmod) * freq, 0, abase * In.ar(amod)));
}).send(s);

SynthDef("dc_offset", { |out|
    Out.ar(out, DC.ar(1.0));
}).send(s);

SynthDef("lfo", { |rate, out|
    Out.ar(out, Saw.ar(rate, 1, 1));
}).send(s);

SynthDef("eg", { |out, atk=0.001, sus=0.2, peak=0.3, curve=2| 
    var eg = EnvGen.ar(Env.perc(Rand(0.0001, 0.001), Rand(0.01, 0.6), Rand(0.1, 0.6), curve), Impulse.kr(abs(LFNoise0.kr(1, 7, 0.5))));
    Out.kr(out, eg);
}).send(s);
)

(
var algorithms, set_algorithm;
var op_bus = Bus.audio(s, 1);
var dead_bus = Bus.audio(s, 1);
var mod_grp = Group.tail(s);
var op_grp = Group.tail(s);
var ops;
var op;
var lfo;

op = { |freq=440|
    var op_data;
    
    var mod_bus;
    var amp_bus;
    var amp_eg;
    var mod;
    var op_def;
    
    var set_out;
    var get_mod_bus;

    mod_bus = Bus.audio(s, 1);
    amp_bus = Bus.control(s, 1);
    amp_eg = Synth.head(mod_grp, "dc_offset", [\out, amp_bus]);
    mod = Synth.head(mod_grp, "dc_offset", [\out, mod_bus]);    
    op_def = Synth.head(op_grp, "fm_op", [\freq, freq,
                                          \fmod, mod_bus,
                                          \abase, 1,
                                          \amod, amp_bus,
                                          \out, op_bus]);
    op_data = Dictionary.new;
    op_data.put(\set_freq, {|value| op_def.set(\freq, value)});
    op_data.put(\set_out, {|value| op_def.set(\out, value)});
    op_data.put(\get_mod_bus, {mod_bus});
};

ops = List();
4.do({
    ops.add(op.value());
});

algorithms = [
    [nil, 0, 1, 2],
    [nil, 0, 1, 0],
    [nil, 0, 0, 0],
    [nil, nil, nil, nil]
];

set_algorithm = {|value|
    var algorithm = algorithms[value];
    var set_out_to_speaker = {|operator| operator.at(\set_out).value(op_bus)};
    var set_out_to_mod = {|operator, op_index| operator.at(\set_out).value(ops[op_index].at(\get_mod_bus).value())};

    ops.do({|op, index|
        var mod_op_index = algorithm[index];
        var fun = if(mod_op_index.isNil, {set_out_to_speaker}, {set_out_to_mod});
        fun.value(op, mod_op_index);
    });
};

set_algorithm.value(0);

{ Out.ar(0, In.ar(op_bus, 1)) }.play(s, addAction: \addToTail);
)