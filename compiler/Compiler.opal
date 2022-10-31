new class SynthScriptException : Exception {}

new class Handler {
    new method __init__(handler, post = None) {
        this.handle = handler;
        
        if post is not None {
            this.post = post;
        }
    }

    new method post() {}
}

new class Tokens {
    new method __init__(source) {
        this.tokens = this.tokenize(source);
        this.pos    = 0;
    }

    new method isntFinished() {
        return this.pos < len(this.tokens);
    }

    new method peek() {
        if this.pos < len(this.tokens) {
            return this.tokens[this.pos];
        }
        
        return "";
    }

    new method next() {
        new dynamic tmp = this.tokens[this.pos];
        this.pos++;
        return tmp;
    }

    new classmethod tokenize(source) {
        source = source.strip().replace("\n", " ").replace("\t", " ");

        new dynamic tokens = [""],
                    level  = 0;

        for ch in source {
            if ch == "(" {
                tokens[-1] += "(";
                level++;
            } elif ch == ")" {
                tokens[-1] += ")";
                level--;
            } elif ch == " " and level == 0 {
                tokens.append("");
            } else {
                tokens[-1] += ch;
            }
        }

        new dynamic i = 0;
        while i < len(tokens) {
            if tokens[i] == "" {
                tokens.pop(i);
            } else {
                i++;
            }
        }

        if level != 0 {
            throw SynthScriptException("invalid syntax: unbalanced brackets");
        }

        return tokens;
    }
}

new class Compiler {
    new dict NOTE_TABLE;
    NOTE_TABLE = {
        "c" : 0,
        "c#": 1,
        "d" : 2,
        "d#": 3,
        "e" : 4,
        "f" : 5,
        "f#": 6,
        "g" : 7,
        "g#": 8,
        "a" : 9,
        "a#": 10,
        "b" : 11
    };

    $include os.path.join("HOME_DIR", "compiler", "handlersMethods.opal")

    new method __init__(source) {
        this.output = "";
        this.level  = 0;

        this.hadError = False;

        try {
            this.tokens = Tokens(source);
        } catch SynthScriptException as e {
            this.__error(e);
        }

        $include os.path.join("HOME_DIR", "compiler", "statementHandlers.opal")
    }

    new method __error(msg) {
        this.hadError = True;

        IO.out(msg, IO.endl);
    }

    new classmethod getFreq(note) {
        return 440 * 2 ** ((note - 69) / 12);
    }

    new method getValue() {
        new dynamic value = this.tokens.next(),
                    low   = value.lower();

        if low in ("on", "true") {
            return "True";
        } elif low in ("off", "false") {
            return "False";
        } elif low[0].isalpha() {
            new dynamic tmp;

            if low[1] == "#" {
                try {
                    tmp = int(low[2]);
                } catch ValueError {
                    this.__error(f'invalid note value "{value}"');
                }

                if low[:1] not in Compiler.NOTE_TABLE {
                    this.__error(f'invalid note value "{value}"');
                }

                return str(this.getFreq(Compiler.NOTE_TABLE[low[:1]] + int(low[2]) * 12));
            } else {
                try {
                    tmp = int(low[1]);
                } catch ValueError {
                    this.__error(f'invalid note value "{value}"');
                }

                if low[0] not in Compiler.NOTE_TABLE {
                    this.__error(f'invalid note value "{value}"');
                }

                return str(this.getFreq(Compiler.NOTE_TABLE[low[0]] + int(low[1]) * 12));
            }
        } elif value[0].isdigit() {
            return value;
        }

        this.__error(f'invalid value "{value}"');
        return "";
    }

    new method compile() {
        while this.tokens.isntFinished() {
            new dynamic next  = this.tokens.next(),
                        lower = next.lower();

            if lower[:5] == "with(" {
                this.__error(f'unknown statement "{next}". Did you mean: "{next[:4]} {next[4:]}"?');
                continue;
            }

            if lower in this.statementHandlers {
                new dynamic handler = this.statementHandlers[lower],
                            result  = handler.handle();

                if result is not None {
                    this.output += (" " * this.level) + result + "\n";
                }

                handler.post();
            } else {
                this.__error(f'unknown statement "{next}"');
            }
        }

        if not this.hadError {
            return this.output;
        } else {
            return "";
        }
    }
}