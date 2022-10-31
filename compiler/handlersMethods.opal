new method __create() {
    new dynamic obj  = this.tokens.next(),
                next = this.tokens.next();

    if next.lower() != "as" {
        this.__error(f'invalid identifier "{next}". Expecting "AS"');
    }

    new dynamic name = this.tokens.next();

    if this.tokens.peek().lower() == "with" {
        this.tokens.next();
        return name + "=" + obj + this.tokens.next();
    }

    return name + "=" + obj + "()";
}

new method __set() {
    new dynamic attr = this.tokens.next(),
                next = this.tokens.next();

    if next.lower() != "of" {
        this.__error(f'invalid identifier "{next}". Expecting "OF"');
    }

    new dynamic name = this.tokens.next();
    next = this.tokens.next();

    if next.lower() != "to" {
        this.__error(f'invalid identifier "{next}". Expecting "TO"');
    }

    return name + "." + attr + "=" + this.tokens.next();
}

new method __note() {
    new dynamic note = this.getValue(),
                next = this.tokens.next();

    if next.lower() != "channel" {
        this.__error(f'invalid identifier "{next}". Expecting "CHANNEL"');
    }

    new dynamic channel = this.tokens.next(),
                status  = this.getValue(), instr;
    
    if this.tokens.peek().lower() == "using" {
        this.tokens.next();
        instr = this.tokens.next();
    } else {
        instr = "None";
    }

    if this.tokens.peek().lower() == "with" {
        this.tokens.next();

        return "synth.note(" + note + "," + channel + "," + status + "," + instr + "," + this.tokens.next()[1:];
    }

    return "synth.note(" + note + "," + channel + "," + status + "," + instr + ")";
}

new method __play() {
    new dynamic toPlay = this.tokens.next();

    if this.tokens.peek().lower() == "with" {
        this.tokens.next();
        return "synth.play(" + toPlay + "," + this.tokens.next()[1:];
    }

    return "synth.play(" + toPlay + ")";
}

new method __define() {
    return "def " + this.tokens.next() + "(synth):";
}

new method __definePost() {
    this.level++;
}

new method __end() {
    this.level--;
}

new method __wait() {
    new dynamic value = this.tokens.next(), tmp;
    
    try {
        tmp = float(value);
    } catch ValueError {
        this.__error(f'invalid WAIT value "{value}"');
    }

    return "sleep(" + str(float(value) / 1000) + ")";
}

new method __default() {
    new dynamic instr = this.tokens.next();
    return "synth.defaultInstrument=Instrument" + instr;
}

new method __pitchbend() {
    new dynamic next = this.tokens.next();

    if next.lower() != "channel" {
        this.__error(f'invalid identifier "{next}". Expecting "CHANNEL"');
    }

    new dynamic channel = this.tokens.next();
    next = this.tokens.next();

    if next.lower() != "by" {
        this.__error(f'invalid identifier "{next}". Expecting "BY"');
    }

    new dynamic amount = this.tokens.next();

    if this.tokens.peek().lower() == "with" {
        this.tokens.next();
        return "synth.pitchBend(" + amount + "," + channel + "," + this.tokens.next()[1:];
    }

    return "synth.pitchBend(" + amount + "," + channel + ")";
}