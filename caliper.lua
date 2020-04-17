-- caliper
--
-- oscillator calibration helper
-- e1 - set reference freq
-- e2 - set reference tone amp
-- e3 - set voltage offset
-- k1 - hold for fine control
-- k2/k3 - lower/raise voltage
--         offset in octaves

engine.name = 'Analyst'

musicutil = require 'musicutil'
filters = require 'filters'

log2 = math.log(2)
c = musicutil.note_num_to_freq(60) -- middle C (TODO: right?)
volts_per_octave = 1.2

in_freq_poll = nil
in_freq_detected = false
in_freq = 0
in_filter = filters.mean.new(8)

reference_freq = c

out_offset = 0
out_freq = c
out_volts = 0

diff = 0

fine = 1

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
	in_freq_detected = new_freq > 0
	if in_freq_detected then
		in_freq = in_filter:next(new_freq)
		compare_freqs()
	end
	dirty = true
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
	crow.output[1].slew = 0.01 -- match TestSine's lag
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
	
	pitch_poll = poll.set('pitch_analyst_l', update_in_freq)
	pitch_poll.time = 1 / 15
	pitch_poll:start()

	dirty = true
	redraw_metro:start()

end

function redraw()
	screen.clear()

	local l = 14
	local r = 114

	local tuner = 54.5

	if in_freq_detected then
		screen.level(10)
	else
		screen.level(2)
	end
	screen.move(l, 12)
	screen.text('in freq:')
	screen.move(r, 12)
	screen.text_right(string.format('%.2f', in_freq))

	screen.level(10)
	screen.move(l, 21)
	screen.text('reference:')
	screen.move(r, 21)
	screen.text_right(string.format('%.2f', out_freq))

	screen.move(l, 30)
	screen.text('volts:')
	screen.move(r, 30)
	screen.text_right(string.format('%.2f', out_volts))

	screen.move(l, 39)
	screen.text('diff (cents):')
	screen.move(r, 39)
	screen.text_right(string.format('%.2f', diff * 1200))

	screen.move(0, tuner)
	screen.line(128, tuner)
	screen.level(2)
	screen.stroke()
	screen.move(63.5, tuner - 2.5)
	screen.line(63.5, tuner + 2.5)
	screen.level(1)
	screen.stroke()

	screen.move(63.5 + math.atan(diff) * 45, tuner - 2.5)
	screen.line_rel(0, 5)
	screen.level(10)
	screen.stroke()

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
		params:delta('offset', d * fine)
	end
end

function cleanup()
	if in_freq_poll ~= nil then
		in_freq_poll:stop()
	end
	redraw_metro:stop()
end
