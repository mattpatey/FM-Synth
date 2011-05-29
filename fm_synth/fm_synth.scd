(
SynthDef("fm_op", { |fbase, fmod, freq, abase, amod, out|
    // A standard, run-of-the-mill sine wave oscillator.
    //
    // FM and AM modulation are possible by passing audio rate signals to
    // `fmod` and `amod`, respectively.
    var oscillator = SinOsc.ar(In.ar(fmod) * (fbase + In.kr(freq)), 0, abase * In.ar(amod));
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

SynthDef("sequencer", {|clock, sequence, out|
	var s = [100, 200, 300, 400];
    var value = Select.kr(Stepper.kr(In.kr(clock), 0, 0, 5, 1, 0),
                          s);
    Out.kr(out, value);
}).send(s);

SynthDef("lfo", {|rate, out|
    Out.kr(out, LFPulse.kr(rate, 0, 0.5, 1));
}).send(s);
)

(
var algorithms;
var clock;
var control_grp;
var master_clock;
var master_clock_bus;
var master_gate;
var master_gate_bus;
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

op = { |fbase=440, gain=1|
    var amp_eg;
    var amp_mod_bus;
    var freq;
    var freq_bus;
    var freq_mod;
    var freq_mod_bus;
    var get_freq_mod_bus;
    var op;
    var op_data;
    var set_adsr;
    var set_fbase;
    var set_gate;
    var set_gate_bus;
    var set_out;

    // Busses to channel all modulation signals to the synthdef.
    amp_mod_bus = Bus.audio(s, 1);
    freq_bus = Bus.control(s, 1);
    freq_mod_bus = Bus.audio(s, 1);

    // Setup some default modulation sources.
    amp_eg = Synth.tail(mod_grp, "eg", [\gate, master_clock_bus, // TODO: Change to gate bus once I've figured out how to send one signal to multiple places.
                                        \out, amp_mod_bus]);
    freq_mod = Synth.tail(mod_grp, "dc_offset", [\out, freq_mod_bus]);
    op = Synth.head(op_grp, "fm_op", [\fbase, fbase,
                                      \freq, sequencer_bus,
                                      \fmod, freq_mod_bus,
                                      \abase, gain,
                                      \amod, amp_mod_bus,
                                      \out, op_bus]);

    // LATER: Why not use a generic object?
    op_data = Dictionary.new;

    set_fbase = {|value|
        op.set(\fbase, value);
    };
    op_data.put(\set_fbase, set_fbase);

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

    set_gate_bus = {|value|
        amp_eg.set(\gate, value);
    };
    op_data.put(\set_gate_bus, set_gate_bus);
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

// TODO: Make sure correct bus type (control, audio) is used.
master_clock_bus = Bus.control(s, 1);
master_gate_bus = Bus.control(s, 1);
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

num_ops.do({
    var operator = op.value();
    ops.add(operator);
});

// DEBUG
set_algorithm.value(0);
master_clock = Synth.tail(control_grp, "lfo", [\rate, 1,
                                               \out, master_clock_bus]);
sequencer = Synth.tail(mod_grp, "sequencer", [\clock, master_clock_bus,
                                              \sequence, [500, 100, 100, 100],
                                              \out, sequencer_bus]);
{ Out.ar(0, In.ar(op_bus, 1)) }.play(s, addAction: \addToTail);
)