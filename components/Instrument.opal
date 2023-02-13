new class Instrument {
    new dynamic ID = 0;

    new method __init__(**waves) {
        if "postProcess" in waves {
            this.postProcess = waves["postProcess"];
            del waves["postProcess"];
        } else {
            this.postProcess = None;
        }

        if "preProcess" in waves {
            this.preProcess = waves["preProcess"];
            del waves["preProcess"];
        } else {
            this.preProcess = None;
        }

        this.waves = waves;
        this.__keys = list(waves.keys()); 

        if "static" in waves {
            new dynamic static = waves["static"];
            del waves["static"];
            this.__keys.remove("static");

            for key in this.__keys {
                this.waves[key].static = static; 
            }
        }

        this._id = Instrument.ID;
        Instrument.ID++;
    }

    new method _noStatic() {
        for key in this.__keys {
            this.waves[key]._noStatic(); 
        }

        if this.postProcess is not None {
            this.postProcess._noStatic();
        }
        
        if this.preProcess is not None {
            this.preProcess._noStatic();
        }
    }

    new method get(frequency, velocity) {
        if this.preProcess is not None {
            frequency = this.preProcess.get(frequency);
        }

        new dynamic wave = this.waves[this.__keys[0]].get(frequency, velocity);
        for i = 1; i < len(this.__keys); i++ {
            wave += this.waves[this.__keys[i]].get(frequency, velocity);
        }

        if this.postProcess is not None {
            wave = this.postProcess.get(wave);
        }
        
        return wave;
    }

    new method __getattr__(name) {
        if name in this.waves {
            return this.waves[name];
        }
    }
}