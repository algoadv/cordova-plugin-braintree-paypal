var exec = require('cordova/exec');

function BrainTreePayPalPlugin() { };

BrainTreePayPalPlugin.prototype.init = function(token, success, error) {
    exec(success, error, 'BrainTreePayPalPlugin', 'init', [token]);
}

BrainTreePayPalPlugin.prototype.showPaymentUI = function(options, success, error) {
    if (!options) {
        options = {};
    }

    if (typeof(options.amount) === "undefined") {
        options.amount = "0.00";
    };
    
    if (!isNaN(options.amount * 1)) {
	    options.amount = (options.amount * 1).toFixed(2)
	}

    var pluginOptions = [
        options.amount,
        options.currency
    ];
    
    exec(success, error, 'BrainTreePayPalPlugin', 'showPaymentUI', pluginOptions);
}

var instance = new BrainTreePayPalPlugin();
module.exports = instance;