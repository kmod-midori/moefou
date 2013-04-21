asyncblock = require 'asyncblock'
Shred = require 'shred'
shred = new Shred()
fs = require 'fs'

fetch = (page,conn,cb)->
	asyncblock (flow)->
		#出错回调
		flow.errorCallback = (err)->
			console.dir err


		reqcb = flow.set('list')
		#获取数据
		shred.get
			url:'https://yande.re/post.json'
			query:
				limit:30
				page:page
			proxy:'http://127.0.0.1:8888'
			on:
				response:(rep)->reqcb(rep.isError,rep)
		items = flow.get('list').content.data
		#处理数据
		for item in items
			console.log item.id







fetch(1)

