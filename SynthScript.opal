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
$include os.path.join("HOME_DIR", "components", "Midi.opal")

new class Synth {
    enum {
        REALTIME, RENDER, EXPORT
    }

    enum EventType {
        NOTE, PLAYBACK
    }

    new dynamic SAMPLE;
    SAMPLE = 2 * numpy.pi * numpy.arange(0, NOTE_DURATION, NOTE_DURATION / FREQUENCY_SAMPLE);

    new method __init__() {
        this.playing = {};
    
        this.mode = Synth.RENDER;

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

    new method play(playable, times = 1, blocking = True) {
        new dynamic type_ = type(playable);

        if type_ is Sound {
            if this.mode == Synth.REALTIME {
                new dynamic ch = this.getFreeSoundChannel();

                ch.play(playable, times - 1);

                if blocking {
                    while ch.get_busy() {}
                }
            } else {
                new dynamic array = sndarray.array(playable), delay;

                if blocking {
                    delay = len(array) / FREQUENCY_SAMPLE;
                } else {
                    delay = 0;
                }

                this.eventList.append([
                    Synth.EventType.PLAYBACK, array, delay, this.__time
                ]);

                this.__time += delay;
            }
        } else {
            if type_ is Midi {
                new function __play() {
                    external times;

                    while times != 0 {
                        for event in playable.events {
                            match event[0] {
                                case "note" {
                                    this.note(*(event[1:]));
                                }
                                case "pitch" {
                                    this.pitchBend(*(event[1:]));
                                }
                            }
                        }

                        times--;
                    }
                }
            } else {
                new function __play() {
                    external times;

                    while times != 0 {
                        playable(this);

                        times--;
                    }
                }
            }

            if blocking {
                __play();
            } else {
                Thread(target = __play).start();
            }
        } 
    }

    new method __addTime(time) {
        for freqs in this.playing.values() {
            for freq in freqs {
                this.eventList[freq][5] += time;
            }
        }
    }

    new method note(frequency, channel, status, instrument = None, velocity = MAX_AMP, delay = 0) {
        new dynamic pair = (frequency, channel), ch;

        if instrument is None {
            instrument = this.defaultInstrument;
        }

        if this.mode in (Synth.EXPORT, Synth.RENDER) {
            if status {
                this.__addTime(delay);

                if pair in this.playing {
                    this.playing[pair].append(len(this.eventList));
                } else {
                    this.playing[pair] = [len(this.eventList)];
                }

                this.eventList.append([
                    Synth.EventType.NOTE, frequency, channel, velocity, instrument, delay, this.__time
                ]);
            } else {
                this.playing[pair].pop();

                if delay != 0 and len(this.eventList) != 0 {
                    this.__addTime(delay);
                }
            }

            this.__time += delay;
            return;
        }

        if status {
            ch = this.getFreeNote(channel);

            if pair in this.playing {
                this.playing[pair].append((ch, velocity, instrument));
            } else {
                this.playing[pair] = [(ch, velocity, instrument)];
            }

            ch = this.channels[channel][ch];
            ch.play(
                sndarray.make_sound(
                    (
                        velocity * instrument.get(frequency)
                    ).reshape((-1, 2)).astype(numpy.int16)
                ), -1
            );
        } else {
            ch = this.playing[pair].pop()[0];
            this.channels[channel][ch].stop();
        }

        if delay > 0 {
            sleep(delay);
        }
    }

    new method pitchBend(amount, channel, delay = 0) {
        for frequency in this.playing.keys() {
            if frequency[1] == channel {
                for i in range(len(this.playing[frequency])) {
                    new dynamic new_ = frequency[0] * (2 ** (BEND_OCTAVES * (amount / 8192))), sound, ch;
                    
                    if this.mode in (Synth.EXPORT, Synth.RENDER) {
                        this.eventList.append([
                            Synth.EventType.NOTE, new_, channel, this.eventList[this.playing[frequency][i]][3], 
                            this.eventList[this.playing[frequency][i]][4], 0, this.__time
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

                        ch = this.channels[channel][this.playing[frequency][i][0]];

                        ch.stop();
                        ch.play(sound, -1);
                    }
                }
            }
        }

        if delay > 0 {
            sleep(delay);
        }
    }

    new method render(source) {
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
                if this.eventList[i][0] == Synth.EventType.NOTE and this.eventList[i][2] == ch {
                    tracks.append(
                        numpy.zeros(
                            ceil((this.eventList[i][6] + this.eventList[i][5]) * FREQUENCY_SAMPLE),
                            dtype = numpy.int16
                        )
                    );

                    break;
                }
            } else {
                tracks.append(numpy.zeros(0, dtype = numpy.int16));
            }
        }

        for i = len(this.eventList) - 1; i >= 0; i-- {
            if this.eventList[i][0] == Synth.EventType.PLAYBACK {
                tracks.append(
                    numpy.zeros(
                        ceil((this.eventList[i][2] + this.eventList[i][3]) * FREQUENCY_SAMPLE),
                        dtype = numpy.int16
                    )
                );

                break;
            }
        } else {
            tracks.append(numpy.zeros(0, dtype = numpy.int16));
        }

        IO.out("Generating waves...\n");
        for event in this.eventList {
            if event[0] == Synth.EventType.NOTE {
                Synth.SAMPLE = 2 * numpy.pi * numpy.arange(0, event[5], 1 / FREQUENCY_SAMPLE);

                new dynamic length = int(event[6] * FREQUENCY_SAMPLE),
                            cLen   = len(tracks[event[2]]) - length - len(Synth.SAMPLE);

                if cLen < 0 {
                    cLen = 0;
                }

                event[4]._noStatic();

                tracks[event[2]] += numpy.resize(
                    numpy.concatenate((
                        numpy.zeros(length, dtype = numpy.int16),
                        (event[3] * event[4].get(event[1])).astype(numpy.int16),
                        numpy.zeros(cLen, dtype = numpy.int16)
                    )), len(tracks[event[2]])
                );
            } else {
                new dynamic length = int(event[3] * FREQUENCY_SAMPLE),
                            cLen   = len(tracks[-1]) - length - len(event[1]);

                tracks[-1] += numpy.resize(
                    numpy.concatenate((
                        numpy.zeros(length, dtype = numpy.int16),
                        event[1].astype(numpy.int16),
                        numpy.zeros(cLen, dtype = numpy.int16)
                    )), len(tracks[-1])
                );
            }
        }

        if this.mode == Synth.EXPORT {
            IO.out("Writing files...\n");;
            if not path.exists("tracks") {
                mkdir("tracks");
            }

            for i in range(len(tracks) - 1) {
                if len(tracks[i]) != 0 {
                    wavfile.write(path.join("tracks", str(i) + ".wav"), FREQUENCY_SAMPLE, tracks[i]);
                }
            }

            if len(tracks[-1]) != 0 {
                wavfile.write(path.join("tracks", "playbackTrack.wav"), FREQUENCY_SAMPLE, tracks[-1]);
            }

            return;
        }

        IO.out("Mixing tracks...\n");
        
        new dynamic maxLen = max(len(x) for x in tracks);
        tracks[0].resize(maxLen);
        new dynamic fullTrack = tracks[0];

        for i = 1; i < len(tracks); i++ {
            tracks[i].resize(maxLen);
            fullTrack += tracks[i];
        }

        return fullTrack;
    }

    new method playCompiled(source) {
        match this.mode {
            case Synth.EXPORT {
                this.render(source);
                return;
            }
            case Synth.REALTIME {
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

                new dynamic synth = this;
                exec(source);
            }
            case Synth.RENDER {
                mixer.init(RENDER_FREQ_SAMPLE, channels = 1);

                this.soundChannels = [mixer.Channel(0)];

                new dynamic soundtrack = this.render(source);
                this.mode = Synth.REALTIME;
                this.play(sndarray.make_sound(soundtrack));
            }
        }
    }
}

main() {
    if len(argv) == 1 {
        IO.out("SynthScript v2023.1.7 - thatsOven\n");
    } else {
        new bool compile = False;

        if "--compile" in argv {
            compile = True;
            argv.remove("--compile");
        }

        new dynamic synth = Synth();

        if "--export-tracks" in argv {
            synth.mode = Synth.EXPORT;
            argv.remove("--export-tracks");
        }

        if "--realtime" in argv {
            synth.mode = Synth.REALTIME;
            argv.remove("--realtime");
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
    }
}
