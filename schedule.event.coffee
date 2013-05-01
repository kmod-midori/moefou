events = require 'events'

class Scheduler extends events.EventEmitter
	constructor:(@tasks)->
		events.EventEmitter.call @



module.exports = Scheduler