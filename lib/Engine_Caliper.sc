Engine_Caliper : CroneEngine {

	var sine_synth;
	var pitch_in_bus;
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
			# freq, hasFreq = Tartini.kr(input, threshold, n, k, overlap, smallCutoff);
			amp = Amplitude.kr(input);
			freq = Select.kr((amp > ampThreshold) * (hasFreq > 0.9), [-1, freq]);
			Out.kr(out, freq);
		}).add;

		context.server.sync;

		sine_synth = Synth.new(\sine, target: context.og);
		pitch_in_bus = Bus.control(context.server);
		pitch_in_synth = Synth.new(\analyst, [
			\in_l, context.in_b[0],
			\in_r, context.in_b[1],
			\out, pitch_in_bus
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
			pitch_in_bus.getSynchronous;
		});
	}

	free {
		sine_synth.free;
		pitch_in_synth.free;
		pitch_in_bus.free;
	}
}
