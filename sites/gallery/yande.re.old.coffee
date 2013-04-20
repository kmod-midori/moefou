async = require 'async'
Shred = require 'shred'
shred = new Shred()
_ = require 'underscore'
mysql = require 'mysql'
block = require('node-block').block
#Rel = require 'rel'
#pics = new Rel.Table 'mp_gallery'

conn = mysql.createConnection('mysql://root:password@127.0.0.1:3306/moefou')

fetch = (cur_page,conn,_cb)->
	async.waterfall([
		#start fetch
		(cb)->
			shred.get
				url:'https://yande.re/post.json'
				query:
					limit:30
					page:cur_page
				proxy:'http://127.0.0.1:8888'
				on:
					200:(rep)->
						cb(null,rep)
					response:(rep)->
						cb(rep.status,rep)
		#process list
		(rep,cb)->
			async.map rep.content.data,(item,cb)->
				async.waterfall [
					#query existent
					(cb)->
						sql = 'SELECT `gallery_id` FROM `mp_gallery` WHERE `gallery_md5` = ?'
						conn.query(sql,[item.md5],cb)
					#check existent
					(result,q,cb)->
						if result.length
							cb(null,false)
							return

						item.tags = item.tags.split /\s/g

						sql = '''
									INSERT INTO `mp_gallery`
									(`gallery_width`, `gallery_height`
									, `gallery_file_url`, `gallery_sample_url`, `gallery_preview_url`
									, `gallery_source`, `gallery_file_size`, `gallery_date`
									, `gallery_rating`, `gallery_md5`, `gallery_site`
									, `gallery_site_id`) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
									'''
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
						],(err,q)->
							item.row_id = q.insertId if q?.insertId?
							cb(err,item)
						)
				],cb
			,(err,items)->
				items = _.compact items
				if items.length is 0
					cb null,
						received:30
						collected:0
						tags:0
					return

				_tags = {}
				for item in items
					for tag in item.tags
						_tags[tag] = [] unless _tags[tag]?
						_tags[tag].push(item.row_id)
				tags = for key,val of _tags
					{name:key,rows:val}
				async.map tags,(tag,cb)->
					async.waterfall [
						#check existent
						(cb)->
							sql = 'SELECT `tag_id` FROM `mp_tags` WHERE  `tag_eng_name` = ?'
							conn.query(sql,tag.name,cb)
						(result,q...,cb)->
							unless result.length is 0
								cb(null,result[0].tag_id)
								return
							sql = 'INSERT INTO `mp_tags` (`tag_chn_name`,`tag_eng_name`,`tag_jpn_name`,`tag_modified`) VALUES (?,?,?,?)'
							conn.query(sql,[
								''
								tag.name
								''
								Math.round(new Date().getTime()/1000)
							],cb)
						(q, f...,cb)->
							async.map tag.rows,(row,cb)->
								sql = '''
											INSERT INTO `mp_tags_gallery` (`tr_object_id`,`tr_object_type`,`tr_tag_id`, `tr_uid`,`tr_tag_type`)
											VALUES (?,'',?,0,1)
											'''
								conn.query(sql,[
									row
									q.insertId
								],cb)
							,cb

					],cb
				,cb

				cb()

		#end process list
	],_cb)

fetch(1,conn,(err)->
	console.dir(arguments)
	console.log('Completed.')
	#conn.end()
)