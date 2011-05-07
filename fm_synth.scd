(
SynthDef("fm_op", { |freq, fmod, abase, amod, out|
    // A standard, run-of-the-mill sine wave oscillator.
    //
    // FM and AM modulation are possible by passing audio rate signals to
    // `fmod` and `amod`, respectively.
    var oscillator = SinOsc.ar(In.ar(fmod) * freq, 0, abase * In.ar(amod));
    Out.ar(out, oscillator);
}).send(s);

SynthDef("eg", { |a=0.01, d=0.7, s=0.0, r=0.01, gate, out|
    // A standard, run-of-the-mill ADSR envelope generator.
    var envelope = EnvGen.ar(Env.adsr(a, d, s, r), In.kr(gate));
    Out.ar(out, envelope);
}).send(s);

SynthDef("dc_offset", { |value=1.0, out|
    // A static signal.
    var signal = DC.ar(value);
    Out.ar(out, signal);
}).send(s);

SynthDef("sequencer", {|rate=1.0, sequence, out|
	var trigger = LFPulse.kr(rate, 0, 0.5, 1);
	var signal = Stepper.kr(trigger, 0, 0, 15, 1, 0);
	var value = Select.kr(signal, sequence);
	Out.kr(out, value);
}).send(s);
)

(
var algorithms;
var control_grp;
var mod_grp;
var num_ops;
var op;
var op_bus;
var op_grp;
var ops;
var sequence;
var sequencer;
var sequencer_bus;
var set_algorithm;

op = { |freq=440, gain=1|
    var amp_eg;
    var amp_mod_bus;
    var freq_mod;
    var freq_mod_bus;
    var gate;
    var gate_bus;
	var get_freq_mod_bus;
	var get_gate_bus;
    var op;
    var op_data;
    var set_adsr;
	var set_freq;
	var set_gate;
	var set_out;

    // Busses to channel all modulation signals to the synthdef.
    amp_mod_bus = Bus.audio(s, 1);
    freq_mod_bus = Bus.audio(s, 1);
    gate_bus = Bus.control(s, 1);

    // Setup some default modulation sources.
    amp_eg = Synth.tail(mod_grp, "eg", [\gate, gate_bus,
                                        \out, amp_mod_bus]);
    freq_mod = Synth.tail(mod_grp, "dc_offset", [\out, freq_mod_bus]);
    gate = Synth.tail(control_grp, "dc_offset", [\value, 0.0,
		                                         \out, gate_bus]);

    op = Synth.head(op_grp, "fm_op", [\freq, freq,
                                      \fmod, freq_mod_bus,
                                      \abase, gain,
                                      \amod, amp_mod_bus,
                                      \out, op_bus]);

    // LATER: Why not use a generic object?
    op_data = Dictionary.new;

	set_freq = {|value|
		op.set(\freq, value);
	};
    op_data.put(\set_freq, set_freq);

	set_out = {|value|
		op.set(\out, value);
	};
    op_data.put(\set_out, set_out);

	get_freq_mod_bus = {
		freq_mod_bus;
	};
    op_data.put(\get_freq_mod_bus, get_freq_mod_bus);

    set_adsr = {|adsr|
        amp_eg.set(\a, adsr[0]);
        amp_eg.set(\d, adsr[1]);
        amp_eg.set(\s, adsr[2]);
        amp_eg.set(\r, adsr[3]);
    };
    op_data.put(\set_adsr, {|value| set_adsr.value(value)});

	get_gate_bus = {
		gate_bus;
	};
	op_data.put(\get_gate_bus, get_gate_bus);
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
sequencer_bus = Bus.control(s, 1);
control_grp = Group.tail(s);
mod_grp = Group.tail(s);
op_grp = Group.tail(s);
ops = List();

num_ops = 4;
algorithms = [
    [nil, 0, 1, 2],
    [nil, 0, 1, 0],
    [nil, 0, 0, 0],
    [nil, nil, nil, nil]
];

// DEBUG
sequence = List();
sequence.add(400);
sequence.add(800);
sequencer = Synth.tail(mod_grp, "sequencer", [\out, sequencer_bus]);

num_ops.do({
	var operator = op.value();
	// TODO: Add sequencer output to the operator mod bus.
	// TODO: Add sequencer gate to the operator gate bus.
    ops.add(operator);
});

// DEBUG
set_algorithm.value(0);
{ Out.ar(0, In.ar(op_bus, 1)) }.play(s, addAction: \addToTail);
)