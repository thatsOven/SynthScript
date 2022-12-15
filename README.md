# SynthScript
A basic software synthetizer programmable in Python and a dedicated language.

To run, open or compile `SynthScript.opal`, and pass it a file to run as a command line argument.
# Command line arguments
- `--compile`
	- Tells the program that the given file is written in SynthScript and needs to be compiled.
	- **Usage**: --compile
- `--export-tracks`
	- Generates a .wav file for each playback channel.
	- **Usage**: --export-tracks
- `--realtime`
	- Skips the rendering process and plays the source code directly. This option will produce a lower quality sound and more inaccuracies in playback.
	- **Usage**: --realtime
# Synthetizer tools
## `Instrument`
An `Instrument` is a way to combine waveforms and `Process`es.
### Arguments
```
Instrument(**instruments, postProcess, preProcess, static)
```
- `**instruments`: a list of keyword arguments used to refer to other `Instrument`s or waveforms.
- `postProcess`: (Optional) used to refer to a `Process` object for post processing;
- `preProcess`: (Optional) used to refer to a `Process` object for pre processing;
- `static`: If set to `True`, the `Instrument` will not react to variable changes. Useful for performance reasons. `False` by default.
## `Process`
A `Process` is a way to combine effects.
### Arguments
```
Process(**effects, static)
```
- `**effects`: a list of keyword arguments used to refer to other `Process` objects or effects.
- `static`
## Waveforms
Waveforms all take two basic arguments when generated:
```
Wave(amplitude, static)
```
- `amplitude`: the waveform's amplitude;
- `static`

Available waveforms are:
- `Square(amplitude, duty, static)`
	- `duty`: the square wave's duty cycle. Can be either a float or another waveform or `Instrument`. Default is 0.5.
- `Sawtooth(amplitude, width, static)`
	- `width`: width of the rising ramp as a proportion of the total cycle of the sawtooth wave.
- `Noise(amplitude, static)`
## Effects
### Post processing effects
- `Envelope(attack, decay, sustain, release, static)`
	- `attack`: sets the time it takes for the signal to rise from an amplitude of 0 to full amplitude. Default is 0.
	- `decay`: sets the time it takes for the signal to fall from full amplitude to the sustain level.
	- `sustain`: sets the amplitude of the wave for the time the key is held.
	- `release`: sets the time it takes for the sound to decay from the sustain level to an amplitude of 0 when the key is released.
### Pre processing effects
- `Vibrato(osc, amount, static)`
	- `osc`: sets the rate at which the frequency oscillates. Default is 0.25.
	- `amount`: sets the amount of variation of frequency. Default is 1.
- `FreqSweep(toFreq, time)`
	- `toFreq`: the destination frequency.
	- `time`: the amount of time in which the wave's frequency should reach the destination frequency.
# The language and the Python API
NOTE: The compiler will ignore any tabs or newlines. Spaces however make a difference in syntax, unless they're inside brackets.
## Statements
Statements are not case sensitive. 
### `CREATE <object> AS <variable name>`
- The `CREATE` statement is used to create instances of any class.
- Optionally, a `WITH` clause can be added to pass arguments to the class constructor. Example:
	```
	CREATE Instrument AS myInstrument WITH (
		mySquare = Square(),
		myNoise  = Noise()
	)
	```
- The Python equivalent of the snippet above would be:
	```
	myInstrument = Instrument(
		mySquare = Square(),
		myNoise  = Noise()
	)
	```
### `SET <property> OF <variable or property> TO <value>`
 - Assigns values to variables or properties of objects.
 - Example:
	```
	SET duty OF myInstrument.mySquare TO 0.3
	```
- The Python equivalent of the snippet above would be:
	```
	myInstrument.mySquare.duty = 0.3
	```
### `NOTE <frequency> CHANNEL <channel id> <status>`
- Plays or stops frequencies on a given channel id.
- The frequency can be:
	- A number, in which case it will be interpreted as a value in Hertz;
	- A note (example: `NOTE c4 CHANNEL 1 ON`). Notes are not case sensitive.
- The channel id can be anywhere in the range 0-15;
- The status can assume any value that is considered `True`, including language specific values such as ON and OFF (case insensitive).
- An optional `USING` clause can be added, to specify which instrument to use. If not specified, the synthetizer will use the default instrument. Example:
	```
	NOTE C4 CHANNEL 3 ON USING myInstrument
	```
- Optionally, a `WITH` clause can be added to pass arguments to the `note` method:
	- `velocity`: relative volume of the note. Can be anywhere in the range 0-512. Default is 512.
	- `delay`: amount of time (in seconds) to wait after the note started playing. Default is 0.
- Example:
	```
	NOTE C4 CHANNEL 2 ON USING myInstrument WITH (
		velocity = 128,
		delay    = 1.5
	)
	
	NOTE C4 CHANNEL 2 OFF
	```
- You can use SynthScript's Python API to do the same operation. The `note` method is composed like this:
	```
	synth.note(
		frequency, channel, status, 
		<instrument>, <velocity>, <delay>
	)
	```
	Arguments in angular brackets are optional.
### `PITCHBEND CHANNEL <channel id> BY <amount>`
- Varies the pitch of all notes in a given channel.
- The channel id can be anywhere in the range 0-15;
- The amount can be anywhere in the range -8192 to 8192;
- Optionally, a `WITH` clause can be added to pass arguments to the `pitchBend` method:
	- `delay`: amount of time (in seconds) to wait after the pitch bending has been applied. Default is 0.
- Example:
	```
	PITCHBEND CHANNEL 2 BY -123 WITH (
		delay = 0.25
	)
	PITCHBEND CHANNEL 2 BY -292 
	```
- You can use SynthScript's Python API to do the same operation. The `pitchBend` method is composed like this:
	```
	synth.pitchBend(amount, channel, <delay>)
	```
	Arguments in angular brackets are optional.
### `WAIT <time>`
- Waits a certain amount of time (in milliseconds)
- Example:
	```
	WAIT 500
	```
### `DEFAULT`
- Creates an `Instrument` and sets it as default.
- Example:
	```
	DEFAULT (
		mySquare = Square(
			duty = 0.8
		)
	)
	```
- The Python equivalent of the snippet above would be:
	```
	synth.defaultInstrument = Instrument(
		mySquare = Square(
			duty = 0.8
		)
	)
	```
### `DEFINE <section name>`
- Defines a callable segment of code. Equivalent of a Python function.
- Example: 
	```
	DEFINE shortNote
		NOTE A4 CHANNEL 1 ON WITH (
			delay = 1
		)
		NOTE A4 CHANNEL 1 OFF
		WAIT 1000
	END
	```
### `PLAY <object>`
- Plays a defined section or pygame `Sound` object.
- Optionally, a `WITH` clause can be added to pass arguments to the `play` method:
	- `times`: amount of times the object will be played. Default is 1.
	- `blocking`: sets whether the method should wait until the end of the playback (True) or not (False). Default is True.
	- Example:
	```
	PLAY shortNote WITH (
		times = 2
	)
	```
- You can use SynthScript's Python API to do the same operation. The `play` method is composed like this:
	```
	synth.play(playable, <times>, <blocking>)
	```
	Arguments in angular brackets are optional.
