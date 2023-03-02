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
                return signal.square(frequency);
            }
        } elif type(this.duty) in (int, float) {
            new function __wave(frequency) {
                return signal.square(frequency, this.duty);
            }
        } else {
            new function __wave(frequency) {
                return signal.square(frequency, this.duty.get(frequency));
            }
        }

        if usingCupy {            
            new function __newWave(frequency) {
                return numpy.asarray(__wave((frequency * Synth.SAMPLE).get()));
            }
        } else {
            new function __newWave(frequency) {
                return __wave(frequency * Synth.SAMPLE);
            }
        }

        this.__wave = __newWave;
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

        if usingCupy {
            new function __wave(frequency, width) {
                return numpy.array(signal.sawtooth((Synth.SAMPLE * frequency).get(), this.width));
            }
        } else {
            new function __wave(frequency, width) {
                return signal.sawtooth(Synth.SAMPLE * frequency, this.width);
            }
        }

        this.__wave = __wave;
    }

    new method get(frequency, velocity) {
        super().get();

        return velocity * this.__amp * this.__wave(frequency, this.width);
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