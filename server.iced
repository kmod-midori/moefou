cp = require 'child_process'
fs = require 'fs'
{make_esc} = require 'iced-error'

init = (gcb)->
	esc = make_esc gcb
	await fs.readdir __dirname + '/sites',esc defer file
	file = file.filter((i)->i.match /\.js$/i).map((i)->i.match(/(.+)\.js$/i)[1])
	console.dir file

init ->console.dir arguments



