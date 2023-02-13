new class Wave : Effect {
    new method __init__(amplitude = MAX_INSTRUMENT_VALUE, static = False) {
        this.amplitude = amplitude;
        
        super().__init__(static);
    }
}

new class Square : Wave {
    new method __init__(amplitude = MAX_INSTRUMENT_VALUE, duty = None, static = False) {
        this.duty = duty;
        
        super().__init__(amplitude, static);
    }

    new method _compute() {
        this.__amp = (this.amplitude / MAX_INSTRUMENT_VALUE);

        if this.duty is None {
            new function __wave(frequency) {
                return signal.square(Synth.SAMPLE * frequency);
            }
        } elif type(this.duty) in (int, float) {
            new function __wave(frequency) {
                return signal.square(Synth.SAMPLE * frequency, this.duty);
            }
        } else {
            new function __wave(frequency) {
                return signal.square(Synth.SAMPLE * frequency, this.duty.get(frequency));
            }
        }

        this.__wave = __wave;
    }

    new method get(frequency, velocity) {
        super().get();

        return velocity * this.__amp * this.__wave(frequency);
    }
}

new class Sawtooth : Wave {
    new method __init__(amplitude = MAX_INSTRUMENT_VALUE, width = 1, static = False) {
        this.width = width;

        super().__init__(amplitude, static);
    }

    new method _compute() {
        this.__amp = this.amplitude / MAX_INSTRUMENT_VALUE;
    }

    new method get(frequency, velocity) {
        super().get();

        return velocity * this.__amp * signal.sawtooth(Synth.SAMPLE * frequency, this.width);
    }
}

new class Noise : Wave {
    new method _compute() {
        this.__wave = (this.amplitude / MAX_INSTRUMENT_VALUE) * numpy.random.uniform(-1, 1, len(Synth.SAMPLE));
    }

    new method get(frequency, velocity) {
        super().get();

        return velocity * this.__wave;
    }
}