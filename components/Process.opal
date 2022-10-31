new class Process {
    new method __init__(**effects) {
        this.effects = effects;
        this.__keys = list(effects.keys());

        if "static" in effects {
            new dynamic static = effects["static"];
            del effects["static"];
            this.__keys.remove("static");

            for key in this.__keys {
                this.effects[key].static = static;
            }
        }
    }

    new method _noStatic() {
        for key in this.__keys {
            this.effects[key]._noStatic();
        }
    }

    new method get(wave) {
        for key in this.__keys {
            wave = this.effects[key].get(wave);
        }

        return wave;
    }

    new method __getattr__(name) {
        if name in this.effects {
            return this.effects[name];
        }
    }
}