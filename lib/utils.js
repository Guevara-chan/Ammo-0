Function.prototype.getter = function(name, proc) {
  return Reflect.defineProperty(this.prototype, name, {
    get: proc,
    configurable: true
  });
};

Function.prototype.setter = function(name, proc) {
  return Reflect.defineProperty(this.prototype, name, {
    set: proc,
    configurable: true
  });
};