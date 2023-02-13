package sf2_loader: import sf2_loader;

new class SoundFont {
    new method __init__(soundFont) {
        if type(soundFont) is str {
            this.soundFont = sf2_loader(soundFont);
        } else {
            this.soundFont = soundFont;
        }
    }

    new method getInstrument(name) {
        new dynamic instruments = this.soundFont.get_all_instrument_names();

        for item in instruments {
            if name.lower() in item.lower() {
                return item;
            }
        }

        IO.out(f'"{name}" was not found.\nAvailable:\n{str(instruments)}\n');

        return instruments[0];
    }
}

new class _FakeMPNote {
    new method __init__(frequency) {
        this.degree = int(12 * numpy.log2(frequency / 455) + 69); 
    }
}

new class SoundFontInstrument {
    new method __init__(soundFont, preset = 0, bank = 0) {
        this.soundFont = soundFont.soundFont;

        this.preset = preset;
        this.bank   = bank;
    }

    new method _noStatic() {}

    new method get(frequency, velocity) {
        new dynamic tmp = len(Synth.SAMPLE) / FREQUENCY_SAMPLE, segment;

        this.soundFont.change(
            preset = this.preset,
            bank   = this.bank
        );

        segment = this.soundFont.export_note(
            _FakeMPNote(frequency), tmp, volume = int(
                Utils.translate(velocity, 0, MAX_AMP, 0, 127)
            ), channels = 1, frame_rate = FREQUENCY_SAMPLE,
            get_audio = True
        );

        return numpy.array(segment.get_array_of_samples(), numpy.int16).astype(float);
    }
}