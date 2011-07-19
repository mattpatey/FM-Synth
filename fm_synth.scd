(
SynthDef("fm_op", { |fbase, fmod_bus, freq_bus, abase, amod_bus, out_bus|
    // A standard, run-of-the-mill sine wave oscillator.
    //
    // FM and AM modulation are possible by passing audio rate signals to
    // `fmod` and `amod`, respectively.
    var oscillator = SinOsc.ar(In.ar(fmod_bus) * (fbase + In.kr(freq_bus)), 0, abase * In.ar(amod_bus));
    Out.ar(out_bus, oscillator);
}).send(s);

SynthDef("eg", { |a=0.01, d=0.7, s=0.0, r=0.01, gate_bus, level_bus, out_bus|
    // A standard, run-of-the-mill ADSR envelope generator, with
    // modulation possibilities on the peak level.
    var envelope = EnvGen.ar(Env.adsr(a, d, s, r, In.ar(level_bus)), In.ar(gate_bus));
    Out.ar(out_bus, envelope);
}).send(s);

SynthDef("dc_offset", { |value=1.0, out_bus|
    // A static signal.
    var signal = DC.ar(value);
    Out.ar(out_bus, signal);
}).send(s);
)

(
var fm_synth,
master_grp,
my_synth,
srv;

fm_synth = {
    // Four-operator FM synthesizer.
    //
    //
    var algorithms,
	active_voices,
    audio_out,
    control_grp,
    current_voice,
	gate_bus,
    get_voice_gate,
    mod_grp,
    num_voices,
    op,
    op_grp,
    ops_per_voice,
    play_note,
    set_algorithm,
	stop_note,
    synth_instance,
    voice,
	v_gate,
	v_output,
	v,
    voices,
	voice_index;

    voice = {|gate_bus, num_ops, voice_out|
        // Single voice for an FM synthesizer.
        //
        // A voice consists of one or more FM operators.
        var activate,
		deactivate,
		gate,
		ops,
		op_level_bus,
		peak,
        set_algorithm,
		set_base_freq,
        voice_instance;

		// TODO: why aren't these control busses?
		gate_bus = Bus.audio(srv, 1);
		op_level_bus = Bus.audio(srv, 1);

        set_algorithm = {|algorithm|
            var set_out_to_speaker = {|operator| operator.at(\set_out_bus).value(audio_out)};
            var set_out_to_mod = {|operator, op_index| operator.at(\set_out_bus).value(ops[op_index].at(\get_freq_mod_bus).value())};

            ops.do({|op, index|
                var mod_op_index = algorithm[index];
                var output = if(mod_op_index.isNil, {set_out_to_speaker}, {set_out_to_mod});
                output.value(op, mod_op_index);
            });
        };

        set_base_freq = { |value|
            // Sets the base frequency for all operators.
            ops.do({ |op|
                op.at(\set_fbase).value(value);
            });
        };

        ops = List();
        num_ops.do({
			var operator;
            operator = op.value(gate_bus, voice_out, op_level_bus);
            ops.add(operator);
        });

		activate = { |note, vel|
			// TODO - DEBUG - remove
			postln("activate " + note + "@" + vel);

			set_base_freq.value(note.midicps);
			peak.free;
			peak = Synth.head(
				master_grp,
				"dc_offset",
				[
					\value, vel/127,
					\out_bus, op_level_bus
				]
			);
			gate.free;
			gate = Synth.head(
				master_grp,
				"dc_offset",
				[
					\value, 1.0,
					\out_bus, gate_bus
				]);
		};

		deactivate = {
			// TODO - DEBUG - remove
			postln("deactivate");
			gate.free;
			gate = Synth.head(
				master_grp,
				"dc_offset",
				[
					\value, 0.0,
					\out_bus, gate_bus
				]);
		};

        voice_instance = Dictionary.new;
		voice_instance.put(\activate, activate);
		voice_instance.put(\deactivate, deactivate);
        voice_instance.put(\set_algorithm, set_algorithm);
        voice_instance.put(\get_gate_bus, {gate_bus});
    };

    op = { |gate_bus, out, op_level_bus, fbase=440, gain=1|
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
        var amp_eg,
        amp_mod_bus,
        freq_bus,
        freq_mod,
        freq_mod_bus,
        get_freq_mod_bus,
        op,
        op_instance,
        set_adsr,
        set_fbase,
        set_out_bus;

        // Instances of an FM synth create busses on the fly.
        amp_mod_bus = Bus.audio(s, 1);
        freq_bus = Bus.control(s, 1);
        freq_mod_bus = Bus.audio(s, 1);

        // Setup some default modulation sources.
        amp_eg = Synth.tail(
            mod_grp,
            "eg",
            [\gate_bus, gate_bus,
             \level_bus, op_level_bus,
             \out_bus, amp_mod_bus]);
        freq_mod = Synth.tail(
            mod_grp,
            "dc_offset",
            [\out_bus, freq_mod_bus]);
        op = Synth.head(op_grp, "fm_op", [
            \fbase, fbase,
            \fmod_bus, freq_mod_bus,
            \abase, gain,
            \amod_bus, amp_mod_bus,
            \out_bus, out]);

        // LATER: Why can't I use a generic object?
        op_instance = Dictionary.new;

        set_fbase = {|value|
            // Set the relative frequency of the operator.
            op.set(\fbase, value);
        };
        op_instance.put(\set_fbase, set_fbase);

        set_out_bus = {|value|
            // Set the bus that will receive the operator's output.
            op.set(\out_bus, value);
        };
        op_instance.put(\set_out_bus, set_out_bus);

        set_adsr = {|adsr|
            // Set times/levels for the operator's amplitude envelope.
            amp_eg.set(\a, adsr[0]);
            amp_eg.set(\d, adsr[1]);
            amp_eg.set(\s, adsr[2]);
            amp_eg.set(\r, adsr[3]);
        };
        op_instance.put(\set_adsr, {|value| set_adsr.value(value)});
        op_instance.put(\get_freq_mod_bus, {freq_mod_bus});
    };

    set_algorithm = { |value|
        // Define the structure of the FM by setting the outputs of
        // each voice's operators' outputs.
        var algorithm = algorithms[value];
        // voices.do({|voice, i|
        //     voice.at(\set_algorithm).value(algorithm);
        // });
    };

    algorithms = [
        [nil, 0, 1, 2],
        [nil, 0, 1, 0],
        [nil, 0, 0, 0],
        [nil, nil, nil, nil]
    ];

    get_voice_gate = {
        voices[0].at(\get_gate_bus).value();
    };

    // Set-up audio channels.
    audio_out = Bus.audio(s, 1);

    // Set-up groups.
    control_grp = Group.tail(s);
    mod_grp = Group.tail(s);
    op_grp = Group.tail(s);

    // Set-up voices.
    num_voices = 4;
    ops_per_voice = 4;
    voices = List();

    num_voices.do({
        v_gate = Bus.audio(s, 1);
        v_output = Bus.audio(s, 1);
        v = voice.value(v_gate, ops_per_voice, audio_out);
        voices.add(v);
    });

	voice_index = 0;
    current_voice = {
		var index, last_voice;
		last_voice = num_voices - 1;
		voice_index = if(voice_index < last_voice, {voice_index + 1}, {0});
        voices[voice_index];
    };


    play_note = { |note, vel|
		// Play a note at a specific velocity, using the current
		// voice.
		//
		var voice;
        voice = current_voice.value;
		active_voices.put(note, voice);
		voice.at(\activate).value(note, vel);

		// TODO: remove - DEBUG
		//postln("Note on: " + active_voices);
    };

	stop_note = { |note|
		// Tell a voice to stop playing.
		//
		var voice;
		voice = active_voices.matchAt(note).value;
		active_voices.removeAt(note);
		voice.at(\deactivate).value();

		// TODO: remove - DEBUG
		//postln("Note off: " + voice);
		//postln("          " + active_voices);
	};

	active_voices = Dictionary.new;

    synth_instance = Dictionary.new;
    synth_instance.put(\set_algorithm, set_algorithm);
    synth_instance.put(\get_output, {audio_out});
    synth_instance.put(\play_note, play_note);
	synth_instance.put(\stop_note, stop_note);
};

// Make MIDI connections.
MIDIIn.connect;
MIDIIn.noteOn = { |port, chan, note, vel|
    my_synth.at(\play_note).value(note, vel);
};

MIDIIn.noteOff = { |port, chan, note, vel|
	my_synth.at(\stop_note).value(note);
};

// DEBUG
srv = Server.default;

master_grp = Group.head(srv);

my_synth = fm_synth.value();
my_synth.at(\set_algorithm).value(2);


{ Out.ar(0, In.ar(my_synth.at(\get_output).value(), 1)) }.play(srv, addAction: \addToTail);
)