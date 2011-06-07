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
    var envelope = EnvGen.ar(Env.adsr(a, d, s, r), In.ar(gate));
    Out.ar(out, envelope);
}).send(s);

SynthDef("dc_offset", { |value=1.0, out|
    // A static signal.
    var signal = DC.ar(value);
    Out.ar(out, signal);
}).send(s);

SynthDef("gate", { |control_bus, out_bus|
    // A static signal.
    Gate.ar(DC.ar(1.0), In.ar(control_bus));
}).send(s);
)

(
var fm_synth, my_synth;

fm_synth = {
	// Four-operator FM synthesizer.
	//
	//
	var algorithms, control_grp, mod_grp,
        num_ops, op, op_bus, op_grp,
        ops, sequence, set_algorithm,
	    gate_bus, op_gate_bus, gate,
	    gate_control;

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
        amp_eg = Synth.tail(mod_grp, "eg", [\gate, gate_bus,
                                            \out, amp_mod_bus]);
        freq_mod = Synth.tail(mod_grp, "dc_offset", [\out, freq_mod_bus]);
        op = Synth.head(op_grp, "fm_op", [\fbase, fbase,
                                          \fmod, freq_mod_bus,
                                          \abase, gain,
                                          \amod, amp_mod_bus,
                                          \out, op_bus]);

        // LATER: Why can't I use a generic object?
        op_data = Dictionary.new;

        set_fbase = {|value|
			// Set the relative frequency of the operator.
            op.set(\fbase, value);
        };
        op_data.put(\set_fbase, set_fbase);

        set_out = {|value|
			// Set the bus that will receive the operator's output.
            op.set(\out, value);
        };
        op_data.put(\set_out, set_out);

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

    set_algorithm = {|value|
		// Set the outputs of the operators to a pre-defined
		// configuration.
        var algorithm = algorithms[value];
        var set_out_to_speaker = {|operator| operator.at(\set_out).value(op_bus)};
        var set_out_to_mod = {|operator, op_index| operator.at(\set_out).value(ops[op_index].at(\get_freq_mod_bus).value())};

        ops.do({|op, index|
            var mod_op_index = algorithm[index];
            var fun = if(mod_op_index.isNil, {set_out_to_speaker}, {set_out_to_mod});
            fun.value(op, mod_op_index);
        });
    };

    algorithms = [
        [nil, 0, 1, 2],
        [nil, 0, 1, 0],
        [nil, 0, 0, 0],
        [nil, nil, nil, nil]
    ];

    op_bus = Bus.audio(s, 1);
	gate_bus = Bus.audio(s, 1);
	op_gate_bus = Bus.audio(s, 1);

    control_grp = Group.tail(s);
    mod_grp = Group.tail(s);
    op_grp = Group.tail(s);

	gate_control = Synth.tail(control_grp, "dc_offset", [\value, 0.0, \out, gate_bus]);
	gate = Synth.tail(control_grp, "gate", [\control_bus, gate_bus, \out, op_gate_bus]);

    ops = List();
    num_ops = 4;
    num_ops.do({
        var operator = op.value(op_gate_bus);
        ops.add(operator);
    });

    MIDIIn.connect;

    MIDIIn.noteOn = { |port, chan, note, vel|
		// Send '1' to gate bus.
		gate_control.free;
		gate_control = Synth.tail(control_grp, "dc_offset", [\value, 1.0, \out, gate_bus]);
	};
    MIDIIn.noteOff = {
		// Send '0' to gate bus.
		gate_control.free;
		gate_control = Synth.tail(control_grp, "dc_offset", [\value, 0.0, \out, gate_bus]);
	};

	// DEBUG
	set_algorithm.value(0);
    { Out.ar(0, In.ar(op_bus, 1)) }.play(s, addAction: \addToTail);
};


// DEBUG
fm_synth.value();
)