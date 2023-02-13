package mido: import MidiFile;

new class Midi {
    new method __init__(file, instruments = None) {
        this.events = [];

        if instruments is None {
            this.instruments = [Instrument(square = Square()) for _ in range(CHANNELS)];
        } else {
            this.instruments = instruments;
        }

        new dynamic mid = MidiFile(file);

        for message in mid {
            if message.type in ("note_on", "note_off") {
                new dynamic type_;
                if message.type == "note_on" and message.velocity == 0 {
                    type_ = "note_off";
                } else {
                    type_ = message.type;
                }

                this.events.append([
                    "note",
                    this.getFreq(message.note), message.channel, 
                    (type_ == "note_on"), this.instruments[message.channel], 
                    Utils.translate(message.velocity, 0, 127, 0, MAX_AMP), message.time
                ]);
            } elif message.type == "pitchwheel" {
                this.events.append([
                    "pitch",
                    message.pitch, message.channel, message.time
                ]);
            } elif message.type == "end_of_track" {
                this.events.append([message.time]);
                break;
            } elif len(this.events) != 0 {
                this.events[-1][-1] += message.time;
            }
        }

        for i = 0; i < len(this.events) - 1; i++ {
            this.events[i][-1] = this.events[i + 1][-1];
        }
        this.events.pop(-1);
    }

    new classmethod getFreq(note) {
        return 440.0 * 2 ** ((note - 69) / 12);
    }
}