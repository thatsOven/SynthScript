package opal:         import *;
package os:           import mkdir, path;
package sys:          import argv;
package math:         import ceil;
package scipy:        import signal;
package time:         import sleep;
package pygame:       import sndarray, mixer;
package scipy.io:     import wavfile;
package threading:    import Thread;
package pygame.mixer: import Sound;
import numpy;
use exec as exec;

new int CHANNELS           = 16,
        NOTES_PER_CHANNEL  = 16,
        SOUND_CHANNELS     = 16,
        FREQUENCY_SAMPLE   = 30000,
        RENDER_FREQ_SAMPLE = 48000;

new float MAX_AMP              = 512,
          NOTE_DURATION        = 1,
          MAX_INSTRUMENT_VALUE = 512,
          BEND_OCTAVES         = 1 / 6; 

$include os.path.join("HOME_DIR",   "compiler", "Compiler.opal")
$include os.path.join("HOME_DIR", "components", "effects.opal")
$include os.path.join("HOME_DIR", "components", "waves.opal")
$include os.path.join("HOME_DIR", "components", "Instrument.opal")
$include os.path.join("HOME_DIR", "components", "Process.opal")

new class Synth {
    new dynamic SAMPLE;
    SAMPLE = 2 * numpy.pi * numpy.arange(0, NOTE_DURATION, NOTE_DURATION / FREQUENCY_SAMPLE);

    new method __init__() {
        this.playing = {};
    
        this.export = False;

        this.eventList = None;
        this.__time    = 0;

        this.defaultInstrument = Instrument(square = Square());
    }

    new method getFreeNote(channel) {
        for i in range(len(this.channels[channel])) {
            if not this.channels[channel][i].get_busy() {
                return i;
            }
        }

        return 0;
    }

    new method getFreeSoundChannel() {
        for channel in this.soundChannels {
            if not channel.get_busy() {
                return channel;
            }
        }

        return this.soundChannels[0];
    }

    new method play(playable, times = 1, blocking = True, volumes = (1.0, 1.0)) {
        if type(playable) is Sound {
            new dynamic ch = this.getFreeSoundChannel();

            ch.play(playable, times - 1);
            ch.set_volume(*volumes);

            if blocking {
                while ch.get_busy() {}
            }
        } else {
            if blocking {
                while times != 0 {
                    playable(this);

                    times--;
                }
            } else {
                new function __play() {
                    external times;

                    while times != 0 {
                        playable(this);

                        times--;
                    }
                }

                Thread(target = __play).start();
            }
        }
    }

    new method __addTime(time) {
        for freqs in this.playing.values() {
            for freq in freqs {
                this.eventList[freq][4] += time;
            }
        }
    }

    new method note(frequency, channel, status, instrument = None, velocity = MAX_AMP, delay = 0, volumes = (1.0, 1.0), release = 0) {
        new dynamic pair = (frequency, channel), ch;

        if instrument is None {
            instrument = this.defaultInstrument;
        }

        if this.export {
            if status {
                this.__addTime(delay);

                if pair in this.playing {
                    this.playing[pair].append(len(this.eventList));
                } else {
                    this.playing[pair] = [len(this.eventList)];
                }

                this.eventList.append([
                    frequency, channel, velocity, instrument, delay, this.__time
                ]);
            } else {
                this.playing[pair].pop();

                if delay != 0 and len(this.eventList) != 0 {
                    this.__addTime(delay);
                    this.eventList[-1][4] += delay;
                }
            }

            this.__time += delay;
            return;
        }

        if status {
            ch = this.getFreeNote(channel);

            if pair in this.playing {
                this.playing[pair].append((ch, velocity, instrument, volumes));
            } else {
                this.playing[pair] = [(ch, velocity, instrument, volumes)];
            }

            ch = this.channels[channel][ch];
            ch.play(
                sndarray.make_sound(
                    (
                        velocity * instrument.get(frequency)
                    ).reshape((-1, 2)).astype(numpy.int16)
                ), -1
            );
            ch.set_volume(*volumes);
        } else {
            ch = this.playing[pair].pop()[0];
            this.channels[channel][ch].fadeout(release);
        }

        if delay > 0 {
            sleep(delay);
        }
    }

    new method pitchBend(amount, channel, delay = 0) {
        for frequency in this.playing.keys() {
            if frequency[1] == channel {
                for i in range(len(this.playing[frequency])) {
                    new dynamic new_ = frequency[0] * (2 ** (BEND_OCTAVES * (amount / 8192))), vol, sound, ch;
                    
                    if this.export {
                        this.eventList.append([
                            new_, channel, this.eventList[this.playing[frequency][i]][2], 
                            this.eventList[this.playing[frequency][i]][3], 0, this.__time
                        ]);

                        this.playing[frequency][i] = len(this.eventList) - 1;
                        
                        this.__addTime(delay);
                        this.__time += delay;
                    } else {
                        sound = sndarray.make_sound(
                            (
                                this.playing[frequency][i][1] * this.playing[frequency][i][2].get(new_)
                            ).reshape((-1, 2)).astype(numpy.int16)
                        );

                        vol = this.playing[frequency][i][3];
                        ch  = this.channels[channel][this.playing[frequency][i][0]];

                        ch.stop();
                        ch.play(sound, -1);
                        ch.set_volume(*vol);
                    }
                }
            }
        }

        if delay > 0 {
            sleep(delay);
        }
    }

    new method exportTracks(source) {
        global FREQUENCY_SAMPLE;
        
        FREQUENCY_SAMPLE = RENDER_FREQ_SAMPLE;

        IO.out("Converting source to event list...\n");
        this.eventList = [];

        new dynamic synth = this;
        exec(source);

        IO.out("Generating base arrays...\n");
        new dynamic tracks = [];
        for ch in range(CHANNELS) {
            for i = len(this.eventList) - 1; i >= 0; i-- {
                if this.eventList[i][1] == ch {
                    tracks.append(
                        numpy.zeros(
                            ceil((this.eventList[i][5] + this.eventList[i][4]) * FREQUENCY_SAMPLE),
                            dtype = numpy.int16
                        )
                    );

                    break;
                }
            } else {
                tracks.append(numpy.zeros(0, dtype = numpy.int16));
            }
        }

        IO.out("Generating waves...\n");
        for event in this.eventList {
            Synth.SAMPLE = 2 * numpy.pi * numpy.arange(0, event[4], 1 / FREQUENCY_SAMPLE);

            new dynamic length = int(event[5] * FREQUENCY_SAMPLE),
                        cLen   = len(tracks[event[1]]) - length - len(Synth.SAMPLE);

            if cLen < 0 {
                cLen = 0;
            }

            event[3]._noStatic();

            tracks[event[1]] += numpy.resize(
                numpy.concatenate((
                    numpy.zeros(length, dtype = numpy.int16),
                    (event[2] * event[3].get(event[0])).astype(numpy.int16),
                    numpy.zeros(cLen, dtype = numpy.int16)
                )), len(tracks[event[1]])
            );
        }

        IO.out("Writing files...\n");;
        if not path.exists("tracks") {
            mkdir("tracks");
        }

        for i in range(len(tracks)) {
            wavfile.write(path.join("tracks", str(i) + ".wav"), FREQUENCY_SAMPLE, tracks[i]);
        }
    }

    new method playCompiled(source) {
        if this.export {
            this.exportTracks(source);
            return;
        }

        mixer.init(FREQUENCY_SAMPLE);
        mixer.set_num_channels(NOTES_PER_CHANNEL * CHANNELS + SOUND_CHANNELS);

        this.channels = [
            [mixer.Channel(NOTES_PER_CHANNEL * j + i) 
            for i in range(NOTES_PER_CHANNEL)] 
            for j in range(CHANNELS)
        ];

        this.soundChannels = [
            mixer.Channel(NOTES_PER_CHANNEL * CHANNELS + i) for i in range(SOUND_CHANNELS)
        ];
    }
}

main {
    if len(argv) == 1 {
        IO.out("SynthScript v2022.10.31 - thatsOven\n");
    } else {
        new bool compile = False;

        if "--compile" in argv {
            compile = True;
            argv.remove("--compile");
        }

        new dynamic synth = Synth();

        if "--export-tracks" in argv {
            synth.export = True;
            argv.remove("--export-tracks");
        }

        if len(argv) == 1 {
            IO.out("No file name given.\n");
            quit;
        }

        new dynamic source;
        with open(argv[1], "r") as script {
            source = script.read();
        }

        if compile {
            source = Compiler(source).compile();
        }

        synth.playCompiled(source);

        if not synth.export {
            exec(source);
        }
    }
}