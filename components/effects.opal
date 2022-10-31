abstract: new class Effect {
    new method __init__(static) {
        this.static = static;
    }

    property static {
        get {
            return this._static;
        }

        set {
            this._static = value;

            if value {
                this._compute();
            }
        }
    }

    new method _noStatic() {
        this.static = False;
    }

    new method get() {
        if not this.static {
            this._compute();
        }
    }

    abstract: new method _compute();
}

new class Envelope : Effect {
    new method __init__(attack = 0, decay = 0, sustain = 1, static = False) {
        this.attack  = attack;
        this.decay   = decay;
        this.sustain = sustain;

        super().__init__(static);
    }

    new method _compute() {
        new dynamic attackAmt, decayAmt, sustSize;
        attackAmt = int((this.attack / 1000) * FREQUENCY_SAMPLE);
        decayAmt  = int((this.decay  / 1000) * FREQUENCY_SAMPLE);

        sustSize = len(Synth.SAMPLE) - attackAmt - decayAmt;
        if sustSize < 0 {
            sustSize = 0;
        }

        this.__envWave = numpy.resize(
            numpy.concatenate((
                numpy.linspace(0,            1, attackAmt, dtype = float),
                numpy.linspace(1, this.sustain,  decayAmt, dtype = float),
                numpy.full(sustSize, this.sustain, dtype = float)
            )), len(Synth.SAMPLE)
        );
    }

    new method get(wave) {
        super().get();

        return numpy.multiply(wave, this.__envWave);
    }
}

new class Vibrato : Effect {
    new method __init__(osc = 0.25, amount = 1, static = False) {
        this.osc    = osc;
        this.amount = amount;

        super().__init__(static);
    }

    new method _compute() {
        this.__oscWave = this.amount * numpy.sin(Synth.SAMPLE * this.osc);
    }

    new method get(frequency) {
        super().get();

        return frequency + this.__oscWave;
    }
}

new class FreqSweep : Effect {
    new method __init__(toFreq = 440, time = 1) {
        this.toFreq  = toFreq;
        this.samples = time;

        super().__init__(False);
    }

    property samples {
        get {
            return this._samples;
        }
        set {
            this._samples = int((value / 1000) * FREQUENCY_SAMPLE);
        }
    }

    new method _compute() {
        new dynamic fillSize = len(Synth.SAMPLE) - this.samples;
        if fillSize < 0 {
            fillSize = 0;
        }

        this.__freqWave = numpy.resize(
            numpy.concatenate((
                numpy.linspace(this.frequency, this.toFreq, this.samples, dtype = float), 
                numpy.full(fillSize, this.toFreq, dtype = float)
            )), len(Synth.SAMPLE)
        );
    }

    new method get(frequency) {
        this.frequency = frequency;

        super().get();

        return this.__freqWave;
    }
}