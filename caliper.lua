-- caliper
--
-- oscillator calibration helper
-- e1 - set reference freq
-- e2 - set reference tone amp
-- e3 - set voltage offset
-- k1 - hold for fine control
-- k2/k3 - lower/raise voltage
--         offset in octaves

engine.name = 'Caliper'

musicutil = require 'musicutil'
filters = require 'filters'

log2 = math.log(2)
c = musicutil.note_num_to_freq(60)
volts_per_octave = 1.2

in_freq_poll = nil
in_freq_detected = false
in_freq = 0
in_filter = filters.mean.new(4)

reference_freq = c

out_offset = 0
out_freq = c
out_volts = 0

diff = 0

fine = 1

dirty = false

redraw_metro = metro.init{
	time = 1 / 15,
	event = function()
		if dirty then
			redraw()
			dirty = false
		end
	end
}

function update_in_freq(new_freq)
	local was_detected = in_freq_detected
	in_freq_detected = new_freq > 0
	if in_freq_detected then
		in_freq = in_filter:next(new_freq)
		compare_freqs()
	elseif was_detected then
		dirty = true
	end
end

function update_output()
	local ratio = math.pow(2, out_offset)
	out_freq = reference_freq * ratio
	engine.sine_freq(out_freq)
	out_volts = out_offset * volts_per_octave
	crow.output[1].volts = out_volts
	compare_freqs()
end

function compare_freqs()
	local ratio = in_freq / out_freq
	diff = math.log(ratio) / log2
	dirty = true
end

function crow_setup()
	crow.clear()
	crow.output[1].slew = 0.02 -- match ReferenceTuner's sine lag
	crow.output[1].shape = 'linear'
end

function init()

	params:set('monitor_level', 0) -- full
	params:set('monitor_mode', 2) -- mono
	params:set('reverb', 1) -- off

	params:add{
		type = 'control',
		id = 'reference_tone_amp',
		name = 'reference tone amp',
		controlspec = controlspec.DB,
		action = function(value)
			engine.sine_amp(util.dbamp(value))
		end
	}
	params:add{
		type = 'control',
		id = 'reference_frequency',
		name = 'reference frequency',
		controlspec = controlspec.new(27.5, 3520, 'exp', 0, c, 'Hz'),
		action = function(value)
			reference_freq = value
			update_output()
		end
	}
	params:add{
		type = 'control',
		id = 'offset',
		name = 'offset',
		controlspec = controlspec.new(-5, 5, 'lin', 0, 0, 'oct'),
		action = function(value)
			out_offset = value
			update_output()
		end
	}
	params:add{
		type = 'option',
		id = 'volts_per_octave',
		name = 'volts per octave',
		options = { '1', '1.2' },
		default = 1,
		action = function(value)
			volts_per_octave = value == 1 and 1 or 1.2
			update_output()
		end
	}
		
	params:bang()

	crow.add = crow_setup
	crow_setup()
	
	in_freq_poll = poll.set('input_freq', update_in_freq)
	in_freq_poll.time = 1 / 15
	in_freq_poll:start()

	redraw_metro:start()
end

function draw_line(n, label, value)
	local y = n * 9 + 7
	screen.move(14, y)
	screen.text(label)
	screen.move(114, y)
	screen.text_right(string.format('%.2f', value))
end

function draw_tuner()
	local y = 56.5
	local abscents = math.floor(math.abs(diff * 1200) + 0.5)
	local base_level = 2
	local notch_level = 4
	local notch_height = 2
	if in_freq_detected then
		base_level = math.max(2, 4 - abscents)
		notch_level = math.max(7, 15 - abscents)
		notch_height = math.max(1, 4 - abscents)
	end

	screen.move(63.5, y - 2.5)
	screen.line(63.5, y + 2.5)
	screen.level(1)
	screen.stroke()

	screen.move(0, y)
	screen.line(128, y)
	screen.level(base_level)
	screen.stroke()

	screen.move(63.5 + math.max(-63, math.min(63, math.atan(diff * 3) * 44)), y - notch_height)
	screen.line_rel(0, notch_height * 2 + 1)
	screen.level(notch_level)
	screen.stroke()
end

function redraw()
	screen.clear()

	screen.level(in_freq_detected and 10 or 2)
	draw_line(1, 'in freq:', in_freq)

	screen.level(10)
	draw_line(2, 'reference:', out_freq)
	draw_line(3, 'volts:', out_volts)
	draw_line(4, 'diff (cents):', diff * 1200)

	draw_tuner()

	screen.update()
end

function key(n, z)
	if n == 1 then
		fine = z == 1 and 0.05 or 1
	elseif z == 1 then
		if n == 2 then
			params:delta('offset', -10)
		elseif n == 3 then
			params:delta('offset', 10)
		end
	end
end

function enc(n, d)
	if n == 1 then
		params:delta('reference_frequency', d * fine / 4)
	elseif n == 2 then
		params:delta('reference_tone_amp', d)
	elseif n == 3 then
		params:delta('offset', d * fine / 2)
	end
end

function cleanup()
	if in_freq_poll ~= nil then
		in_freq_poll:stop()
	end
	redraw_metro:stop()
end
