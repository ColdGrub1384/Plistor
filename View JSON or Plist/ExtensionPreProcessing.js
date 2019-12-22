var Action = function() {};

Action.prototype = {

run: function(parameters) {
    parameters.completionFunction({ "content" : document.body.innerText, "name" : window.location.pathname.split("/").reverse()[0] });
},

finalize: function(parameters) {

}

};

var ExtensionPreprocessingJS = new Action
