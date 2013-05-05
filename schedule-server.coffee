dnode = require('dnode')
timeplan = require 'timeplan'
d = dnode.connect(2334)

d.on 'remote',(remote)->
	timeplan.repeat
		period:'10s'
		task:->
			remote.fetch((err,stat)->



			)