global.CONFIG = require('config')
timeplan = require 'timeplan'
logger = require('tracer').dailyfile({
	root:'./log'
	format:'{{timestamp}} <{{title}}> {{message}}'
})
logStr = '[%s] %j'

srv_count = 0

for srv in CONFIG.srvs
	if srv.enabled
		srv_count += 1
		do (srv)->
			run = require('./sites/'+srv.file)
			timeplan.repeat
				period:srv.period
				task:->
					run (err,stat)->
						if err
							logger.error logStr,err.toString()
							return
						logger.info logStr,srv.name,stat


logger.info 'Server started with %d services',srv_count


