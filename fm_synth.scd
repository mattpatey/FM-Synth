(
SynthDef("fm_op", { |freq, fmod, abase, amod, out|
	// A standard, run-of-the-mill sine wave oscillator.
	//
	// FM and AM modulation are possible by passing audio rate signals to
	// `fmod` and `amod`, respectively.
	var oscillator = SinOsc.ar(In.ar(fmod) * freq, 0, abase * In.ar(amod));
    Out.ar(out, oscillator);
}).send(s);

SynthDef("eg", { |out, a=0.01, d=0.01, s=0.7, r=0.01|
	// A standard, run-of-the-mill ADSR envelope generator.
	var envelope = EnvGen.ar(Env.adsr(a, d, s, r));
	Out.ar(out, envelope);
}).send(s);

SynthDef("dc_offset", { |out|
	// A static signal.
	var signal = DC.ar(1.0);
    Out.ar(out, signal);
}).send(s);


)

(
var algorithms;
var mod_grp;
var num_ops;
var op;
var op_bus;
var op_grp;
var ops;
var set_algorithm;

op = { |freq=440, gain=1|
	var amp_mod;
    var amp_mod_bus;
    var freq_mod;
    var freq_mod_bus;
    var op;
    var op_data;

	// Busses to channel all modulation signals to the synthdef.
    amp_mod_bus = Bus.control(s, 1);
	freq_mod_bus = Bus.audio(s, 1);

	// Setup some default modulation sources.
	amp_mod = Synth.tail(mod_grp, "eg", [\out, amp_mod_bus]);
    freq_mod = Synth.tail(mod_grp, "dc_offset", [\out, freq_mod_bus]);

    op = Synth.head(op_grp, "fm_op", [\freq, freq,
		                              \fmod, freq_mod_bus,
		                              \abase, gain,
                                      \amod, amp_mod_bus,
                                      \out, op_bus]);

	// LATER: Why not use a generic object?
    op_data = Dictionary.new;
    op_data.put(\set_freq, {|value| op.set(\freq, value)});
    op_data.put(\set_out, {|value| op.set(\out, value)});
    op_data.put(\get_freq_mod_bus, {freq_mod_bus});
};

set_algorithm = {|value|
    var algorithm = algorithms[value];
    var set_out_to_speaker = {|operator| operator.at(\set_out).value(op_bus)};
    var set_out_to_mod = {|operator, op_index| operator.at(\set_out).value(ops[op_index].at(\get_freq_mod_bus).value())};

    ops.do({|op, index|
        var mod_op_index = algorithm[index];
        var fun = if(mod_op_index.isNil, {set_out_to_speaker}, {set_out_to_mod});
        fun.value(op, mod_op_index);
    });
};

op_bus = Bus.audio(s, 1);
op_grp = Group.tail(s);
mod_grp = Group.tail(s);
ops = List();
num_ops = 4;

num_ops.do({
    ops.add(op.value());
});

algorithms = [
    [nil, 0, 1, 2],
    [nil, 0, 1, 0],
    [nil, 0, 0, 0],
    [nil, nil, nil, nil]
];


// DEBUG
set_algorithm.value(0);
{ Out.ar(0, In.ar(op_bus, 1)) }.play(s, addAction: \addToTail);
)