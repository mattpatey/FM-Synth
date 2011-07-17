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
gate,
gate_bus,
master_grp,
my_synth,
op_level_bus,
peak,
srv,
set_base_freq;

fm_synth = {
    // Four-operator FM synthesizer.
    //
    //
    var algorithms,
    audio_out,
    control_grp,
    mod_grp,
    num_voices,
    op,
    op_grp,
    ops_per_voice,
    set_algorithm,
    synth_instance,
    voice,
    voices,
    voice_gate_busses;

    voice = {|gate_bus, num_ops, voice_out|
        // Single voice for an FM synthesizer.
        //
        // A voice consists of one or more FM operators.
        var ops,
        set_algorithm,
        voice_instance;
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
            ops.do({|op|
                op.at(\set_fbase).value(value);
            });
        };

        ops = List();
        num_ops.do({
            var operator = op.value(gate_bus, voice_out);
            ops.add(operator);
        });

        voice_instance = Dictionary.new;
        voice_instance.put(\set_algorithm, set_algorithm);
        voice_instance.put(\set_base_freq, set_base_freq);
        voice_instance.put(\get_gate_bus, {gate_bus});
    };

    op = { |gate_bus, out, fbase=440, gain=1|
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

    set_base_freq = { |value|
        // Sets the base frequency for all voices.
        voices.do({ |voice, i|
            voice.at(\set_base_freq).value(value);
        });
    };

    // Set-up audio channels.
    audio_out = Bus.audio(s, 1);

    // Set-up groups.
    control_grp = Group.tail(s);
    mod_grp = Group.tail(s);
    op_grp = Group.tail(s);

    // Set-up voices.
    num_voices = 1;
    ops_per_voice = 4;
    voices = List();
    num_voices.do({
        var v_gate = Bus.audio(s, 1);
        var v_output = Bus.audio(s, 1);
        var v = voice.value(v_gate, ops_per_voice, audio_out);
        voices.add(v);
    });

    // DEBUG
    //gate = Synth.head(mod_grp, "dc_offset", [\value, 1.0, \out_bus, op_gate_bus]);
    //{ Out.ar(0, In.ar(audio_out, 1)) }.play(s, addAction: \addToTail);

    synth_instance = Dictionary.new;
    synth_instance.put(\get_voice_gate, {voices[0].at(\get_gate_bus).value()}); // TODO: return voice bus dynamically
    synth_instance.put(\set_algorithm, set_algorithm);
    synth_instance.put(\get_output, {audio_out});
    synth_instance.put(\set_base_freq, set_base_freq);
};

// Make MIDI connections.
MIDIIn.connect;
MIDIIn.noteOn = { |port, chan, note, vel|
    // Not sure if I really need to free the gate synth or not. Is
    // there a better approach?
    my_synth.at(\set_base_freq).value(note.midicps);
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
    gate = Synth.head(master_grp, "dc_offset", [\value, 1.0, \out_bus, gate_bus]);
};

MIDIIn.noteOff = {
    // Again, not sure if I need to free the synth everytime I want to
    // change the gate value.
    gate.free;
    gate = Synth.head(master_grp, "dc_offset", [\value, 0.0, \out_bus, gate_bus]);
};

// DEBUG
srv = Server.default;

master_grp = Group.head(srv);

op_level_bus = Bus.audio(srv, 1);

my_synth = fm_synth.value();
my_synth.at(\set_algorithm).value(2);
gate_bus = my_synth.at(\get_voice_gate).value();
gate = Synth.head(master_grp, "dc_offset", [\value, 0.0, \out_bus, gate_bus]);

{ Out.ar(0, In.ar(my_synth.at(\get_output).value(), 1)) }.play(srv, addAction: \addToTail);
)