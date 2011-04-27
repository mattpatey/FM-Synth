(

// Operator prototype
var op = { | freq=100, mod=1, amp=0.2 | 
    { SinOsc.ar(freq * mod, 0, amp) };
};



// Modulators for operator 2
var rnd_fre_mod = { LFNoise0.kr(0.3, 7, 1) };
var rnd_fre = { LFNoise0.kr(rnd_fre_mod, 10000, 1) };

var rnd_amp_mod = { LFNoise0.kr(0.3, 7, 1) };
var rnd_amp = { LFNoise0.kr(rnd_amp_mod, 1000, 1) };

// The operators
var op2 = op.value(freq: {SinOsc.ar(rnd_fre, 0, rnd_amp)});
var op1 = op.value(freq: 400, 
                   mod: op2,
                   amp: 0.2);
{([op1, op1])}.play;
)

{([SinOsc.ar(440, 0, 0.2), SinOsc.ar(442, 0, 0.2)])}.play;