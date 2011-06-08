(
SynthDef("fm_op", { |fbase, fmod_bus, freq_bus, abase, amod_bus, out_bus|
    // A standard, run-of-the-mill sine wave oscillator.
    //
    // FM and AM modulation are possible by passing audio rate signals to
    // `fmod` and `amod`, respectively.
    var oscillator = SinOsc.ar(In.ar(fmod_bus) * (fbase + In.kr(freq_bus)), 0, abase * In.ar(amod_bus));
    Out.ar(out_bus, oscillator);
}).send(s);

SynthDef("eg", { |a=0.01, d=0.7, s=0.0, r=0.01, gate_bus, out_bus|
    // A standard, run-of-the-mill ADSR envelope generator.
    var envelope = EnvGen.ar(Env.adsr(a, d, s, r), In.ar(gate_bus));
    Out.ar(out_bus, envelope);
}).send(s);

SynthDef("dc_offset", { |value=1.0, out_bus|
    // A static signal.
    var signal = DC.ar(value);
    Out.ar(out_bus, signal);
}).send(s);
)

(
var fm_synth, my_synth, gate, gate_bus, master_grp, master_gate_bus, set_base_freq;

fm_synth = {
    // Four-operator FM synthesizer.
    //
    //
    var algorithms, control_grp, mod_grp,
        num_ops, op, op_bus, op_grp,
        ops, sequence, set_algorithm,
        op_gate_bus, s;

    op = { |gate_bus, fbase=440, gain=1|
        // FM operator.
        //
        // An operator consists of a sine wave oscillator, an ADSR
        // envelope, and several inputs and outputs.
        //
        // It has inputs for frequency modulation and a gate input to
        // trigger an ADSR envelope that modulates its amplitude.
        //
        // Instantiating an FM operator will return a dictionary
        // containing functions that allow one to interact with the
        // operator's parameters.
        var amp_eg, amp_mod_bus, freq,
            freq_bus, freq_mod, freq_mod_bus,
            get_freq_mod_bus, op, op_data,
            set_adsr, set_fbase, set_gate,
            set_out, gate;

        // Instances of an FM synth create busses on the fly.
        amp_mod_bus = Bus.audio(s, 1);
        freq_bus = Bus.control(s, 1);
        freq_mod_bus = Bus.audio(s, 1);

        // Setup some default modulation sources.
        amp_eg = Synth.tail(mod_grp, "eg", [\gate_bus, gate_bus,
                                            \out_bus, amp_mod_bus]);
        freq_mod = Synth.tail(mod_grp, "dc_offset", [\out_bus, freq_mod_bus]);
        op = Synth.head(op_grp, "fm_op", [\fbase, fbase,
                                          \fmod_bus, freq_mod_bus,
                                          \abase, gain,
                                          \amod_bus, amp_mod_bus,
                                          \out_bus, op_bus]);

        // LATER: Why can't I use a generic object?
        op_data = Dictionary.new;

        set_fbase = {|value|
            // Set the relative frequency of the operator.
            op.set(\fbase, value);
        };
        op_data.put(\set_fbase, set_fbase);

        set_out = {|value|
            // Set the bus that will receive the operator's output.
            op.set(\out_bus, value);
        };
        op_data.put(\set_out_bus, set_out);

        set_adsr = {|adsr|
            // Set times/levels for the operator's amplitude envelope.
            amp_eg.set(\a, adsr[0]);
            amp_eg.set(\d, adsr[1]);
            amp_eg.set(\s, adsr[2]);
            amp_eg.set(\r, adsr[3]);
        };
        op_data.put(\set_adsr, {|value| set_adsr.value(value)});
        op_data.put(\get_freq_mod_bus, {freq_mod_bus});
    };

    set_algorithm = { |value|
        // Set the outputs of the operators to a pre-defined
        // configuration.
        var algorithm = algorithms[value];
        var set_out_to_speaker = {|operator| operator.at(\set_out_bus).value(op_bus)};
        var set_out_to_mod = {|operator, op_index| operator.at(\set_out_bus).value(ops[op_index].at(\get_freq_mod_bus).value())};

        ops.do({|op, index|
            var mod_op_index = algorithm[index];
            var fun = if(mod_op_index.isNil, {set_out_to_speaker}, {set_out_to_mod});
            fun.value(op, mod_op_index);
        });
    };

    set_base_freq = { |value|
        ops.do({ |op, i|
            op.at(\set_fbase).value(value);
        });
    };

    algorithms = [
        [nil, 0, 1, 2],
        [nil, 0, 1, 0],
        [nil, 0, 0, 0],
        [nil, nil, nil, nil]
    ];

    op_bus = Bus.audio(s, 1);
    op_gate_bus = Bus.audio(s, 1);

    control_grp = Group.tail(s);
    mod_grp = Group.tail(s);
    op_grp = Group.tail(s);

    ops = List();
    num_ops = 4;
    num_ops.do({
        var operator = op.value(op_gate_bus);
        ops.add(operator);
    });

    // DEBUG
    //gate = Synth.head(mod_grp, "dc_offset", [\value, 1.0, \out_bus, op_gate_bus]);
    //{ Out.ar(0, In.ar(op_bus, 1)) }.play(s, addAction: \addToTail);

    s = Dictionary.new;
    s.put(\get_gate_bus, {op_gate_bus});
    s.put(\set_algorithm, set_algorithm);
    s.put(\get_output, {op_bus});
    s.put(\set_base_freq, set_base_freq)
};


// DEBUG
master_grp = Group.head(s);
master_gate_bus = Bus.audio(s, 1);

my_synth = fm_synth.value();
my_synth.at(\set_algorithm).value(2);

gate_bus = my_synth.at(\get_gate_bus).value();
gate = Synth.head(master_grp, "dc_offset", [\value, 0.0, \out_bus, gate_bus]);

MIDIIn.connect;
MIDIIn.noteOn = { |port, chan, note, vel|
    // Not sure if I really need to free the gate synth or not. Is
    // there a better approach?
    my_synth.at(\set_base_freq).value(note.midicps);
    gate.free;
    gate = Synth.head(master_grp, "dc_offset", [\value, 1.0, \out_bus, gate_bus]);
};

MIDIIn.noteOff = {
    // Again, not sure if I need to free the synth everytime I want to
    // change the gate value.
    gate.free;
    gate = Synth.head(master_grp, "dc_offset", [\value, 0.0, \out_bus, gate_bus]);
};

{ Out.ar(0, In.ar(my_synth.at(\get_output).value(), 1)) }.play(s, addAction: \addToTail);
)