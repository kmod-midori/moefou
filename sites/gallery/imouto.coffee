next = require 'nextflow'
request = require 'request'
assert = require 'assert'
equal = assert.equal
mysql = require 'mysql'
_ = require 'underscore'
gate = require 'gate'
dnode = require 'dnode'




conn = mysql.createConnection 'mysql://root:19990906c@127.0.0.1:3306/moefou'


fetch = (callback)->
	stats = {}
	next flow =
		error: (err)->
			process.nextTick ->
				callback err
		start: ->
			request({
				url:'https://yande.re/pot.json'
				qs:
					limit:30
					page:1
			},@next)

		check_exist: (err,rep)->
			equal rep.statusCode,200,'Request to imouto is not success.'

			items = JSON.parse rep.body
			stats.item_received = items.length
			sql = 'SELECT `gallery_id` FROM `mp_gallery` WHERE `gallery_md5` = ?'
			g = gate.create()

			for item in items
				item.tags = item.tags.split /\s/g
				conn.query(sql,[item.md5],g.latch({data:1,item:g.val(item)}))

			g.await @next

		insert_data:(err,items)->
			items = _.filter items,(item)->not item.data[0]?
			items = for item in items
				item.item

			stats.items_inserted = 0
			if items.length is 0
				@success(null,stats)
				return

			g = gate.create()

			sql = '''
						INSERT INTO `mp_gallery`
						(`gallery_width`, `gallery_height`
						, `gallery_file_url`, `gallery_sample_url`, `gallery_preview_url`
						, `gallery_source`, `gallery_file_size`, `gallery_date`
						, `gallery_rating`, `gallery_md5`, `gallery_site`
						, `gallery_site_id`) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
						'''

			for item in items
				conn.query(sql,[
					item.width
					item.height
					item.file_url
					item.sample_url
					item.preview_url
					item.source
					item.file_size
					Math.round(new Date().getTime()/1000)
					item.rating
					item.md5
					'imouto'
					item.id
				],g.latch({result:1,item:g.val(item)}))

			g.await @next

		query_tags:(err,result)->
			items = _.map result,(item)->
				_.extend(item.item,{row:item.result.insertId})
			stats.items_inserted = items.length
			_tags = {}
			for item in items
				for tag in item.tags
					_tags[tag] = [] unless _tags[tag]?
					_tags[tag].push(item.row)
			tags = for key,val of _tags
				{name:key,rows:val}

			console.dir tags

			g = gate.create()

			for tag in tags
				sql = 'SELECT `tag_id` FROM `mp_tags` WHERE  `tag_eng_name` = ?'
				conn.query sql,[tag.name], g.latch({data:1,tag:g.val(tag)})

			g.await @next

		insert_tags:(err,tags)->
			already = _.filter(tags,(tag)->tag.data[0]?.tag_id?)
			need_insert = _.filter(tags,(tag)->not tag.data[0]?.tag_id?)
			need_insert = _.map(need_insert,(tag)->tag.tag)
			stats.tags_affected = need_insert.length
			g = gate.create()
			sql = 'INSERT INTO `mp_tags` (`tag_chn_name`,`tag_eng_name`,`tag_jpn_name`,`tag_modified`) VALUES (?,?,?,?)'
			for tag in need_insert
				conn.query(sql,[
					''
					tag.name
					''
					Math.round(new Date().getTime()/1000)
				],g.latch({result:1,row:g.val(tag.rows)}))

			g.await((err,results)=>
				if err
					@error err
					return
				results = _.map results,(data)->{id:data.result.insertId,row:data.row}
				for tag in already
					results.push {id:tag.data[0].tag_id,row:tag.tag.rows}
				@next(null,results)
			)


		insert_ref:(err,tags)->
			g = gate.create()
			sql = '''
						INSERT INTO `mp_tags_gallery` (`tr_object_id`,`tr_object_type`,`tr_tag_id`, `tr_uid`,`tr_tag_type`)
						VALUES (?,'',?,0,1)
						'''


			for tag in tags
				for row in tag.row
					conn.query(sql,[row,tag.id],g.latch({result:1}))

			g.await @next










		success:(err)->
			process.nextTick ->
				conn.end()
				if stats
					callback null,stats
				else
					callback err



server = dnode({fetch})
server.listen 2333



