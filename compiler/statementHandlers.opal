this.statementHandlers = {
    "create"   : Handler(this.__create),
    "set"      : Handler(this.__set),
    "note"     : Handler(this.__note),
    "play"     : Handler(this.__play),
    "define"   : Handler(this.__define, this.__definePost),
    "end"      : Handler(this.__end),
    "wait"     : Handler(this.__wait),
    "default"  : Handler(this.__default),
    "pitchbend": Handler(this.__pitchbend)
};