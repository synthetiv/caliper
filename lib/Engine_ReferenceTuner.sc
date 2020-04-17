Engine_ReferenceTuner : CroneEngine {

	var sine_synth;
	var pitch_in_buffer;
	var pitch_in_synth;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {

		SynthDef.new(\sine, {
			arg out, freq = 440, amp = 0, freqLag = 0.02, ampLag = 0.05;
			freq = Lag.kr(freq, freqLag);
			amp = Lag.kr(amp, ampLag);
			Out.ar(out, SinOsc.ar(freq) * amp ! 2);
		}).add;

		SynthDef.new(\analyst, {
			arg in_l, in_r, out, ampThreshold = 0.001, threshold = 0.93, n = 2048, k = 0, overlap = 1024, smallCutoff = 0.5;
			var input, freq, hasFreq, amp;
			input = In.ar([in_l, in_r]).sum;
			#freq, hasFreq = Tartini.kr(input, threshold, n, k, overlap, smallCutoff);
			amp = Amplitude.kr(input);
			freq = Select.kr(amp > ampThreshold, [-1, freq]);
			Out.kr(out, [freq, hasFreq, amp]);
		}).add;

		context.server.sync;

		sine_synth = Synth.new(\sine, target: context.og);
		pitch_in_buffer = Bus.control(context.server, 3);
		pitch_in_synth = Synth.new(\analyst, [
			\in_l, context.in_b[0],
			\in_r, context.in_b[1],
			\out, pitch_in_buffer
		], context.xg); // "process" group

		this.addCommand(\sine_amp, "f", {
			arg msg;
			sine_synth.set(\amp, msg[1]);
		});

		this.addCommand(\sine_freq, "f", {
			arg msg;
			sine_synth.set(\freq, msg[1]);
		});

		this.addCommand(\amp_threshold, "f", {
			arg msg;
			pitch_in_synth.set(\ampThreshold, msg[1]);
		});

		this.addPoll(\input_freq, {
			var freq, hasFreq, amp;
			#freq, hasFreq, amp = pitch_in_buffer.getnSynchronous(3);
			freq;
		});

		this.addPoll(\input_freq_clarity, {
			var freq, hasFreq, amp;
			#freq, hasFreq, amp = pitch_in_buffer.getnSynchronous(3);
			hasFreq;
		});

		this.addPoll(\input_amp, {
			var freq, hasFreq, amp;
			#freq, hasFreq, amp = pitch_in_buffer.getnSynchronous(3);
			amp;
		});
	}

	free {
		sine_synth.free;
		pitch_in_synth.free;
		pitch_in_buffer.free;
	}
}
