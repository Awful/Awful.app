(function(){
  function ObjCBridge() {
    this.messages = {};
    this.next = 0;
  }
  
  ObjCBridge.prototype.log = function(msg) {
    window.location.href = "awful-log:" + msg;
  }
  
  ObjCBridge.prototype.send = function(action, infoDictionary) {
    var url = "awful-js://" + action;
    if (infoDictionary) {
      this.messages[this.next] = JSON.stringify(infoDictionary);
      url += "/" + this.next;
      this.next += 1;
    }
    window.location.href = url;
  }
  
  ObjCBridge.prototype.receive = function(i) {
    var msg = this.messages[i];
    delete this.messages[i];
    return msg;
  }
  
  Awful = new ObjCBridge;
  console.log = Awful.log;
})();
