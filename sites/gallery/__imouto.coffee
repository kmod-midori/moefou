flowless = require 'flowless'
_ = require 'underscore'
mysql = require 'mysql'
request = require 'request'
assert = require 'assert'
block = require('node-block').block

conn = mysql.createConnection 'mysql://root:19990906c@127.0.0.1:3306/moefou'

fetch = (page,callback)->

	flowless.runSeq([
		#start fetch
		(cb)->
			request
				url:'https://yande.re/post.json'
				qs:
					limit:30
					page:page
				#proxy:'http://127.0.0.1:8080'
			,cb

		(rep,body,cb)->
			assert.equal rep.statusCode,200,'statCode'
			body = JSON.parse body
			cb(null,body)

		flowless.map (item,cb)->
			item.tags = item.tags.split /\s/g

			block(
				->
					sql = 'SELECT `gallery_id` FROM `mp_gallery` WHERE `gallery_md5` = ?'
					conn.query(sql,[item.md5],@async 'q1')
			,->
				return @end() unless @data.q1[0].length is 0

				sql = '''
							INSERT INTO `mp_gallery`
							(`gallery_width`, `gallery_height`
							, `gallery_file_url`, `gallery_sample_url`, `gallery_preview_url`
							, `gallery_source`, `gallery_file_size`, `gallery_date`
							, `gallery_rating`, `gallery_md5`, `gallery_site`
							, `gallery_site_id`) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
							'''
				__cb = @async 'q2'
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
				],(err,r)->
					item = _.extend(item,{row:r.insertId}) if r?.insertId?
					__cb(err,item)
				)
			)(cb)
		(items,cb)->
			items = _.map items,(item)-> item[0]
			items = _.filter items,(item)-> item.q2?
			items = _.map items,(item)-> item.q2
			console.dir items
			if items.length is 0
				cb('nothing to insert')
				return


			_tags = {}
			for item in items
				for tag in item.tags
					_tags[tag] = [] unless _tags[tag]?
					_tags[tag].push(item.row)
			tags = for key,val of _tags
				{name:key,rows:val}



			flowless.runMap tags,(tag,cb)->
				flowless.runSeq([
					(cb)->
						sql = 'SELECT `tag_id` FROM `mp_tags` WHERE  `tag_eng_name` = ?'
						conn.query(sql,tag.name,cb)
					(result,q...,cb)->
						unless result.length is 0
							cb(null,{insertId:result[0].tag_id})
							return

						sql = 'INSERT INTO `mp_tags` (`tag_chn_name`,`tag_eng_name`,`tag_jpn_name`,`tag_modified`) VALUES (?,?,?,?)'
						conn.query(sql,[
							''
							tag.name
							''
							Math.round(new Date().getTime()/1000)
						],cb)
					(q,f...,cb)->
						flowless.runMap tag.rows,(row,cb)->
							sql = '''
										INSERT INTO `mp_tags_gallery` (`tr_object_id`,`tr_object_type`,`tr_tag_id`, `tr_uid`,`tr_tag_type`)
										VALUES (?,'',?,0,1)
										'''
							conn.query(sql,[
								row
								q.insertId
							],cb)
						,cb
				],cb)
	],callback)

fetch 1,(err)->
	console.info(err) if err?
	#conn.query('DELETE FROM `mp_gallery`',()->
	#  console.info 'Cleaning...'
	#  console.info "Test finish. Removed #{arguments[1].affectedRows} rows in 'mp_gallery'."
	conn.end()
#)
